import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { ZingUpstream } from './upstream.js';

const config = loadConfig();
const app = await buildApp(config, new ZingUpstream(config));

try {
  await app.listen({ host: config.host, port: config.port });
} catch (error) {
  app.log.error(error);
  process.exitCode = 1;
}
