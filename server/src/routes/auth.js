import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { User } from '../models/User.js';
import { signToken, requireAuth } from '../middleware/auth.js';

const router = Router();
const AVATAR_COLORS = ['#007AFF', '#00C2BB', '#C64F00', '#7C3AED', '#DB2777', '#0D9488'];

router.post('/register', async (req, res) => {
  try {
    const { email, password, name } = req.body || {};
    if (!email || !password) return res.status(400).json({ error: 'Нужны email и пароль' });
    if (password.length < 6) return res.status(400).json({ error: 'Пароль минимум 6 символов' });

    const exists = await User.findOne({ email: email.toLowerCase().trim() });
    if (exists) return res.status(409).json({ error: 'Такой email уже зарегистрирован' });

    const user = await User.create({
      email,
      passwordHash: await bcrypt.hash(password, 10),
      name: name?.trim() || email.split('@')[0],
      avatarColor: AVATAR_COLORS[Math.floor(Math.random() * AVATAR_COLORS.length)]
    });
    res.json({ token: signToken(user), user: user.toSafeJSON() });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body || {};
    const user = await User.findOne({ email: (email || '').toLowerCase().trim() });
    if (!user || !user.passwordHash || !(await bcrypt.compare(password || '', user.passwordHash))) {
      return res.status(401).json({ error: 'Неверный email или пароль' });
    }
    res.json({ token: signToken(user), user: user.toSafeJSON() });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Гостевой режим: аккаунт по deviceId, поездки хранятся на сервере
router.post('/guest', async (req, res) => {
  try {
    const { deviceId } = req.body || {};
    if (!deviceId) return res.status(400).json({ error: 'Нужен deviceId' });
    let user = await User.findOne({ deviceId, isGuest: true });
    if (!user) {
      user = await User.create({
        isGuest: true,
        deviceId,
        name: 'Гость',
        avatarColor: AVATAR_COLORS[Math.floor(Math.random() * AVATAR_COLORS.length)]
      });
    }
    res.json({ token: signToken(user), user: user.toSafeJSON() });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/me', requireAuth, (req, res) => res.json({ user: req.user.toSafeJSON() }));

router.patch('/me', requireAuth, async (req, res) => {
  const { name, interests, fcmToken } = req.body || {};
  if (name) req.user.name = String(name).slice(0, 60);
  if (Array.isArray(interests)) req.user.interests = interests.slice(0, 20);
  if (fcmToken !== undefined) req.user.fcmToken = fcmToken;
  await req.user.save();
  res.json({ user: req.user.toSafeJSON() });
});

export default router;
