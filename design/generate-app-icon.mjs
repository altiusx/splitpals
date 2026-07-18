// Generates the SplitPals iOS app icon set from a single SVG definition,
// following the iOS 26 app-icon appearances (Default / Dark / Tinted) with a
// Liquid-Glass treatment on the default tile.
//
// It writes the 1024x1024 PNGs into
//   ../SplitPals/Assets.xcassets/AppIcon.appiconset/
// and the SVG sources next to this script (for future edits).
//
// Requires sharp:  npm i sharp   (or run from a checkout that already has it)
//   node design/generate-app-icon.mjs

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const here = dirname(fileURLToPath(import.meta.url));
const iconset = join(here, "..", "SplitPals", "Assets.xcassets", "AppIcon.appiconset");
mkdirSync(iconset, { recursive: true });

// The alien mascot in a 1024x1024 box centred near (512, 540). `mono` renders a
// flat grey silhouette for the Tinted appearance (iOS applies the tint colour).
function alien({ mono = false } = {}) {
  const skin = mono ? "#CFCFCF" : "url(#skin)";
  const skinStroke = mono ? "#9A9A9A" : "#26893A";
  const antenna = mono ? "#B4B4B4" : "#2FA23A";
  const bulb = mono ? "#DADADA" : "#7CE04A";
  const bulbGlint = mono ? "#FFFFFF" : "#EAFFD4";
  const eye = mono ? "#3A3A3A" : "url(#eye)";
  const reflect = mono ? "#EDEDED" : "#B98BFF";
  return `
    <g stroke="${antenna}" stroke-width="26" fill="none" stroke-linecap="round">
      <path d="M430 300 C 405 210, 360 175, 352 120"/>
      <path d="M594 300 C 619 210, 664 175, 672 120"/>
    </g>
    <circle cx="352" cy="108" r="34" fill="${bulb}"/>
    <circle cx="672" cy="108" r="34" fill="${bulb}"/>
    <circle cx="343" cy="99" r="11" fill="${bulbGlint}" opacity="0.9"/>
    <circle cx="663" cy="99" r="11" fill="${bulbGlint}" opacity="0.9"/>
    <path d="M512 250 C 372 250, 268 344, 268 476 C 268 566, 300 628, 356 686
             C 410 742, 466 792, 512 792 C 558 792, 614 742, 668 686
             C 724 628, 756 566, 756 476 C 756 344, 652 250, 512 250 Z"
          fill="${skin}" stroke="${skinStroke}" stroke-width="16"/>
    ${mono ? "" : `<ellipse cx="360" cy="560" rx="64" ry="46" fill="url(#cheek)"/>
    <ellipse cx="664" cy="560" rx="64" ry="46" fill="url(#cheek)"/>`}
    <path d="M356 430 C 356 500, 404 540, 448 520 C 470 510, 476 470, 468 436 C 460 402, 420 384, 388 396 C 366 404, 356 414, 356 430 Z" fill="${eye}"/>
    <path d="M668 430 C 668 500, 620 540, 576 520 C 554 510, 548 470, 556 436 C 564 402, 604 384, 636 396 C 658 404, 668 414, 668 430 Z" fill="${eye}"/>
    <circle cx="404" cy="444" r="20" fill="#FFFFFF"/>
    <circle cx="444" cy="480" r="10" fill="${reflect}"/>
    <circle cx="616" cy="444" r="20" fill="#FFFFFF"/>
    <circle cx="576" cy="480" r="10" fill="${reflect}"/>
    <path d="M470 636 C 492 660, 532 660, 554 636" fill="none" stroke="${skinStroke}" stroke-width="16" stroke-linecap="round"/>`;
}

