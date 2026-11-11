// What the two AI endpoints share: the Claude key stays here on the server,
// the prompts and models are ours rather than the caller's, and every call is
// counted against limits before it costs anything.
//
// The endpoints are public: nothing proves a request came from the app. What
// keeps that safe is that a caller can't choose the model, the prompt, the
// output shape or the size, and that the number of calls a day is capped.

import { json, readJSON } from "./request.js";

const MESSAGES = "https://api.anthropic.com/v1/messages";

/** A request we won't forward, with the status to answer it with. */
export class Refused extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

/** The request's JSON object; throws `Refused` for anything else. */
export async function body(request, options) {
  const read = await readJSON(request, options);
  if (!read.error) return read.body;
  const reply = await read.error.json().catch(() => ({}));
  throw new Refused(read.error.status, reply.error || "The request is invalid.");
}

/**
 * A string within `limit`, trimmed; throws `Refused` otherwise. Limits here
 * are looser than the app's own, which counts characters where this counts
 * UTF-16 units; the cap on the whole body is what bounds the cost.
 */
export function text(value, limit, { allowEmpty = false } = {}) {
  if (typeof value !== "string" || value.length > limit) throw new Refused(400, "A text field is invalid.");
  // Control characters out: they have no place in a name or a request.
  const clean = value.replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, "").trim();
  if (!allowEmpty && !clean) throw new Refused(400, "A text field is empty.");
  return clean;
}

export function integer(value, min, max) {
  if (!Number.isInteger(value) || value < min || value > max) throw new Refused(400, "A number is invalid.");
  return value;
}

/** A rating out of five, or null when there are no reviews. */
export function rating(value) {
  if (value === null || value === undefined) return null;
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0 || value > 5) {
    throw new Refused(400, "A rating is invalid.");
  }
  return value;
}

/**
 * Who to count a request against. A home or a phone on IPv6 holds a whole /64
 * and can pick a new address in it for every request, so those count as one.
 */
export function caller(request) {
  const ip = request.headers.get("cf-connecting-ip") || "unknown";
  return ip.includes(":") ? ip.toLowerCase().split(":").slice(0, 4).join(":") : ip;
}

const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// KV takes one write a second to a key.
let retryMs = 1100;
/** Tests shorten the wait between the two write attempts. */
export function setRetryMs(ms) { retryMs = ms; }

/**
 * Adds one to a KV counter, or refuses when it has reached `limit`.
 *
 * KV isn't a lock: requests that arrive together read the same count, so a
 * burst can pass a limit by its own size. The spend limit on the Claude key
 * is what stops that mattering; see the README.
 */
async function count(env, key, limit, full) {
  let used;
  try {
    used = Number(await env.SIGNUPS.get(key)) || 0;
  } catch (error) {
    console.error("ai counter read failed", key, String(error));
    throw new Refused(503, "Busy right now. Try again in a minute.");
  }
  if (used >= limit) throw new Refused(429, full);
  // A write can fail when two land on a key in the same second, or when the
  // day's writes are used up. Try twice, then refuse: a call that can't be counted is a call that isn't capped.
  for (let attempt = 0; ; attempt++) {
    try {
      await env.SIGNUPS.put(key, String(used + 1), { expirationTtl: 2 * 86400 });
      return;
    } catch (error) {
      if (attempt === 1) {
        console.error("ai counter write failed", key, String(error));
        throw new Refused(503, "Busy right now. Try again in a minute.");
      }
      await pause(retryMs);
    }
  }
}

/**
 * Counts this call against the caller's allowance for the day and against
 * everyone's. Without the KV binding nothing can be counted, so nothing is
 * allowed: an uncounted endpoint is an open tab on the key.
 *
 * `perIPPerDay` should stay well under `perDay`, so no one address can use up
 * the day for everybody.
 */
export async function allow(env, request, name, { perIPPerDay, perDay }) {
  if (!env.ANTHROPIC_API_KEY || !env.SIGNUPS) {
    throw new Refused(503, "This isn't switched on yet.");
  }
  const day = new Date().toISOString().slice(0, 10);
  await count(env, `ai-${name}:${day}:${caller(request)}`, perIPPerDay,
              "Too many requests from here today. Try again tomorrow.");
  await count(env, `ai-${name}:${day}`, perDay, "That's all for today. Try again tomorrow.");
}

/** A daily cap from the project's variables, or the default when unset or blank. */
export function cap(value, fallback) {
  if (value === undefined || value === null || String(value).trim() === "") return fallback;
  const number = Number(value);
  return Number.isInteger(number) && number >= 0 ? number : fallback;
}

/** At most `limit` UTF-16 units, without cutting a character in half. */
export function clip(value, limit) {
  const cut = String(value ?? "").slice(0, limit);
  return /[\uD800-\uDBFF]$/.test(cut) ? cut.slice(0, -1) : cut;
}

/**
 * One Messages API call. Returns `{ stop, text }`; throws `Refused` with a
 * message of our own, never the API's, which can quote the key.
 */
export async function ask(env, body, { version, beta, timeoutMs }) {
  const headers = {
    "x-api-key": env.ANTHROPIC_API_KEY,
    "anthropic-version": version,
    "Content-Type": "application/json",
  };
  if (beta) headers["anthropic-beta"] = beta;

  let response;
  try {
    response = await fetch(MESSAGES, {
      method: "POST",
      headers,
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch {
    throw new Refused(504, "That took too long. Try again.");
  }
  if (!response.ok) {
    // The status and the error's type, for the logs. Never the message or the
    // body: they aren't ours to show, and the caller gets words of our own.
    const type = await response.json().then((reply) => reply?.error?.type, () => undefined);
    console.error("claude refused", response.status, String(type ?? ""), body.model);
    if (response.status === 429 || response.status >= 500) throw new Refused(503, "Busy right now. Try again in a minute.");
    throw new Refused(502, "That couldn't be done. Try again.");
  }

  let envelope;
  try {
    envelope = await response.json();
  } catch {
    throw new Refused(502, "That couldn't be read. Try again.");
  }
  const blocks = Array.isArray(envelope?.content) ? envelope.content : [];
  return {
    stop: envelope?.stop_reason,
    text: blocks.filter((block) => block?.type === "text").map((block) => block.text || "").join(""),
  };
}

/** Runs an endpoint, turning a `Refused` into its response. */
export async function answer(work) {
  try {
    return json(await work());
  } catch (error) {
    if (error instanceof Refused) return json({ error: error.message }, error.status);
    console.error("ai endpoint failed", String(error?.stack || error));
    return json({ error: "That couldn't be done. Try again." }, 500);
  }
}
