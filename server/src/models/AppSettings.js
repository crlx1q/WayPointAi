import mongoose from 'mongoose';

const appSettingsSchema = new mongoose.Schema(
  {
    key: { type: String, unique: true, default: 'global' },
    geminiModel: { type: String, default: null }, // переопределение модели из админки
    maxDailyRequestsPerUser: { type: Number, default: 50 },
    maintenanceMode: { type: Boolean, default: false },
    welcomeMessage: {
      type: String,
      default: 'Привет! Я ваш личный ИИ-ассистент по путешествиям. Куда бы вы хотели отправиться и на сколько дней?'
    }
  },
  { timestamps: true }
);

appSettingsSchema.statics.get = async function () {
  let doc = await this.findOne({ key: 'global' });
  if (!doc) doc = await this.create({ key: 'global' });
  return doc;
};

export const AppSettings = mongoose.model('AppSettings', appSettingsSchema);
