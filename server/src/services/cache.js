import mongoose from 'mongoose';
import { CacheEntry } from '../models/CacheEntry.js';

const memory = new Map(); // горячий слой поверх Mongo

export async function cached(key, ttlSeconds, fetcher) {
  const now = Date.now();

  const hot = memory.get(key);
  if (hot && hot.expires > now) return hot.value;

  if (mongoose.connection.readyState === 1) {
    try {
      const doc = await CacheEntry.findOne({ key }).lean();
      if (doc && doc.expiresAt && doc.expiresAt.getTime() > now) {
        memory.set(key, { value: doc.value, expires: doc.expiresAt.getTime() });
        return doc.value;
      }
    } catch {
      /* кэш не критичен */
    }
  }

  const value = await fetcher();
  const expires = now + ttlSeconds * 1000;
  memory.set(key, { value, expires });
  if (mongoose.connection.readyState === 1 && value !== undefined && value !== null) {
    CacheEntry.updateOne(
      { key },
      { $set: { value, expiresAt: new Date(expires) } },
      { upsert: true }
    ).catch(() => {});
  }
  return value;
}
