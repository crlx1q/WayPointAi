import { Router } from 'express';
import { geocode } from '../services/geo.js';
import { searchPlaces } from '../services/places.js';
import { getForecast } from '../services/weather.js';
import { findPlacePhotos } from '../services/photos.js';

// Открытые data-эндпоинты (прокси с кэшем): погода, места, фото, геокодинг
const router = Router();

router.get('/geocode', async (req, res) => {
  try {
    if (!req.query.q) return res.status(400).json({ error: 'Нужен параметр q' });
    res.json({ results: await geocode(String(req.query.q)) });
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

router.get('/places', async (req, res) => {
  try {
    const { lat, lon, category = 'sight', radius = 10 } = req.query;
    if (!lat || !lon) return res.status(400).json({ error: 'Нужны lat и lon' });
    const places = await searchPlaces({
      lat: parseFloat(lat),
      lon: parseFloat(lon),
      category: String(category),
      radiusKm: parseFloat(radius)
    });
    res.json({ places });
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

router.get('/weather', async (req, res) => {
  try {
    const { lat, lon, days = 7 } = req.query;
    if (!lat || !lon) return res.status(400).json({ error: 'Нужны lat и lon' });
    res.json(await getForecast(parseFloat(lat), parseFloat(lon), parseInt(days, 10)));
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

router.get('/photos', async (req, res) => {
  try {
    const { q, lat, lon, limit = 8 } = req.query;
    if (!q && !lat) return res.status(400).json({ error: 'Нужен q или lat/lon' });
    const photos = await findPlacePhotos({
      query: q ? String(q) : null,
      lat: lat ? parseFloat(lat) : null,
      lon: lon ? parseFloat(lon) : null,
      limit: parseInt(limit, 10)
    });
    res.json({ photos });
  } catch (err) {
    res.status(502).json({ error: err.message });
  }
});

export default router;
