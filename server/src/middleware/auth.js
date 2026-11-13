import jwt from 'jsonwebtoken';
import { config } from '../config.js';
import { User } from '../models/User.js';

export function signToken(user) {
  return jwt.sign({ sub: user._id.toString(), role: user.role }, config.jwtSecret, {
    expiresIn: config.jwtExpires
  });
}

export async function requireAuth(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : req.query.token;
    if (!token) return res.status(401).json({ error: 'Требуется авторизация' });
    const payload = jwt.verify(token, config.jwtSecret);
    const user = await User.findById(payload.sub);
    if (!user) return res.status(401).json({ error: 'Пользователь не найден' });
    user.lastSeenAt = new Date();
    user.save().catch(() => {});
    req.user = user;
    next();
  } catch {
    return res.status(401).json({ error: 'Недействительный токен' });
  }
}

export function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Только для администратора' });
  }
  next();
}
