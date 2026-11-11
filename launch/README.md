# Launch page

The beta sign-up page for Cloudflare Pages:

- `public/` is what's served: `index.html`, `app.js`, `_headers` and the icons.
- `functions/api/signup.js` adds each sign-up to a Supabase table and can also email you about it.
- `functions/api/ai/` answers the app's AI features, so the Claude key stays on the server. See below.
- `supabase/beta_signups.sql` creates the table.
- `tests/` has the functions' tests: `node --test 'launch/tests/*.test.mjs'`.

## Deploy

1. **Supabase**: use a project for City Tourist, not the ENM one. Run `supabase/beta_signups.sql` in its SQL editor.
2. **Cloudflare**: the Pages project `citytourist` (https://citytourist.pages.dev) is set up from the command line with `wrangler.toml`, which binds the `SIGNUPS` KV namespace and holds `SUPABASE_URL`. Deploy from this folder:
   ```
   cd launch
   npx wrangler pages deploy --branch main
   ```
   This project uses direct upload, so it doesn't redeploy by itself when `main` changes. Run the command again after merging.
3. **Secrets** are kept out of `wrangler.toml`. Set them with:
   ```
   npx wrangler pages secret put SUPABASE_KEY --project-name citytourist
   ```
   Use the project's **publishable (anon)** key. Don't use the secret or service-role key: the table only lets this key add rows, which is all the page needs.

   Optional, an email for each sign-up through [Resend](https://resend.com):
   - `RESEND_API_KEY` as a secret.
   - `SIGNUP_TO` under `[vars]`. With Resend's shared sender, this has to be your Resend account's email.
   - `SIGNUP_FROM` once you've verified a domain with Resend.
4. **KV**: `SIGNUPS` is already bound. It limits each IP to 5 sign-ups an hour, and stops a repeat sign-up from emailing you twice.
5. Redeploy so the variables and binding take effect. Then sign up once yourself and check that the row appears.

With neither Supabase nor Resend set up, the form tells people sign-ups aren't switched on yet.

## The blanket invite

When the TestFlight link is ready, run these in the Supabase SQL editor:

```sql
select email, name from beta_signups where invited_at is null order by created_at;
-- after sending
update beta_signups set invited_at = now() where invited_at is null;
```

## The beta survey

`/feedback` (`public/feedback.html`) asks testers how the beta held up. The app
links to it from Settings, and from the Trips list once a trip has ended,
with `?trip=<city>&v=<build>` so each answer says what it's about.
`functions/api/feedback.js` checks the answers against the form's own options
and lengths and stores them in `beta_feedback`. Run
`supabase/beta_feedback.sql` once to create the table: like sign-ups, the
publishable key can only add rows. Read the answers in the SQL editor:

```sql
select created_at, city, used_today, leave_by_accuracy, plan_broke, confusing, next_trip, one_thing, email
from beta_feedback order by created_at desc;
```

Both functions share `lib/request.js`: the same-origin JSON reader, the
Supabase insert and the per-IP limit.

## The app's AI endpoints

The app's AI concierge and "Plan my whole trip" don't hold a Claude key. They post to two Pages Functions here, which add the key, the prompt and the model:

- `functions/api/ai/concierge.js` — `POST /api/ai/concierge`
- `functions/api/ai/trip.js` — `POST /api/ai/trip`
- `lib/claude.js` — what they share: the limits and the call to Claude.

Set the key once, then deploy:

```
cd launch
npx wrangler pages secret put ANTHROPIC_API_KEY --project-name citytourist
npx wrangler pages deploy --branch main
```

Use a key made for this server, not one that has ever been in an app build. Rotating it later is the same command, with no new app build.

Nothing proves a request came from the app, so the endpoints are built to be dull to anyone else: the caller can't choose the model, the prompt, the output shape or the size, and calls are counted in the `SIGNUPS` KV namespace before they cost anything.

| Limit | Default | Change it with |
| --- | --- | --- |
| Trip drafts per IP per hour | 12 | `PER_IP_PER_HOUR` in `trip.js` |
| Trip drafts a day, everyone | 200 | `TRIP_DAILY_LIMIT` under `[vars]` |
| Concierge searches per IP per hour | 30 | `PER_IP_PER_HOUR` in `concierge.js` |
| Concierge searches a day, everyone | 600 | `CONCIERGE_DAILY_LIMIT` under `[vars]` |

A limit of `0` switches that endpoint off. `TRIP_MODEL` and `CONCIERGE_MODEL` under `[vars]` change the models without an app build. Without the key or the KV binding the endpoints answer 503 and send nothing.

Also set a monthly spend limit on the key's workspace in the Anthropic console: it's the backstop if these limits are ever wrong.

Each call writes two KV keys, and KV's free plan allows 1,000 writes a day, which is about 500 AI calls. Past that, move to the paid plan or a Cloudflare rate-limiting rule.

To try them locally, put `ANTHROPIC_API_KEY=...` in `launch/.dev.vars` (gitignored) and run `npx wrangler pages dev`.

## Preview locally

`cd launch && npx wrangler pages dev public` serves the page and runs the
function. Put variables in `launch/.dev.vars`, which is gitignored. Any static
server pointed at `public/` shows the page, but the form needs the function.

## Security notes

- `public/_headers` sets a strict Content-Security-Policy. The only inline
  script is the one in `<head>` that decides whether the intro plays, and it's
  allowed by its SHA-256 hash. **If you edit that script, update the hash in
  `_headers`**, or browsers will block it.
- The function only accepts `POST` JSON up to 2 KB from the page's own origin.
  It drops anything that fills the hidden `company` field (a trap for bots),
  validates the email, and strips control characters from the name. It never
  echoes input back into HTML.
- The Supabase key it uses can insert an email and a name, and nothing else. It
  can't read the list, so if it leaked, the emails wouldn't. The table's own
  checks repeat the email and name rules for anything that bypasses the
  function.
- The Claude key is a Pages secret and never reaches a browser or the app. The app's bundle holds only keys that are safe to publish: Google's, restricted to the app's bundle ID and to two APIs, and Supabase's publishable key.
- The AI endpoints' counters aren't atomic: two requests at the same instant can both get through on the last allowance. The daily cap can be passed by a handful, not by much. The next step up is App Attest, so the server only answers a genuine copy of the app.
- For a harder limit than the per-IP KV counter, add a Cloudflare rate-limiting
  rule on `/api/signup`.
