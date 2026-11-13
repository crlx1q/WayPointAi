import mongoose from 'mongoose';
import { config } from './config.js';

export const dbState = { ok: false, detail: 'не подключено', mode: 'none' };

export async function connectDb() {
  mongoose.set('strictQuery', true);

  if (config.mongoUri) {
    try {
      await mongoose.connect(config.mongoUri, { serverSelectionTimeoutMS: 8000 });
      dbState.ok = true;
      dbState.mode = 'atlas';
      dbState.detail = `Atlas · ${mongoose.connection.name}`;
      return;
    } catch (err) {
      dbState.detail = `Atlas недоступен: ${err.message.slice(0, 60)}`;
    }
  }

  // Локальный фолбэк для разработки: in-memory MongoDB
  try {
    const { MongoMemoryServer } = await import('mongodb-memory-server');
    const mem = await MongoMemoryServer.create();
    await mongoose.connect(mem.getUri('waypoint'));
    dbState.ok = true;
    dbState.mode = 'memory';
    dbState.detail = 'in-memory (dev) — задай MONGODB_URI для Atlas';
  } catch (err) {
    dbState.ok = false;
    dbState.detail = `нет БД: ${err.message.slice(0, 60)}`;
  }
}
