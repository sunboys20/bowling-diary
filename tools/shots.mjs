// 설명서 사진 찍기 (크롬 원격 조종). 쓰는 법:
//   1) 폴더에서 로컬 서버:  npx serve -l 8153 .
//   2) node tools/shots.mjs http://localhost:8153 help g1 g2 ...   (이름을 빼면 전부)
// 각 이름은 tools/_shot.html#이름 화면. 결과는 help/ 폴더(설명서 12장) 또는 help/signup-*.png(가입 설명서)
import { spawn } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const base = process.argv[2] || 'http://localhost:8153';
const HELP = ['who', 'names', 'server', 'gear', 'edit', 'pad', 'fix', 'list', 'main', 'view', 'photos', 'backup'];
const SIGN = ['g1', 'g2', 'g3', 'g4', 'g5', 'g6', 'g7'];
const want = process.argv.slice(3);
const list = want.length ? want : [...HELP, ...SIGN];
const outName = n => HELP.includes(n) ? `help/${String(HELP.indexOf(n) + 1).padStart(2, '0')}-${n}.png` : `help/signup-${n.slice(1)}.png`;
const CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const sleep = ms => new Promise(r => setTimeout(r, ms));

for (const name of list) {
  const dir = mkdtempSync(join(tmpdir(), 'bshot-'));
  const port = 9300 + Math.floor(Math.random() * 500);
  const ch = spawn(CHROME, ['--headless=new', '--disable-gpu', '--hide-scrollbars', `--remote-debugging-port=${port}`, `--user-data-dir=${dir}`, '--window-size=375,812', 'about:blank']);
  let ws;
  for (let i = 0; i < 50 && !ws; i++) {
    await sleep(200);
    try { const t = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); const pg = t.find(x => x.type === 'page'); if (pg) ws = pg.webSocketDebuggerUrl; } catch { /* not yet */ }
  }
  const sock = new WebSocket(ws); await new Promise(r => sock.onopen = r);
  let id = 0; const wait = new Map();
  sock.onmessage = e => { const m = JSON.parse(e.data); if (m.id && wait.has(m.id)) { wait.get(m.id)(m); wait.delete(m.id); } };
  const cmd = (method, params = {}) => new Promise(r => { const n = ++id; wait.set(n, r); sock.send(JSON.stringify({ id: n, method, params })); });
  await cmd('Emulation.setDeviceMetricsOverride', { width: 375, height: 812, deviceScaleFactor: 1, mobile: false });
  await cmd('Page.navigate', { url: `${base}/tools/_shot#${name}` });
  await sleep(name.startsWith('g') ? 6000 : 7000);
  const shot = await cmd('Page.captureScreenshot', { format: 'png' });
  writeFileSync(outName(name), Buffer.from(shot.result.data, 'base64'));
  console.log(name, '->', outName(name));
  sock.close(); ch.kill();
  await sleep(500);
  try { rmSync(dir, { recursive: true, force: true }); } catch { /* chrome may still hold files */ }
}
