import express from 'express';
import cors from 'cors';
import path from 'node:path';
import bcrypt from 'bcryptjs';
import { config, ROOT_DIR } from './config.js';
import { connectDb, dbState } from './db.js';
import { printBanner, logStep } from './utils/banner.js';
import { pingGemini, geminiState } from './agent/gemini.js';
import { User } from './models/User.js';
import { AppSettings } from './models/AppSettings.js';

import authRoutes from './routes/auth.js';
import chatRoutes from './routes/chat.js';
import tripRoutes from './routes/trips.js';
import dataRoutes from './routes/data.js';
import notificationRoutes from './routes/notifications.js';
import adminRoutes from './routes/admin.js';

const app = express();
app.disable('x-powered-by');
app.use(cors());
app.use(express.json({ limit: '25mb' })); // фото локаций приходят base64

// ── API ────────────────────────────────────────────────────────
app.get('/api/health', (req, res) =>
  res.json({
    ok: true,
    name: 'WayPoint AI',
    db: dbState,
    gemini: { ok: geminiState.ok, model: geminiState.activeModel },
    time: new Date().toISOString()
  })
);
app.use('/api/auth', authRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/trips', tripRoutes);
app.use('/api/data', dataRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/admin', adminRoutes);

app.use('/api', (req, res) => res.status(404).json({ error: 'Эндпоинт не найден' }));

// ── Статика: лендинг и админка ────────────────────────────────
const PUBLIC_DIR = path.join(ROOT_DIR, 'public');
app.use(express.static(PUBLIC_DIR, { extensions: ['html'] }));
app.get('/admin', (req, res) => res.sendFile(path.join(PUBLIC_DIR, 'admin', 'index.html')));
app.get('/admin/*', (req, res) => res.sendFile(path.join(PUBLIC_DIR, 'admin', 'index.html')));

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('✖', err.message);
  res.status(500).json({ error: 'Внутренняя ошибка сервера' });
});

// ── Bootstrap ─────────────────────────────────────────────────
async function ensureAdmin() {
  const existing = await User.findOne({ email: config.admin.email });
  if (!existing) {
    await User.create({
      email: config.admin.email,
      passwordHash: await bcrypt.hash(config.admin.password, 10),
      name: 'Администратор',
      role: 'admin'
    });
    logStep(`Создан админ: ${config.admin.email}`);
  }
}

async function main() {
  console.clear();
  logStep('Запуск WayPoint AI…');

  logStep('Подключаюсь к MongoDB…');
  await connectDb();

  if (dbState.ok) {
    await ensureAdmin().catch((e) => logStep('Не удалось создать админа: ' + e.message));
    await AppSettings.get().catch(() => {});
  }

  logStep('Проверяю Gemini API…');
  await Promise.race([pingGemini(), new Promise((r) => setTimeout(r, 12000))]);

  app.listen(config.port, config.host, () => {
    printBanner({
      port: config.port,
      publicUrl: config.publicUrl,
      db: dbState,
      gemini: geminiState,
      adminEmail: config.admin.email
    });
  });
}

main().catch((err) => {
  console.error('Фатальная ошибка запуска:', err);
  process.exit(1);
});
