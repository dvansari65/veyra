import { createHash } from 'node:crypto';
import { chmod, mkdir, readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

// Checksum-pinned native compiler; no global writes and no Python dependency.
const builds = {
  darwin: ['macosx-amd64', '738dcdc6afddeb505ee4e4ef24f1c1fdba2b8c924e614cbbf5801a5b062dd683'],
  linux: ['linux-amd64', 'f3e987dc6ecebd4bd350c48edcbc320b46cf9e3109bd3fc3d88f1acaf4c428f7'],
};
if (!builds[process.platform] || (process.platform === 'linux' && process.arch !== 'x64')) {
  throw new Error('Use macOS (Rosetta on Apple Silicon) or Linux x86_64 for the pinned compiler.');
}
const [platform, checksum] = builds[process.platform];
const target = new URL('../.tooling/solc', import.meta.url);
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
let current;
try { current = await readFile(target); } catch (error) { if (error.code !== 'ENOENT') throw error; }
if (!current || hash(current) !== checksum) {
  const url = `https://raw.githubusercontent.com/ethereum/solc-bin/gh-pages/${platform}/solc-${platform}-v0.8.30+commit.73712a01`;
  const response = await fetch(url, { signal: AbortSignal.timeout(90_000) });
  if (!response.ok) throw new Error(`Compiler download failed: ${response.status}`);
  const bytes = Buffer.from(await response.arrayBuffer());
  if (hash(bytes) !== checksum) throw new Error('Compiler checksum mismatch');
  await mkdir(new URL('../.tooling/', import.meta.url), { recursive: true });
  await writeFile(target, bytes);
}
await chmod(target, 0o755);
console.log(`Compiler verified: ${fileURLToPath(target)}`);
