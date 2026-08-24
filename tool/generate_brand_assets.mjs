import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { deflateSync } from 'node:zlib';
import path from 'node:path';
import process from 'node:process';

const repositoryRoot = path.resolve(import.meta.dirname, '..');
const checkOnly = process.argv.includes('--check');

const palette = {
  ink: [16, 17, 19],
  plum: [46, 24, 52],
  coral: [255, 107, 74],
  coralLight: [255, 139, 111],
  lime: [184, 244, 61],
};

const rasterTargets = [
  ['web/favicon.png', 32, 0.92],
  ['web/icons/Icon-192.png', 192, 0.92],
  ['web/icons/Icon-512.png', 512, 0.92],
  ['web/icons/Icon-maskable-192.png', 192, 0.72],
  ['web/icons/Icon-maskable-512.png', 512, 0.72],
  ['android/app/src/main/res/mipmap-mdpi/ic_launcher.png', 48, 0.92],
  ['android/app/src/main/res/mipmap-hdpi/ic_launcher.png', 72, 0.92],
  ['android/app/src/main/res/mipmap-xhdpi/ic_launcher.png', 96, 0.92],
  ['android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png', 144, 0.92],
  ['android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png', 192, 0.92],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png', 20, 0.92],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png', 40, 0.92],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png', 60, 0.92],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png', 29, 0.92],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png', 58, 0.92],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png', 87, 0.92],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png', 40, 0.92],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png', 80, 0.92],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png', 120, 0.92],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png', 120, 0.92],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png', 180, 0.92],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png', 76, 0.92],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png', 152, 0.92],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png', 167, 0.92],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png', 1024, 0.92],
  ['ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png', 168, 0.76],
  ['ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png', 336, 0.76],
  ['ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png', 504, 0.76],
  ['ios/ZingChartWatch/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png', 1024, 0.82],
  ['macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png', 16, 0.82, 'rounded'],
  ['macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png', 32, 0.82, 'rounded'],
  ['macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png', 64, 0.82, 'rounded'],
  ['macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png', 128, 0.82, 'rounded'],
  ['macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png', 256, 0.82, 'rounded'],
  ['macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png', 512, 0.82, 'rounded'],
  ['macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png', 1024, 0.82, 'rounded'],
  ['packaging/tv/assets/icon-80.png', 80, 0.8],
  ['packaging/tv/assets/icon-117.png', 117, 0.8],
  ['packaging/tv/assets/icon-130.png', 130, 0.8],
  ['packaging/harmonyos/app_icon.png', 1024, 0.78],
];

const pngCache = new Map();
for (const [relativePath, size, markScale, variant = 'opaque'] of rasterTargets) {
  const key = `${size}:${markScale}:${variant}`;
  let png = pngCache.get(key);
  if (!png) {
    const rgb = renderIcon(size, markScale);
    png = variant === 'rounded'
      ? encodeRgbaPng(applyRoundedMask(rgb, size), size, size)
      : encodePng(rgb, size, size);
    pngCache.set(key, png);
  }
  await emit(relativePath, png);
}

await emit('assets/brand/zingchart-mark.svg', Buffer.from(canonicalSvg()));
await emit('windows/runner/resources/app_icon.ico', buildIco());

if (checkOnly) {
  process.stdout.write('Brand assets are current.\n');
} else {
  process.stdout.write(`Generated ${rasterTargets.length + 2} brand assets.\n`);
}

async function emit(relativePath, contents) {
  const destination = path.join(repositoryRoot, relativePath);
  if (checkOnly) {
    let current;
    try {
      current = await readFile(destination);
    } catch {
      throw new Error(`Missing generated brand asset: ${relativePath}`);
    }
    if (!current.equals(contents)) {
      throw new Error(`Stale generated brand asset: ${relativePath}`);
    }
    return;
  }
  await mkdir(path.dirname(destination), { recursive: true });
  await writeFile(destination, contents);
}

