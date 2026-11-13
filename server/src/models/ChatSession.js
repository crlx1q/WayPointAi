import mongoose from 'mongoose';

const messageSchema = new mongoose.Schema(
  {
    role: { type: String, enum: ['user', 'model'], required: true },
    text: { type: String, default: '' },
    imageUrl: { type: String, default: null },
    proposal: { type: mongoose.Schema.Types.Mixed, default: null }, // карточка-предложение тура
    tripId: { type: mongoose.Schema.Types.ObjectId, ref: 'Trip', default: null },
    toolTrace: [{ type: String }], // какие инструменты вызывал агент (для админки)
    createdAt: { type: Date, default: Date.now }
  },
  { _id: false }
);

const chatSessionSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', index: true },
    title: { type: String, default: 'Новая поездка' },
    messages: [messageSchema],
    // История в формате Gemini contents (для контекста агента, включая functionCall/Response)
    agentHistory: { type: mongoose.Schema.Types.Mixed, default: [] },
    pendingProposal: { type: mongoose.Schema.Types.Mixed, default: null },
    status: { type: String, enum: ['open', 'trip_created'], default: 'open' }
  },
  { timestamps: true }
);

export const ChatSession = mongoose.model('ChatSession', chatSessionSchema);
