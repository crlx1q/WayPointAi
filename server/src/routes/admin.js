import { Router } from 'express';
import { requireAuth, requireAdmin } from '../middleware/auth.js';
import { User } from '../models/User.js';
import { Trip } from '../models/Trip.js';
import { ChatSession } from '../models/ChatSession.js';
import { Notification } from '../models/Notification.js';
import { AppSettings } from '../models/AppSettings.js';
import { geminiState } from '../agent/gemini.js';
import { dbState } from '../db.js';

const router = Router();
router.use(requireAuth, requireAdmin);

router.get('/stats', async (req, res) => {
  const dayAgo = new Date(Date.now() - 24 * 3600 * 1000);
  const weekAgo = new Date(Date.now() - 7 * 24 * 3600 * 1000);
  const [users, guests, trips, sessions, messagesAgg, activeToday, tripsWeek] = await Promise.all([
    User.countDocuments({ role: 'user', isGuest: false }),
    User.countDocuments({ isGuest: true }),
    Trip.countDocuments({}),
    ChatSession.countDocuments({}),
    ChatSession.aggregate([{ $project: { n: { $size: '$messages' } } }, { $group: { _id: null, total: { $sum: '$n' } } }]),
    User.countDocuments({ lastSeenAt: { $gte: dayAgo } }),
    Trip.countDocuments({ createdAt: { $gte: weekAgo } })
  ]);

  // Поездки по дням за 14 дней — для графика
  const since = new Date(Date.now() - 14 * 24 * 3600 * 1000);
  const tripsByDay = await Trip.aggregate([
    { $match: { createdAt: { $gte: since } } },
    { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, n: { $sum: 1 } } },
    { $sort: { _id: 1 } }
  ]);

  const topDestinations = await Trip.aggregate([
    { $group: { _id: '$destination', n: { $sum: 1 } } },
    { $sort: { n: -1 } },
    { $limit: 6 }
  ]);

  res.json({
    users,
    guests,
    trips,
    sessions,
    messages: messagesAgg[0]?.total || 0,
    activeToday,
    tripsWeek,
    tripsByDay: tripsByDay.map((d) => ({ date: d._id, count: d.n })),
    topDestinations: topDestinations.map((d) => ({ destination: d._id, count: d.n })),
    system: {
      gemini: geminiState,
      db: dbState,
      uptimeSec: Math.round(process.uptime()),
      memoryMb: Math.round(process.memoryUsage().rss / 1024 / 1024)
    }
  });
});

router.get('/users', async (req, res) => {
  const q = (req.query.q || '').toString().trim();
  const filter = q ? { $or: [{ email: new RegExp(q, 'i') }, { name: new RegExp(q, 'i') }] } : {};
  const users = await User.find(filter).sort({ createdAt: -1 }).limit(200).lean();
  const tripCounts = await Trip.aggregate([{ $group: { _id: '$user', n: { $sum: 1 } } }]);
  const countMap = new Map(tripCounts.map((t) => [t._id?.toString(), t.n]));
  res.json({
    users: users.map((u) => ({
      id: u._id,
      email: u.email,
      name: u.name,
      role: u.role,
      isGuest: u.isGuest,
      trips: countMap.get(u._id.toString()) || 0,
      lastSeenAt: u.lastSeenAt,
      createdAt: u.createdAt
    }))
  });
});

router.delete('/users/:id', async (req, res) => {
  if (req.params.id === req.user._id.toString()) return res.status(400).json({ error: 'Нельзя удалить себя' });
  await Promise.all([
    User.deleteOne({ _id: req.params.id }),
    Trip.deleteMany({ user: req.params.id }),
    ChatSession.deleteMany({ user: req.params.id })
  ]);
  res.json({ ok: true });
});

router.get('/trips', async (req, res) => {
  const trips = await Trip.find({})
    .sort({ createdAt: -1 })
    .limit(200)
    .populate('user', 'email name isGuest')
    .select('title destination startDate endDate coverPhoto user status days createdAt')
    .lean();
  res.json({
    trips: trips.map((t) => ({
      id: t._id,
      title: t.title,
      destination: t.destination,
      startDate: t.startDate,
      endDate: t.endDate,
      coverPhoto: t.coverPhoto,
      days: t.days?.length || 0,
      items: t.days?.reduce((n, d) => n + (d.items?.length || 0), 0) || 0,
      status: t.status,
      user: t.user ? { email: t.user.email, name: t.user.name, isGuest: t.user.isGuest } : null,
      createdAt: t.createdAt
    }))
  });
});

router.get('/trips/:id', async (req, res) => {
  const trip = await Trip.findById(req.params.id).populate('user', 'email name').lean();
  if (!trip) return res.status(404).json({ error: 'Не найдено' });
  res.json({ trip });
});

router.delete('/trips/:id', async (req, res) => {
  await Trip.deleteOne({ _id: req.params.id });
  res.json({ ok: true });
});

router.get('/chats', async (req, res) => {
  const chats = await ChatSession.find({})
    .sort({ updatedAt: -1 })
    .limit(100)
    .populate('user', 'email name isGuest')
    .select('title status messages user updatedAt')
    .lean();
  res.json({
    chats: chats.map((c) => ({
      id: c._id,
      title: c.title,
      status: c.status,
      messages: c.messages?.length || 0,
      user: c.user ? { email: c.user.email, name: c.user.name, isGuest: c.user.isGuest } : null,
      updatedAt: c.updatedAt
    }))
  });
});

router.get('/chats/:id', async (req, res) => {
  const chat = await ChatSession.findById(req.params.id).populate('user', 'email name').lean();
  if (!chat) return res.status(404).json({ error: 'Не найдено' });
  res.json({ chat });
});

// Композер уведомлений (база под Firebase push)
router.get('/notifications', async (req, res) => {
  const list = await Notification.find({}).sort({ createdAt: -1 }).limit(100).populate('user', 'email name').lean();
  res.json({ notifications: list });
});

router.post('/notifications', async (req, res) => {
  const { title, body, kind = 'system', icon = 'campaign', userId = null, data = {} } = req.body || {};
  if (!title) return res.status(400).json({ error: 'Нужен заголовок' });
  const n = await Notification.create({
    title,
    body: body || '',
    kind,
    icon,
    user: userId || null,
    data,
    sentBy: 'admin'
    // TODO(firebase): здесь будет отправка через FCM по fcmToken пользователей
  });
  res.json({ notification: n });
});

router.delete('/notifications/:id', async (req, res) => {
  await Notification.deleteOne({ _id: req.params.id });
  res.json({ ok: true });
});

router.get('/settings', async (req, res) => {
  res.json({ settings: await AppSettings.get() });
});

router.patch('/settings', async (req, res) => {
  const settings = await AppSettings.get();
  const { geminiModel, maxDailyRequestsPerUser, maintenanceMode, welcomeMessage } = req.body || {};
  if (geminiModel !== undefined) {
    settings.geminiModel = geminiModel || null;
    geminiState.activeModel = null; // сбросить, чтобы перечитать модель
  }
  if (maxDailyRequestsPerUser !== undefined) settings.maxDailyRequestsPerUser = maxDailyRequestsPerUser;
  if (maintenanceMode !== undefined) settings.maintenanceMode = maintenanceMode;
  if (welcomeMessage !== undefined) settings.welcomeMessage = welcomeMessage;
  await settings.save();
  res.json({ settings });
});

export default router;