function renderIcon(size, markScale) {
  const supersample = size <= 32 ? 8 : size <= 192 ? 4 : size <= 512 ? 2 : 2;
  const width = size * supersample;
  const rgba = Buffer.alloc(width * width * 4);

  for (let y = 0; y < width; y++) {
    for (let x = 0; x < width; x++) {
      const nx = x / Math.max(1, width - 1);
      const ny = y / Math.max(1, width - 1);
      const plumGlow = Math.max(0, 1 - Math.hypot(nx - 0.72, ny - 0.22) / 0.92);
      const coralGlow = Math.max(0, 1 - Math.hypot(nx - 0.18, ny - 0.82) / 0.82);
      const vignette = Math.min(1, Math.hypot(nx - 0.5, ny - 0.5) / 0.72);
      const noise = (((x * 17) ^ (y * 29) ^ (x * y)) & 7) - 3;
      const index = (y * width + x) * 4;
      rgba[index] = clampByte(
        palette.ink[0] + plumGlow * 18 + coralGlow * 7 - vignette * 3 + noise * 0.35,
      );
      rgba[index + 1] = clampByte(
        palette.ink[1] + plumGlow * 6 + coralGlow * 2 - vignette * 3 + noise * 0.25,
      );
      rgba[index + 2] = clampByte(
        palette.ink[2] + plumGlow * 23 + coralGlow * 6 - vignette * 2 + noise * 0.4,
      );
      rgba[index + 3] = 255;
    }
  }

  const point = (x, y) => [
    (0.5 + (x - 0.5) * markScale) * width,
    (0.5 + (y - 0.5) * markScale) * width,
  ];
  const stroke = (value) => value * markScale * width;
  const coralGlow = [...palette.coral, 42];

  const verticals = [
    [point(0.38, 0.22), point(0.34, 0.78)],
    [point(0.64, 0.22), point(0.60, 0.78)],
  ];
  const horizontals = [
    [point(0.23, 0.41), point(0.77, 0.37)],
    [point(0.21, 0.65), point(0.75, 0.61)],
  ];

  for (const [start, end] of [...verticals, ...horizontals]) {
    drawCapsule(rgba, width, start, end, stroke(0.13), coralGlow);
  }
  for (const [start, end] of verticals) {
    drawCapsule(rgba, width, start, end, stroke(0.074), [...palette.coral, 255]);
  }
  for (const [start, end] of horizontals) {
    drawCapsule(rgba, width, start, end, stroke(0.074), [...palette.coralLight, 255]);
  }

  const wave = [
    point(0.18, 0.54),
    point(0.3, 0.54),
    point(0.37, 0.46),
    point(0.45, 0.66),
    point(0.55, 0.36),
    point(0.64, 0.54),
    point(0.82, 0.54),
  ];
  for (let index = 0; index < wave.length - 1; index++) {
    drawCapsule(
      rgba,
      width,
      wave[index],
      wave[index + 1],
      stroke(0.046),
      [...palette.lime, 255],
    );
  }
  drawCircle(rgba, width, point(0.82, 0.54), stroke(0.034), [245, 255, 210, 255]);

  return downsampleRgb(rgba, width, size, supersample);
}

function drawCapsule(buffer, width, start, end, thickness, color) {
  const radius = thickness / 2;
  const minX = Math.max(0, Math.floor(Math.min(start[0], end[0]) - radius - 2));
  const maxX = Math.min(width - 1, Math.ceil(Math.max(start[0], end[0]) + radius + 2));
  const minY = Math.max(0, Math.floor(Math.min(start[1], end[1]) - radius - 2));
  const maxY = Math.min(width - 1, Math.ceil(Math.max(start[1], end[1]) + radius + 2));
  const dx = end[0] - start[0];
  const dy = end[1] - start[1];
  const lengthSquared = dx * dx + dy * dy || 1;
  for (let y = minY; y <= maxY; y++) {
    for (let x = minX; x <= maxX; x++) {
      const projection = Math.max(
        0,
        Math.min(1, ((x - start[0]) * dx + (y - start[1]) * dy) / lengthSquared),
      );
      const nearestX = start[0] + projection * dx;
      const nearestY = start[1] + projection * dy;
      const distance = Math.hypot(x - nearestX, y - nearestY);
      const coverage = Math.max(0, Math.min(1, radius + 0.8 - distance));
      if (coverage > 0) blend(buffer, (y * width + x) * 4, color, coverage);
    }
  }
}

function drawCircle(buffer, width, center, radius, color) {
  drawCapsule(buffer, width, center, center, radius * 2, color);
}

function blend(buffer, offset, color, coverage) {
  const alpha = (color[3] / 255) * coverage;
  const inverse = 1 - alpha;
  buffer[offset] = clampByte(buffer[offset] * inverse + color[0] * alpha);
  buffer[offset + 1] = clampByte(buffer[offset + 1] * inverse + color[1] * alpha);
  buffer[offset + 2] = clampByte(buffer[offset + 2] * inverse + color[2] * alpha);
}

function downsampleRgb(rgba, sourceSize, targetSize, scale) {
  const rgb = Buffer.alloc(targetSize * targetSize * 3);
  const samples = scale * scale;
  for (let y = 0; y < targetSize; y++) {
    for (let x = 0; x < targetSize; x++) {
      let red = 0;
      let green = 0;
      let blue = 0;
      for (let sy = 0; sy < scale; sy++) {
        for (let sx = 0; sx < scale; sx++) {
          const source = ((y * scale + sy) * sourceSize + x * scale + sx) * 4;
          red += rgba[source];
          green += rgba[source + 1];
          blue += rgba[source + 2];
        }
      }
      const target = (y * targetSize + x) * 3;
      rgb[target] = Math.round(red / samples);
      rgb[target + 1] = Math.round(green / samples);
      rgb[target + 2] = Math.round(blue / samples);
    }
  }
  return rgb;
}

