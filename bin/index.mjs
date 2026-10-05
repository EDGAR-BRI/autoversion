#!/usr/bin/env node
import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const installScript = path.resolve(__dirname, '../install.sh');

const child = spawn('bash', [installScript, ...process.argv.slice(2)], {
  stdio: 'inherit',
  cwd: process.cwd()
});

child.on('exit', code => {
  process.exit(code ?? 0);
});
