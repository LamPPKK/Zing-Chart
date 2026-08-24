import { copyFile, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
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
  await copyBrandIcon('icon-80.png', 'icon.png');
  await copyBrandIcon('icon-130.png', 'largeIcon.png');
} else {
  let config = await readFile(
    path.join(import.meta.dirname, 'tizen', 'config.xml'),
    'utf8',
  );
  config = config.replace('version="1.0.0"', `version="${version}"`);
  await writeFile(path.join(outputDirectory, 'config.xml'), config);
  await copyBrandIcon('icon-117.png', 'icon.png');
}

async function copyBrandIcon(sourceName, destinationName) {
  const destination = path.join(outputDirectory, destinationName);
  await mkdir(path.dirname(destination), { recursive: true });
  await copyFile(
    path.join(import.meta.dirname, 'assets', sourceName),
    destination,
  );
}