function encodePng(rgb, width, height) {
  const stride = width * 3 + 1;
  const raw = Buffer.alloc(stride * height);
  for (let y = 0; y < height; y++) {
    const row = y * stride;
    raw[row] = 0;
    rgb.copy(raw, row + 1, y * width * 3, (y + 1) * width * 3);
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header.set([8, 2, 0, 0, 0], 8);
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function applyRoundedMask(rgb, size) {
  const rgba = Buffer.alloc(size * size * 4);
  const half = 0.44;
  const radius = 0.19;
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const nx = (x + 0.5) / size - 0.5;
      const ny = (y + 0.5) / size - 0.5;
      const qx = Math.abs(nx) - (half - radius);
      const qy = Math.abs(ny) - (half - radius);
      const distance =
        Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) +
        Math.min(Math.max(qx, qy), 0) -
        radius;
      const alpha = clampByte((0.5 - distance * size) * 255);
      const source = (y * size + x) * 3;
      const target = (y * size + x) * 4;
      rgba[target] = rgb[source];
      rgba[target + 1] = rgb[source + 1];
      rgba[target + 2] = rgb[source + 2];
      rgba[target + 3] = alpha;
    }
  }
  return rgba;
}

function encodeRgbaPng(rgba, width, height) {
  const stride = width * 4 + 1;
  const raw = Buffer.alloc(stride * height);
  for (let y = 0; y < height; y++) {
    const row = y * stride;
    raw[row] = 0;
    rgba.copy(raw, row + 1, y * width * 4, (y + 1) * width * 4);
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header.set([8, 6, 0, 0, 0], 8);
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function buildIco() {
  const sizes = [16, 24, 32, 48, 64, 128, 256];
  const images = sizes.map((size) => {
    const key = `${size}:0.92:opaque`;
    return pngCache.get(key) ?? encodePng(renderIcon(size, 0.92), size, size);
  });
  const header = Buffer.alloc(6 + sizes.length * 16);
  header.writeUInt16LE(0, 0);
  header.writeUInt16LE(1, 2);
  header.writeUInt16LE(sizes.length, 4);
  let offset = header.length;
  sizes.forEach((size, index) => {
    const entry = 6 + index * 16;
    header[entry] = size === 256 ? 0 : size;
    header[entry + 1] = size === 256 ? 0 : size;
    header[entry + 2] = 0;
    header[entry + 3] = 0;
    header.writeUInt16LE(1, entry + 4);
    header.writeUInt16LE(32, entry + 6);
    header.writeUInt32LE(images[index].length, entry + 8);
    header.writeUInt32LE(offset, entry + 12);
    offset += images[index].length;
  });
  return Buffer.concat([header, ...images]);
}

function canonicalSvg() {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-labelledby="title desc">
  <title id="title">#zingChart app mark</title>
  <desc id="desc">A coral hash crossed by a lime audio pulse on a dark plum field.</desc>
  <defs>
    <radialGradient id="background" cx="72%" cy="22%" r="92%">
      <stop offset="0" stop-color="#2E1834"/>
      <stop offset="0.62" stop-color="#171319"/>
      <stop offset="1" stop-color="#101113"/>
    </radialGradient>
    <filter id="glow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="24"/>
    </filter>
  </defs>
  <rect width="1024" height="1024" fill="url(#background)"/>
  <g fill="none" stroke="#FF6B4A" stroke-linecap="round" stroke-width="74">
    <path opacity=".18" filter="url(#glow)" stroke-width="132" d="M390 230L352 794M654 230L616 794M236 420L788 378M216 664L768 622"/>
    <path d="M390 230L352 794M654 230L616 794"/>
  </g>
  <path fill="none" stroke="#FF8B6F" stroke-linecap="round" stroke-width="74" d="M236 420L788 378M216 664L768 622"/>
  <path fill="none" stroke="#B8F43D" stroke-linecap="round" stroke-linejoin="round" stroke-width="46" d="M184 553H307L379 471L461 676L563 369L655 553H840"/>
  <circle cx="840" cy="553" r="34" fill="#F5FFD2"/>
</svg>\n`;
}

function chunk(type, data) {
  const name = Buffer.from(type, 'ascii');
  const result = Buffer.alloc(data.length + 12);
  result.writeUInt32BE(data.length, 0);
  name.copy(result, 4);
  data.copy(result, 8);
  result.writeUInt32BE(crc32(Buffer.concat([name, data])), data.length + 8);
  return result;
}

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) {
      crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function clampByte(value) {
  return Math.max(0, Math.min(255, Math.round(value)));
}
