import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const script = path.resolve(import.meta.dirname, 'prepare_tv_web.mjs');
const generatedIndex = `<!doctype html>
<html><head><base href="/"><link rel="manifest" href="manifest.json"></head>
<body><script src="flutter_bootstrap.js" async></script></body></html>`;
const generatedBootstrap = `_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: "test-version"
  }
});`;

test('prepares a relative, remote-enabled Tizen TV project', async () => {
  const output = await temporaryOutput();
  runPrepare('tizen', output, '2.3.4');

  const index = await readFile(path.join(output, 'index.html'), 'utf8');
  const bootstrap = await readFile(
    path.join(output, 'flutter_bootstrap.js'),
    'utf8',
  );
  const config = await readFile(path.join(output, 'config.xml'), 'utf8');
  const icon = await readFile(path.join(output, 'icon.png'));
  assert.match(index, /<base href="\.\/">/);
  assert.ok(!index.includes('rel="manifest"'));
  assert.ok(index.indexOf('tv_remote.js') < index.indexOf('flutter_bootstrap.js'));
  assert.equal(bootstrap.trim(), '_flutter.loader.load();');
  assert.match(config, /version="2\.3\.4"/);
  assert.match(config, /required_version="8\.0"/);
  assert.match(config, /devel\.api\.version/);
  assert.match(config, /tv\.inputdevice/);
  assert.deepEqual([...icon.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
  assert.equal(icon.readUInt32BE(16), 117);
  assert.equal(icon.readUInt32BE(20), 117);
  assert.equal(icon[25], 2, 'Tizen icon must be opaque RGB PNG');
  assert.deepEqual(
    icon,
    await readFile(path.join(import.meta.dirname, 'assets/icon-117.png')),
  );
});

test('prepares valid webOS metadata and required icon sizes', async () => {
  const output = await temporaryOutput();
  runPrepare('webos', output, '5.6.7');

  const appInfo = JSON.parse(await readFile(path.join(output, 'appinfo.json')));
  const icon = await readFile(path.join(output, 'icon.png'));
  const largeIcon = await readFile(path.join(output, 'largeIcon.png'));
  assert.equal(appInfo.id, 'software.baycho.app.zingchart');
  assert.equal(appInfo.version, '5.6.7');
  assert.equal(appInfo.main, 'index.html');
  assert.equal(appInfo.disableBackHistoryAPI, true);
  assert.equal(icon.readUInt32BE(16), 80);
  assert.equal(icon.readUInt32BE(20), 80);
  assert.equal(largeIcon.readUInt32BE(16), 130);
  assert.equal(largeIcon.readUInt32BE(20), 130);
  assert.equal(icon[25], 2, 'webOS icon must be opaque RGB PNG');
  assert.deepEqual(
    largeIcon,
    await readFile(path.join(import.meta.dirname, 'assets/icon-130.png')),
  );
});

async function temporaryOutput() {
  const output = await mkdtemp(path.join(os.tmpdir(), 'zingchart-tv-test-'));
  await writeFile(path.join(output, 'index.html'), generatedIndex);
  await writeFile(path.join(output, 'flutter_bootstrap.js'), generatedBootstrap);
  return output;
}

function runPrepare(platform, output, version) {
  const result = spawnSync(process.execPath, [script, platform, output, version], {
    encoding: 'utf8',
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
}
