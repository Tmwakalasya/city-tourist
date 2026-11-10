// node --test 'launch/tests/*.test.mjs'
// The shared-itinerary viewer against a stand-in for the page.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const source = readFileSync(new URL("../public/trip.js", import.meta.url), "utf8");

/// Just enough of a document for the viewer to build its tree in.
function node(tag) {
  return {
    tag, className: "", textContent: "", style: {}, children: [],
    appendChild(child) { this.children.push(child); return child; },
    set innerHTML(html) {
      this.children = [];
      if (html.includes("state")) {
        const heading = node("h1"), text = node("p");
        this.children = [heading, text];
      }
    },
    querySelector(tag) { return this.children.find((child) => child.tag === tag); },
  };
}

function all(root) {
  return [root, ...root.children.flatMap(all)];
}

function open(hash) {
  const root = node("div");
  const document = { title: "", getElementById: () => root, createElement: node };
  const window = { addEventListener() {} };
  new Function("document", "window", "location", source)(document, window, { hash });
  return { root, document };
}

function link(itinerary) {
  return "#i=" + Buffer.from(JSON.stringify(itinerary)).toString("base64url");
}

// The keys the app writes; see SharedItinerary in ShareLinkBuilder.swift.
const lisbon = {
  v: 1, title: "Lisbon with Sam", city: "Lisbon, Portugal",
  days: [
    { d: "2026-11-16", stops: [
      { t: 600, n: "Belém Tower", b: "River fort", m: 75, lat: 38.69, lon: -9.21 },
      { t: 780, n: "Pastéis de Belém", m: 40, note: "Cash only" } ] },
    { d: "2026-11-17", stops: [] },
  ],
};

test("a shared trip shows its days, stops and notes", () => {
  const { root, document } = open(link(lisbon));
  const text = all(root).map((n) => n.textContent);

  assert.equal(document.title, "Lisbon with Sam · City Tourist");
  for (const expected of ["Lisbon with Sam", "Lisbon, Portugal · 2 days", "Belém Tower", "River fort",
                          "Pastéis de Belém", "Cash only", "1 hr 15 min", "Nothing planned."]) {
    assert.ok(text.includes(expected), expected);
  }
  const maps = all(root).filter((n) => n.className === "maps");
  assert.equal(maps.length, 1, "only a stop with coordinates links to a map");
  assert.match(maps[0].href, /query=38\.69,-9\.21$/);
});

test("a shared trip ends by inviting its reader to the app", () => {
  const { root } = open(link(lisbon));
  const invite = all(root).find((n) => n.className === "invite");

  assert.ok(invite, "the invitation is on the page");
  const button = invite.children.find((n) => n.tag === "a");
  assert.equal(button.textContent, "Get City Tourist");
  assert.equal(button.href, "/", "the launch page knows where the app is available");
});

test("no link, or a broken one, says so and shows no itinerary", () => {
  for (const hash of ["", "#i=not-an-itinerary", link({ title: "No days" })]) {
    const { root } = open(hash);
    assert.ok(root.children[0].textContent.length > 0, "a heading explains what happened");
    assert.equal(all(root).filter((n) => n.className === "invite").length, 0);
  }
});
