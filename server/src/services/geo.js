import { cached } from './cache.js';
import { fetchJson } from './http.js';

const NOMINATIM = 'https://nominatim.openstreetmap.org';
const WEEK = 7 * 24 * 3600;

// Геокодинг: название места → координаты (Nominatim, OSM)
export async function geocode(query, limit = 5) {
  const key = `geo:${query.toLowerCase()}:${limit}`;
  return cached(key, WEEK, async () => {
    const url = `${NOMINATIM}/search?format=jsonv2&limit=${limit}&accept-language=ru&q=${encodeURIComponent(query)}`;
    const data = await fetchJson(url);
    return data.map((r) => ({
      name: r.name || r.display_name.split(',')[0],
      displayName: r.display_name,
      lat: parseFloat(r.lat),
      lon: parseFloat(r.lon),
      type: r.type,
      category: r.category,
      importance: r.importance,
      country: r.display_name.split(',').pop().trim()
    }));
  });
}

export async function reverseGeocode(lat, lon) {
  const key = `rgeo:${lat.toFixed(4)}:${lon.toFixed(4)}`;
  return cached(key, WEEK, async () => {
    const url = `${NOMINATIM}/reverse?format=jsonv2&accept-language=ru&lat=${lat}&lon=${lon}`;
    const r = await fetchJson(url);
    return {
      displayName: r.display_name,
      name: r.name || r.display_name?.split(',')[0],
      country: r.address?.country || null,
      city: r.address?.city || r.address?.town || r.address?.village || null
    };
  });
}
