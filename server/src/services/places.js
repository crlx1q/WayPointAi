import { cached } from './cache.js';
import { fetchJson } from './http.js';

const OVERPASS_ENDPOINTS = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter'
];
const DAY = 24 * 3600;

const CATEGORY_SELECTORS = {
  sleep: ['nwr["tourism"~"hotel|hostel|guest_house|motel|resort|apartment"]'],
  food: ['nwr["amenity"~"restaurant|cafe|fast_food|food_court|bar"]'],
  sight: [
    'nwr["tourism"~"attraction|viewpoint|museum|artwork|gallery"]',
    'nwr["historic"~"monument|memorial|castle|ruins"]',
    'nwr["natural"~"peak|beach|waterfall|cave_entrance"]'
  ],
  activity: [
    'nwr["leisure"~"park|beach_resort|water_park|sports_centre|marina"]',
    'nwr["tourism"~"theme_park|zoo|aquarium"]',
    'nwr["sport"~"ski|climbing|horse_racing"]'
  ]
};

function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

async function overpass(query) {
  let lastErr;
  for (const endpoint of OVERPASS_ENDPOINTS) {
    try {
      return await fetchJson(endpoint, {
        method: 'POST',
        timeoutMs: 30000,
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: 'data=' + encodeURIComponent(query)
      });
    } catch (err) {
      lastErr = err;
    }
  }
  throw lastErr;
}

/**
 * Поиск реальных мест вокруг точки через OSM Overpass.
 * category: sleep | food | sight | activity
 * Возвращает места с названием, координатами, звёздами (для отелей), контактами.
 */
export async function searchPlaces({ lat, lon, category = 'sight', radiusKm = 10, limit = 12 }) {
  const key = `poi:${category}:${lat.toFixed(3)}:${lon.toFixed(3)}:${radiusKm}`;
  const list = await cached(key, DAY, async () => {
    const selectors = CATEGORY_SELECTORS[category] || CATEGORY_SELECTORS.sight;
    const around = `(around:${Math.round(radiusKm * 1000)},${lat},${lon})`;
    const body = selectors.map((s) => `${s}${around};`).join('\n');
    const q = `[out:json][timeout:25];(${body});out center tags 60;`;
    const data = await overpass(q);

    return (data.elements || [])
      .map((el) => {
        const t = el.tags || {};
        const plat = el.lat ?? el.center?.lat;
        const plon = el.lon ?? el.center?.lon;
        if (!t.name || plat == null) return null;
        return {
          name: t['name:ru'] || t.name,
          lat: plat,
          lon: plon,
          category,
          stars: t.stars ? parseFloat(t.stars) : null,
          cuisine: t.cuisine || null,
          website: t.website || t['contact:website'] || null,
          phone: t.phone || t['contact:phone'] || null,
          address: [t['addr:street'], t['addr:housenumber']].filter(Boolean).join(', ') || null,
          openingHours: t.opening_hours || null,
          osmId: `${el.type}/${el.id}`,
          kind: t.tourism || t.amenity || t.leisure || t.historic || t.natural || null
        };
      })
      .filter(Boolean);
  });

  return list
    .map((p) => ({ ...p, distanceKm: +haversineKm(lat, lon, p.lat, p.lon).toFixed(2) }))
    .sort((a, b) => {
      // отели со звёздами и места с сайтами — выше: это более «настоящие» объекты
      const score = (x) => (x.stars ? -2 : 0) + (x.website ? -1 : 0) + x.distanceKm / 10;
      return score(a) - score(b);
    })
    .slice(0, limit);
}
