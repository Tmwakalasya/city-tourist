// What the two AI endpoints share: the Claude key stays here on the server,
// the prompts and models are ours rather than the caller's, and every call is
// counted against limits before it costs anything.
//
// The endpoints are public: nothing proves a request came from the app. What
// keeps that safe is that a caller can't choose the model, the prompt, the
// output shape or the size, and that the number of calls a day is capped.

import { json, readJSON, underIPLimit } from "./request.js";

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
 * Counts this call against the caller's hourly allowance and the whole
 * service's daily one. Without the KV binding nothing can be counted, so
 * nothing is allowed: an uncounted endpoint is an open tab on the key.
 */
export async function allow(env, request, name, { perIPPerHour, perDay }) {
  if (!env.ANTHROPIC_API_KEY || !env.SIGNUPS) {
    throw new Refused(503, "This isn't switched on yet.");
  }
  if (!(await underIPLimit(env, request, `ai-${name}`, perIPPerHour))) {
    throw new Refused(429, "Too many requests from here. Try again in an hour.");
  }
  const day = `ai-${name}:${new Date().toISOString().slice(0, 10)}`;
  const used = Number(await env.SIGNUPS.get(day)) || 0;
  if (used >= perDay) throw new Refused(429, "That's all for today. Try again tomorrow.");
  await env.SIGNUPS.put(day, String(used + 1), { expirationTtl: 2 * 86400 });
}

/** A daily cap from the project's variables, or the default. */
export function cap(value, fallback) {
  const number = Number(value);
  return Number.isInteger(number) && number >= 0 ? number : fallback;
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
  if (response.status === 429 || response.status >= 500) throw new Refused(503, "Busy right now. Try again in a minute.");
  if (!response.ok) throw new Refused(502, "That couldn't be done. Try again.");

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
    return json({ error: "That couldn't be done. Try again." }, 500);
  }
}
