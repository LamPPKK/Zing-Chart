import { copyFile, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { deflateSync } from 'node:zlib';
import path from 'node:path';
import process from 'node:process';

const [platform, outputDirectory, version = '1.0.0'] = process.argv.slice(2);
if (!['webos', 'tizen'].includes(platform) || !outputDirectory) {
  throw new Error('Usage: node prepare_tv_web.mjs <webos|tizen> <output-dir> [version]');
}
if (!/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(version)) {
  throw new Error('TV package version must use x.y.z numeric format.');
}
const versionParts = version.split('.').map(Number);
if (
  platform === 'tizen' &&
  (versionParts[0] > 255 || versionParts[1] > 255 || versionParts[2] > 65535)
) {
  throw new Error('Tizen version components exceed the platform limits.');
}

const indexPath = path.join(outputDirectory, 'index.html');
let index = await readFile(indexPath, 'utf8');
index = index.replace(/<base\s+href="[^"]*"\s*>/i, '<base href="./">');
index = index.replace(/\s*<link rel="manifest"[^>]*>/i, '');
const bootstrapTag = '<script src="flutter_bootstrap.js" async></script>';
if (!index.includes(bootstrapTag)) {
  throw new Error('Flutter bootstrap tag was not found in generated index.html.');
}
if (!index.includes('<script src="tv_remote.js"></script>')) {
  index = index.replace(
    bootstrapTag,
    '<script src="tv_remote.js"></script>\n  ' + bootstrapTag,
  );
}
await writeFile(indexPath, index);
await copyFile(path.join(import.meta.dirname, 'tv_remote.js'), path.join(outputDirectory, 'tv_remote.js'));

const bootstrapPath = path.join(outputDirectory, 'flutter_bootstrap.js');
let bootstrap = await readFile(bootstrapPath, 'utf8');
const withoutServiceWorker = bootstrap.replace(
  /_flutter\.loader\.load\(\{\s*serviceWorkerSettings:\s*\{[\s\S]*?\}\s*\}\);/,
  '_flutter.loader.load();',
);
if (
  withoutServiceWorker === bootstrap &&
  !bootstrap.includes('_flutter.loader.load();')
) {
  throw new Error('Flutter service-worker bootstrap block was not found.');
}
await writeFile(bootstrapPath, withoutServiceWorker);
await rm(path.join(outputDirectory, 'flutter_service_worker.js'), { force: true });
await rm(path.join(outputDirectory, 'manifest.json'), { force: true });
await rm(path.join(outputDirectory, 'icons'), { recursive: true, force: true });

if (platform === 'webos') {
  const appInfo = JSON.parse(
    await readFile(path.join(import.meta.dirname, 'webos', 'appinfo.json'), 'utf8'),
  );
  appInfo.version = version;
  await writeFile(
    path.join(outputDirectory, 'appinfo.json'),
    JSON.stringify(appInfo, null, 2) + '\n',
  );
  await writePng(path.join(outputDirectory, 'icon.png'), 80, 80);
  await writePng(path.join(outputDirectory, 'largeIcon.png'), 130, 130);
} else {
  let config = await readFile(
    path.join(import.meta.dirname, 'tizen', 'config.xml'),
    'utf8',
  );
  config = config.replace('version="1.0.0"', `version="${version}"`);
  await writeFile(path.join(outputDirectory, 'config.xml'), config);
  await writePng(path.join(outputDirectory, 'icon.png'), 117, 117);
}

async function writePng(filePath, width, height) {
  await mkdir(path.dirname(filePath), { recursive: true });
  const stride = width * 4 + 1;
  const raw = Buffer.alloc(stride * height);
  for (let y = 0; y < height; y++) {
    const row = y * stride;
    raw[row] = 0;
    for (let x = 0; x < width; x++) {
      const offset = row + 1 + x * 4;
      const nx = x / width;
      const ny = y / height;
      let color = [23, 24, 27, 255];
      if (nx + ny > 0.55 && nx + ny < 0.72 && nx < 0.72) {
        color = [255, 107, 74, 255];
      }
      if (nx > 0.45 && nx < 0.55 && ny > 0.48 && ny < 0.78) {
        color = [184, 244, 61, 255];
      }
      if (nx > 0.59 && nx < 0.69 && ny > 0.38 && ny < 0.78) {
        color = [184, 244, 61, 255];
      }
      if (nx > 0.73 && nx < 0.83 && ny > 0.27 && ny < 0.78) {
        color = [184, 244, 61, 255];
      }
      raw.set(color, offset);
    }
  }
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header.set([8, 6, 0, 0, 0], 8);
  const png = Buffer.concat([
    signature,
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
  await writeFile(filePath, png);
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
