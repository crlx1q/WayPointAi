import mongoose from 'mongoose';

const placeSchema = new mongoose.Schema(
  {
    name: String,
    lat: Number,
    lon: Number,
    address: String,
    stars: { type: Number, default: null },
    rating: { type: Number, default: null },
    photo: { type: String, default: null },
    website: { type: String, default: null },
    phone: { type: String, default: null },
    osmId: { type: String, default: null }
  },
  { _id: false }
);

const itemSchema = new mongoose.Schema(
  {
    id: String,
    time: String, // "14:00"
    endTime: { type: String, default: null },
    category: {
      type: String,
      enum: ['food', 'sleep', 'activity', 'sight', 'transport', 'other'],
      default: 'other'
    },
    title: String,
    description: String,
    durationMin: { type: Number, default: null },
    place: { type: placeSchema, default: null },
    googleMapsUrl: { type: String, default: null }
  },
  { _id: false }
);

const daySchema = new mongoose.Schema(
  {
    index: Number,
    date: String, // "2026-07-10"
    title: String,
    summary: String,
    weather: {
      tempMax: Number,
      tempMin: Number,
      code: Number,
      description: String,
      icon: String,
      precipProb: Number
    },
    items: [itemSchema],
    route: {
      polyline: { type: [[Number]], default: [] }, // [[lat, lon], ...]
      distanceKm: { type: Number, default: null },
      durationMin: { type: Number, default: null },
      profile: { type: String, default: 'foot' },
      googleMapsUrl: { type: String, default: null }
    }
  },
  { _id: false }
);

const tripSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', index: true },
    chatSession: { type: mongoose.Schema.Types.ObjectId, ref: 'ChatSession', default: null },
    title: String, // "Поездка в Боровое"
    destination: String, // "Боровое, Казахстан"
    country: String,
    center: { lat: Number, lon: Number },
    startDate: String,
    endDate: String,
    coverPhoto: { type: String, default: null },
    photos: [{ type: String }],
    days: [daySchema],
    meta: {
      interests: [String],
      budget: String,
      travelers: Number,
      transport: String
    },
    status: { type: String, enum: ['active', 'archived'], default: 'active' }
  },
  { timestamps: true }
);

export const Trip = mongoose.model('Trip', tripSchema);
