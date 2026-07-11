// renderer/googleFont.test.ts
import { fetchGoogleFontFiles } from "./googleFont";
import { mkdtempSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import assert from "node:assert";

const dir = mkdtempSync(join(tmpdir(), "font-test-"));

// Known family downloads at least one non-trivial ttf and reports a family name.
const { files, family } = await fetchGoogleFontFiles("Comic Neue", dir);
assert(files.length >= 1, "expected at least one ttf");
for (const f of files) {
  assert(f.endsWith(".ttf"), `not a ttf path: ${f}`);
  assert(statSync(f).size > 1000, `ttf too small: ${f}`);
}
// The internal family name is read from the TTF name table; for Comic Neue it
// should come back as the real font name, not empty.
assert(/comic/i.test(family), `expected a Comic Neue family name, got "${family}"`);
console.log("PASS: downloads ttf files and resolves family", family, files);

// Unknown family throws.
let threw = false;
try {
  await fetchGoogleFontFiles("No Such Family ZZZ 999", dir);
} catch {
  threw = true;
}
assert(threw, "expected throw on unknown family");
console.log("PASS: unknown family throws");

// Empty family throws.
let threwEmpty = false;
try {
  await fetchGoogleFontFiles("  ", dir);
} catch {
  threwEmpty = true;
}
assert(threwEmpty, "expected throw on empty family");
console.log("PASS: empty family throws");
