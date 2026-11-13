import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { Notification } from '../models/Notification.js';

// База под будущие Firebase push: хранение и выдача уведомлений через REST.
const router = Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const list = await Notification.find({
    $or: [{ user: null }, { user: req.user._id }]
  })
    .sort({ createdAt: -1 })
    .limit(50)
    .lean();

  res.json({
    notifications: list.map((n) => ({
      id: n._id,
      title: n.title,
      body: n.body,
      icon: n.icon,
      kind: n.kind,
      data: n.data,
      createdAt: n.createdAt,
      read: (n.readBy || []).some((id) => id.toString() === req.user._id.toString())
    }))
  });
});

router.post('/:id/read', async (req, res) => {
  await Notification.updateOne({ _id: req.params.id }, { $addToSet: { readBy: req.user._id } });
  res.json({ ok: true });
});

router.post('/read-all', async (req, res) => {
  await Notification.updateMany(
    { $or: [{ user: null }, { user: req.user._id }] },
    { $addToSet: { readBy: req.user._id } }
  );
  res.json({ ok: true });
});

export default router;
