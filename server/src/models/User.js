import mongoose from 'mongoose';

const userSchema = new mongoose.Schema(
  {
    email: { type: String, lowercase: true, trim: true, index: true, sparse: true },
    passwordHash: { type: String },
    name: { type: String, default: 'Путешественник' },
    role: { type: String, enum: ['user', 'admin'], default: 'user' },
    isGuest: { type: Boolean, default: false },
    deviceId: { type: String, index: true, sparse: true },
    avatarColor: { type: String, default: '#007AFF' },
    interests: [{ type: String }],
    fcmToken: { type: String, default: null },
    lastSeenAt: { type: Date, default: Date.now }
  },
  { timestamps: true }
);

userSchema.methods.toSafeJSON = function () {
  return {
    id: this._id.toString(),
    email: this.email || null,
    name: this.name,
    role: this.role,
    isGuest: this.isGuest,
    avatarColor: this.avatarColor,
    interests: this.interests,
    createdAt: this.createdAt
  };
};

export const User = mongoose.model('User', userSchema);
