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

// The SplitPals "pal" is a round chibi cat-alien: pastel-mint head, little cat
// ears, tiny antennae, big sparkly eyes, blush, no mouth. Drawn in a 1024x1024
// box centred near (512, 560). `mono` renders a flat grey silhouette for the
// Tinted appearance (iOS applies the tint colour by luminance).
function alien({ mono = false } = {}) {
  const skin = mono ? "#D2D2D2" : "url(#skin)";
  const stroke = mono ? "#A8A8A8" : "#8FD6A6";
  const earIn = mono ? "#BEBEBE" : "url(#earIn)";
  const antenna = mono ? "#B4B4B4" : "#8FD6A6";
  const bulb = mono ? "#DADADA" : "#FFD98A";
  const eye = mono ? "#4A4A4A" : "url(#eye)";
  const cheek = mono ? "none" : "url(#cheek)";
  const spark2 = mono ? "#E8E8E8" : "#CDB8FF";
  return `
    <g stroke="${antenna}" stroke-width="24" fill="none" stroke-linecap="round">
      <path d="M452 300 C 440 220, 420 205, 430 150"/>
      <path d="M572 300 C 584 220, 604 205, 594 150"/>
    </g>
    <circle cx="430" cy="140" r="30" fill="${bulb}"/>
    <circle cx="594" cy="140" r="30" fill="${bulb}"/>
    <circle cx="421" cy="132" r="10" fill="#FFF3D6" opacity="0.95"/>
    <circle cx="585" cy="132" r="10" fill="#FFF3D6" opacity="0.95"/>
    <path d="M330 360 C 300 250, 320 205, 372 232 C 424 258, 452 320, 452 360 Z"
          fill="${skin}" stroke="${stroke}" stroke-width="16" stroke-linejoin="round"/>
    <path d="M694 360 C 724 250, 704 205, 652 232 C 600 258, 572 320, 572 360 Z"
          fill="${skin}" stroke="${stroke}" stroke-width="16" stroke-linejoin="round"/>
    ${mono ? "" : `<path d="M356 336 C 344 275, 356 252, 384 268 C 410 283, 420 318, 418 344 Z" fill="${earIn}"/>
    <path d="M668 336 C 680 275, 668 252, 640 268 C 614 283, 604 318, 606 344 Z" fill="${earIn}"/>`}
    <ellipse cx="512" cy="565" rx="300" ry="285" fill="${skin}" stroke="${stroke}" stroke-width="16"/>
    ${mono ? "" : `<ellipse cx="322" cy="702" rx="74" ry="48" fill="${cheek}"/>
    <ellipse cx="702" cy="702" rx="74" ry="48" fill="${cheek}"/>`}
    <ellipse cx="410" cy="580" rx="86" ry="104" fill="${eye}"/>
    <ellipse cx="614" cy="580" rx="86" ry="104" fill="${eye}"/>
    <circle cx="392" cy="548" r="30" fill="#FFFFFF"/>
    <circle cx="596" cy="548" r="30" fill="#FFFFFF"/>
    <circle cx="432" cy="608" r="15" fill="${spark2}"/>
    <circle cx="636" cy="608" r="15" fill="${spark2}"/>
    <circle cx="420" cy="560" r="9" fill="#FFFFFF" opacity="0.9"/>
    <circle cx="624" cy="560" r="9" fill="#FFFFFF" opacity="0.9"/>`;
}

const DEFS = `
  <linearGradient id="skin" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#D6F7DD"/><stop offset="0.55" stop-color="#B4EDC2"/><stop offset="1" stop-color="#9CE3AE"/>
  </linearGradient>
  <linearGradient id="earIn" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#FFD3E2"/><stop offset="1" stop-color="#FBB9D0"/>
  </linearGradient>
  <radialGradient id="cheek" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="#FF8FB6" stop-opacity="0.9"/><stop offset="0.7" stop-color="#FF9FC0" stop-opacity="0.35"/><stop offset="1" stop-color="#FF9FC0" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="eye" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#5A4B86"/><stop offset="1" stop-color="#3A2F5B"/>
  </linearGradient>
  <linearGradient id="bg" x1="0.1" y1="0" x2="0.9" y2="1">
    <stop offset="0" stop-color="#E7DEFF"/><stop offset="0.5" stop-color="#CFC2F7"/><stop offset="1" stop-color="#B3A4EE"/>
  </linearGradient>
  <radialGradient id="sheen" cx="0.32" cy="0.2" r="0.9">
    <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.5"/>
    <stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0.12"/>
    <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="vignette" cx="0.5" cy="0.62" r="0.78">
    <stop offset="0.55" stop-color="#6A4FB0" stop-opacity="0"/><stop offset="1" stop-color="#6A4FB0" stop-opacity="0.22"/>
  </radialGradient>
  <filter id="soft" x="-20%" y="-20%" width="140%" height="140%">
    <feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#5B3FA0" flood-opacity="0.3"/>
  </filter>
  <filter id="halo" x="-40%" y="-40%" width="180%" height="180%">
    <feDropShadow dx="0" dy="0" stdDeviation="24" flood-color="#BCE8C6" flood-opacity="0.6"/>
  </filter>`;

const SCALE = 0.92; // alien size within the 1024 tile

// appearance: "default" (glossy pastel tile), "dark" (transparent + halo, the
// system supplies the dark base), "tinted" (grey silhouette, system tints it).
function icon(appearance) {
  const S = 1024, cx = 512, cy = 560;
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
  if (flatten) pipe = pipe.flatten({ background: "#CFC2F7" });
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
