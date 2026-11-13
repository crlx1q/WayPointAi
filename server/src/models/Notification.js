import mongoose from 'mongoose';

// База под будущие Firebase push-уведомления:
// сейчас хранится и раздаётся через REST, позже сюда добавится отправка через FCM.
const notificationSchema = new mongoose.Schema(
  {
    title: { type: String, required: true },
    body: { type: String, default: '' },
    icon: { type: String, default: 'campaign' }, // material symbol name
    kind: { type: String, enum: ['system', 'promo', 'trip', 'ai'], default: 'system' },
    // null → broadcast всем пользователям
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null, index: true },
    data: { type: mongoose.Schema.Types.Mixed, default: {} }, // payload для deep-link (tripId и т.п.)
    readBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    sentBy: { type: String, default: 'system' }, // 'admin' | 'system'
    fcmSent: { type: Boolean, default: false } // для будущей интеграции FCM
  },
  { timestamps: true }
);

export const Notification = mongoose.model('Notification', notificationSchema);
