#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const root = path.resolve(__dirname, "..");

const pages = [
  ["router/www/index.html", "router/www/app.js", "router/www/styles.css"],
  ["router/admin/index.html", "router/admin/app.js", "router/admin/styles.css"],
  ["firebase/dashboard/index.html", "firebase/dashboard/app.js", "firebase/dashboard/styles.css"]
];

for (const [htmlName, jsName, cssName] of pages) {
  const html = fs.readFileSync(path.join(root, htmlName), "utf8");
  const js = fs.readFileSync(path.join(root, jsName), "utf8");
  const css = fs.readFileSync(path.join(root, cssName), "utf8");
  const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]);
  const duplicate = ids.find((id, index) => ids.indexOf(id) !== index);
  if (duplicate) throw new Error(`${htmlName}: duplicate id ${duplicate}`);

  const selectors = [...js.matchAll(/(?:querySelector|\$)\("#([A-Za-z][\w-]*)"\)/g)].map(match => match[1]);
  for (const id of selectors) {
    if (!ids.includes(id)) throw new Error(`${jsName}: #${id} is missing from ${htmlName}`);
  }

  let depth = 0;
  for (const character of css.replace(/\/\*[\s\S]*?\*\//g, "")) {
    if (character === "{") depth += 1;
    if (character === "}") depth -= 1;
    if (depth < 0) throw new Error(`${cssName}: closing brace without opener`);
  }
  if (depth !== 0) throw new Error(`${cssName}: unbalanced braces`);
  if (!html.includes('name="theme-color" content="#f4f7fb"')) throw new Error(`${htmlName}: light theme color missing`);
}

const portalCss = fs.readFileSync(path.join(root, "router/www/styles.css"), "utf8");
const portalJs = fs.readFileSync(path.join(root, "router/www/app.js"), "utf8");
const firebaseJs = fs.readFileSync(path.join(root, "firebase/dashboard/app.js"), "utf8");
if (!/html, body\s*\{[^}]*overflow:\s*hidden/s.test(portalCss)) throw new Error("customer portal must stay one-screen on mobile");
if (!portalJs.includes("new URLSearchParams")) throw new Error("customer portal form encoding is missing");
if (!firebaseJs.includes("revision:Date.now()")) throw new Error("Firebase revisions must not collide within one second");

console.log("PASS: UI IDs, selectors, CSS, light theme, one-screen portal, and unique cloud revisions verified");
