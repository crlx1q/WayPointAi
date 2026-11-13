import os from 'node:os';
import chalk from 'chalk';

const LOGO = [
  ' __      __            ____         _         _        _    ___ ',
  ' \\ \\    / /_ _ _  _   |  _ \\  ___  (_) _ __  | |_     / \\  |_ _|',
  '  \\ \\/\\/ / _` | || |  | |_) |/ _ \\ | || \'_ \\ | __|   / _ \\  | | ',
  '   \\_/\\_/\\__,_|\\_, |  |  __/| (_) || || | | || |_   / ___ \\ | | ',
  '               |__/   |_|    \\___/ |_||_| |_| \\__| /_/   \\_\\___|'
];

// Градиент Deep Horizon Blue → Voyager Teal
const FROM = [0, 122, 255];
const TO = [0, 194, 187];

function gradientLine(line, t0, t1) {
  let out = '';
  const n = Math.max(line.length - 1, 1);
  for (let i = 0; i < line.length; i++) {
    const t = t0 + (t1 - t0) * (i / n);
    const r = Math.round(FROM[0] + (TO[0] - FROM[0]) * t);
    const g = Math.round(FROM[1] + (TO[1] - FROM[1]) * t);
    const b = Math.round(FROM[2] + (TO[2] - FROM[2]) * t);
    out += chalk.rgb(r, g, b)(line[i]);
  }
  return out;
}

export function getNetworkAddresses() {
  const nets = os.networkInterfaces();
  const addrs = [];
  for (const name of Object.keys(nets)) {
    for (const net of nets[name] || []) {
      if (net.family === 'IPv4' && !net.internal) {
        addrs.push({ iface: name, address: net.address });
      }
    }
  }
  return addrs;
}

const ok = (s) => chalk.hex('#22c55e')('✔ ' + s);
const bad = (s) => chalk.hex('#ef4444')('✖ ' + s);
const warn = (s) => chalk.hex('#f59e0b')('◌ ' + s);
const dim = (s) => chalk.hex('#717786')(s);
const label = (s) => chalk.hex('#adc6ff').bold(s.padEnd(12));
const link = (s) => chalk.hex('#00C2BB').underline(s);

export function printBanner({ port, publicUrl, db, gemini, adminEmail }) {
  const lines = [];
  lines.push('');
  LOGO.forEach((l, i) => lines.push('  ' + gradientLine(l, i / LOGO.length, (i + 1) / LOGO.length)));
  lines.push('');
  lines.push('  ' + chalk.bold.white('WayPoint AI') + dim('  ·  ИИ-планировщик путешествий  ·  v1.0.0'));
  lines.push('  ' + dim('─'.repeat(64)));

  lines.push('  ' + label('Local') + link(`http://localhost:${port}`));
  lines.push('  ' + label('Loopback') + link(`http://127.0.0.1:${port}`));
  for (const a of getNetworkAddresses()) {
    lines.push('  ' + label('Network') + link(`http://${a.address}:${port}`) + dim(`  (${a.iface})`));
  }
  lines.push('  ' + label('Listening') + chalk.white(`0.0.0.0:${port}`));
  lines.push('  ' + label('Public') + link(publicUrl));
  lines.push('  ' + dim('─'.repeat(64)));

  lines.push('  ' + label('API') + chalk.white('/api') + dim('   здоровье: /api/health'));
  lines.push('  ' + label('Admin') + chalk.white('/admin') + dim(`   логин: ${adminEmail}`));
  lines.push('  ' + label('MongoDB') + (db.ok ? ok(db.detail) : bad(db.detail)));
  lines.push('  ' + label('Gemini') + (gemini.ok ? ok(gemini.detail) : gemini.pending ? warn(gemini.detail) : bad(gemini.detail)));
  lines.push('  ' + dim('─'.repeat(64)));
  lines.push('  ' + dim(`PID ${process.pid} · Node ${process.version} · ${os.platform()} ${os.release()}`));
  lines.push('');

  console.log(lines.join('\n'));
}

export function logStep(msg) {
  console.log(dim('  › ') + chalk.white(msg));
}
