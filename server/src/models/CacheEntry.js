import mongoose from 'mongoose';

// Кэш ответов внешних API (погода, фото, POI, геокодинг),
// чтобы не упираться в лимиты бесплатных сервисов.
const cacheEntrySchema = new mongoose.Schema({
  key: { type: String, unique: true, index: true },
  value: mongoose.Schema.Types.Mixed,
  expiresAt: { type: Date, index: { expires: 0 } }
});

export const CacheEntry = mongoose.model('CacheEntry', cacheEntrySchema);
