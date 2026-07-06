/**
 * Render a star history chart to an SVG file using star-history's own code.
 *
 * This mirrors the SVG generation in star-history's backend/main.ts: build a
 * JSDOM svg element, fetch stargazer data with getRepoData, draw it with the
 * XYChart renderer in node mode, then optimize with svgo. No browser, no
 * third-party CLI. The vendored star-history source lives under vendor/shared
 * (see vendor/LICENSE and NOTICE.md for attribution).
 *
 * Usage:
 *   tsx render.ts --repos owner/repo[,owner/repo2] --token <t> \
 *     --theme light|dark --type Date|Timeline --width <px> --output <file>
 */
import { JSDOM } from "jsdom";
import { optimize } from "svgo";
import XYChart from "./vendor/shared/packages/xy-chart";
import { convertDataToChartData, getRepoData } from "./vendor/shared/common/chart";
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";

// star-history fetches at most this many pages of stargazers per repo.
const MAX_REQUEST_AMOUNT = 16;

// JSDOM lowercases camelCase SVG names; restore the ones D3's filter emits.
// Copied from star-history backend/utils.ts.
function fixJsdomSvgCasing(svgContent: string): string {
  return svgContent
    .replace(/feturbulence/g, "feTurbulence")
    .replace(/fedisplacementmap/g, "feDisplacementMap")
    .replace(/filterunits/g, "filterUnits")
    .replace(/basefrequency/g, "baseFrequency")
    .replace(/xchannelselector/g, "xChannelSelector")
    .replace(/ychannelselector/g, "yChannelSelector");
}

// The chart draws the repo/owner logo as <image href="https://avatars...">.
// GitHub sanitizes committed SVGs and blocks external image refs, so those show
// as broken-image boxes. Inline each external image as a base64 data URL, the
// same thing star-history's own browser export does before saving.
async function inlineExternalImages(svg: SVGSVGElement): Promise<void> {
  const images = Array.from(svg.querySelectorAll("image"));
  await Promise.all(
    images.map(async (img) => {
      const href = img.getAttribute("href") || img.getAttribute("xlink:href");
      if (!href || !/^https?:\/\//i.test(href)) return;
      try {
        const res = await fetch(href, { signal: AbortSignal.timeout(10000) });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const buf = Buffer.from(await res.arrayBuffer());
        const type = res.headers.get("content-type") || "image/png";
        img.setAttribute("href", `data:${type};base64,${buf.toString("base64")}`);
      } catch (e) {
        // Drop an unreachable logo rather than leaving a broken external ref.
        img.remove();
        process.stderr.write(`Inlined image failed (${href}), removed: ${e}\n`);
      }
    })
  );
}

function parseArgs(argv: string[]): Record<string, string> {
  const out: Record<string, string> = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      out[a.slice(2)] = argv[i + 1];
      i++;
    }
  }
  return out;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const repos = (args.repos || "").split(",").map((r) => r.trim()).filter(Boolean);
  const token = args.token || process.env.GITHUB_TOKEN || "";
  const theme = args.theme === "dark" ? "dark" : "light";
  const type = args.type === "Timeline" ? "Timeline" : "Date";
  const width = Number(args.width) || 800;
  const output = args.output;

  if (repos.length === 0) throw new Error("--repos is required");
  if (!output) throw new Error("--output is required");
  if (!token) throw new Error("--token (or GITHUB_TOKEN env) is required");

  const repoData = await getRepoData(repos, token, MAX_REQUEST_AMOUNT);

  const dom = new JSDOM(`<!DOCTYPE html><body></body>`);
  const body = dom.window.document.querySelector("body")!;
  const svg = dom.window.document.createElement("svg") as unknown as SVGSVGElement;
  body.append(svg);
  svg.setAttribute("width", `${width}`);
  svg.setAttribute("xmlns", "http://www.w3.org/2000/svg");

  XYChart(
    svg,
    {
      title: "Star History",
      xLabel: type === "Date" ? "Date" : "Timeline",
      yLabel: "GitHub Stars",
      data: convertDataToChartData(repoData, type, { insertZeroPoint: true }),
      showDots: false,
      transparent: false,
      theme,
    },
    {
      xTickLabelType: type === "Date" ? "Date" : "Number",
      chartWidth: width,
    }
  );

  await inlineExternalImages(svg);

  const svgContent = fixJsdomSvgCasing(svg.outerHTML);
  const optimized = optimize(svgContent, { multipass: true }).data;

  mkdirSync(dirname(output), { recursive: true });
  writeFileSync(output, optimized, "utf-8");
  process.stderr.write(`Wrote ${output} (${optimized.length} bytes)\n`);
}

main().catch((err) => {
  const msg = err?.message || String(err);
  const status = err?.status ? ` [status ${err.status}]` : "";
  process.stderr.write(`Render failed${status}: ${msg}\n`);
  process.exit(1);
});
