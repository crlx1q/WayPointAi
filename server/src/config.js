import dotenv from 'dotenv';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const ROOT_DIR = path.resolve(__dirname, '..');

dotenv.config({ path: path.join(ROOT_DIR, '.env') });

export const config = {
  port: Number(process.env.PORT || 8080),
  host: process.env.HOST || '0.0.0.0',
  publicUrl: process.env.PUBLIC_URL || 'http://localhost:8080',
  mongoUri: (process.env.MONGODB_URI || '').trim(),
  jwtSecret: process.env.JWT_SECRET || 'dev-secret',
  jwtExpires: process.env.JWT_EXPIRES || '30d',
  gemini: {
    apiKey: (process.env.GEMINI_API_KEY || '').trim(),
    model: (process.env.GEMINI_MODEL || 'gemini-3.1-flash-lite').trim(),
    // Если основная модель недоступна для ключа — пробуем по цепочке
    fallbackModels: [
      'gemini-flash-lite-latest',
      'gemini-2.5-flash-lite',
      'gemini-2.5-flash',
      'gemini-2.0-flash-lite',
      'gemini-2.0-flash'
    ]
  },
  unsplashKey: (process.env.UNSPLASH_ACCESS_KEY || '').trim(),
  admin: {
    email: process.env.ADMIN_EMAIL || 'admin@waypoint.ai',
    password: process.env.ADMIN_PASSWORD || 'admin'
  },
  apkUrl: process.env.APK_URL || '/downloads/waypoint-ai.apk',
  userAgent: 'WayPointAI/1.0 (waypoint.crlx1q.com; contact@crlx1q.com)'
};