const DEFS = `
  <linearGradient id="skin" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#A6F05A"/><stop offset="0.55" stop-color="#5FD23E"/><stop offset="1" stop-color="#2FA23A"/>
  </linearGradient>
  <radialGradient id="cheek" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="#FF6B8A" stop-opacity="0.85"/><stop offset="1" stop-color="#FF6B8A" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="eye" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#15202B"/><stop offset="1" stop-color="#05323A"/>
  </linearGradient>
  <linearGradient id="bg" x1="0.08" y1="0" x2="0.92" y2="1">
    <stop offset="0" stop-color="#9A6BFF"/><stop offset="0.5" stop-color="#6D3DF5"/><stop offset="1" stop-color="#4B1D9E"/>
  </linearGradient>
  <radialGradient id="sheen" cx="0.32" cy="0.20" r="0.9">
    <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.42"/>
    <stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0.10"/>
    <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="vignette" cx="0.5" cy="0.62" r="0.75">
    <stop offset="0.55" stop-color="#000000" stop-opacity="0"/><stop offset="1" stop-color="#000000" stop-opacity="0.22"/>
  </radialGradient>
  <filter id="soft" x="-20%" y="-20%" width="140%" height="140%">
    <feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#12043a" flood-opacity="0.35"/>
  </filter>
  <filter id="halo" x="-40%" y="-40%" width="180%" height="180%">
    <feDropShadow dx="0" dy="0" stdDeviation="26" flood-color="#7CE04A" flood-opacity="0.55"/>
  </filter>`;

const SCALE = 0.74; // alien size within the 1024 tile

// appearance: "default" (glossy purple tile), "dark" (transparent + halo, the
// system supplies the dark base), "tinted" (grey silhouette, system tints it).
function icon(appearance) {
  const S = 1024, cx = 512, cy = 540;
  const g = `translate(${cx} ${cy}) scale(${SCALE}) translate(${-cx} ${-cy})`;
  if (appearance === "default") {
    return `<svg xmlns="http://www.w3.org/2000/svg" width="${S}" height="${S}" viewBox="0 0 ${S} ${S}">
  <defs>${DEFS}</defs>
  <rect width="${S}" height="${S}" fill="url(#bg)"/>
  <rect width="${S}" height="${S}" fill="url(#sheen)"/>
  <rect width="${S}" height="${S}" fill="url(#vignette)"/>
  <g transform="${g}" filter="url(#soft)">${alien()}</g>
</svg>`;
  }
  if (appearance === "dark") {
    return `<svg xmlns="http://www.w3.org/2000/svg" width="${S}" height="${S}" viewBox="0 0 ${S} ${S}">
  <defs>${DEFS}</defs>
  <g transform="${g}" filter="url(#halo)">${alien()}</g>
</svg>`;
  }
  // tinted
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${S}" height="${S}" viewBox="0 0 ${S} ${S}">
  <defs>${DEFS}</defs>
  <g transform="${g}">${alien({ mono: true })}</g>
</svg>`;
}

async function build(appearance, filename, { flatten = false } = {}) {
  const svg = icon(appearance);
  writeFileSync(join(here, `AppIcon-${appearance}.svg`), svg);
  let pipe = sharp(Buffer.from(svg), { density: 384 }).resize(1024, 1024, {
    fit: "contain",
    background: { r: 0, g: 0, b: 0, alpha: 0 },
  });
  // The Default appearance must be fully opaque; Dark/Tinted keep alpha.
  if (flatten) pipe = pipe.flatten({ background: "#6D3DF5" });
  await pipe.png({ compressionLevel: 9 }).toFile(join(iconset, filename));
  console.log(`wrote ${filename}`);
}

await build("default", "AppIcon-default.png", { flatten: true });
await build("dark", "AppIcon-dark.png");
await build("tinted", "AppIcon-tinted.png");

writeFileSync(
  join(iconset, "Contents.json"),
  JSON.stringify(
    {
      images: [
        { filename: "AppIcon-default.png", idiom: "universal", platform: "ios", size: "1024x1024" },
        {
          appearances: [{ appearance: "luminosity", value: "dark" }],
          filename: "AppIcon-dark.png",
          idiom: "universal",
          platform: "ios",
          size: "1024x1024",
        },
        {
          appearances: [{ appearance: "luminosity", value: "tinted" }],
          filename: "AppIcon-tinted.png",
          idiom: "universal",
          platform: "ios",
          size: "1024x1024",
        },
      ],
      info: { author: "xcode", version: 1 },
    },
    null,
    2,
  ) + "\n",
);
console.log("wrote Contents.json");
