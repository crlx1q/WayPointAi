import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { Trip } from '../models/Trip.js';

const router = Router();
router.use(requireAuth);

router.get('/', async (req, res) => {
  const trips = await Trip.find({ user: req.user._id, status: 'active' })
    .sort({ createdAt: -1 })
    .select('title destination country startDate endDate coverPhoto center days.date days.title meta createdAt')
    .lean();
  res.json({ trips });
});

router.get('/:id', async (req, res) => {
  const trip = await Trip.findOne({ _id: req.params.id, user: req.user._id }).lean();
  if (!trip) return res.status(404).json({ error: 'Поездка не найдена' });
  res.json({ trip });
});

router.delete('/:id', async (req, res) => {
  const trip = await Trip.findOneAndUpdate(
    { _id: req.params.id, user: req.user._id },
    { status: 'archived' },
    { new: true }
  );
  if (!trip) return res.status(404).json({ error: 'Поездка не найдена' });
  res.json({ ok: true });
});

export default router;
