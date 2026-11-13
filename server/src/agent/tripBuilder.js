import { generateContent, extractText } from './gemini.js';
import { searchPlaces } from '../services/places.js';
import { getForecast, describeWeatherCode } from '../services/weather.js';
import { findPlacePhotos, photosByGeo } from '../services/photos.js';
import { buildRoute, googleMapsDirUrl, googleMapsPlaceUrl } from '../services/routing.js';
import { Trip } from '../models/Trip.js';

const TRIP_SCHEMA = {
  type: 'OBJECT',
  properties: {
    days: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          title: { type: 'STRING', description: 'Название дня, например "Боровое: Прибытие и адаптация"' },
          summary: { type: 'STRING', description: 'Одно предложение о дне' },
          items: {
            type: 'ARRAY',
            items: {
              type: 'OBJECT',
              properties: {
                time: { type: 'STRING', description: 'Время начала HH:MM' },
                category: { type: 'STRING', enum: ['food', 'sleep', 'activity', 'sight', 'transport', 'other'] },
                title: { type: 'STRING', description: 'Короткий заголовок, например "Завтрак в местном кафе"' },
                description: { type: 'STRING', description: '1-3 предложения: что делать, что попробовать, советы' },
                place_name: { type: 'STRING', description: 'ТОЧНОЕ название места из предоставленного списка, или пустая строка' },
                duration_min: { type: 'NUMBER', description: 'Длительность в минутах' }
              },
              required: ['time', 'category', 'title', 'description']
            }
          }
        },
        required: ['title', 'summary', 'items']
      }
    }
  },
  required: ['days']
};

function nextFriday() {
  const d = new Date();
  d.setDate(d.getDate() + ((5 - d.getDay() + 7) % 7 || 7));
  return d;
}

function addDays(dateStr, n) {
  const d = new Date(dateStr + 'T00:00:00');
  d.setDate(d.getDate() + n);
  return d.toISOString().slice(0, 10);
}

function normalize(s) {
  return (s || '').toLowerCase().replace(/["«»'’]/g, '').replace(/\s+/g, ' ').trim();
}

function matchPlace(name, pois) {
  const n = normalize(name);
  if (!n) return null;
  let best = null;
  let bestScore = 0;
  for (const p of pois) {
    const pn = normalize(p.name);
    let score = 0;
    if (pn === n) score = 3;
    else if (pn.includes(n) || n.includes(pn)) score = 2;
    else {
      const words = n.split(' ').filter((w) => w.length > 3);
      const hit = words.filter((w) => pn.includes(w)).length;
      if (hit && hit >= Math.ceil(words.length / 2)) score = 1;
    }
    if (score > bestScore) {
      best = p;
      bestScore = score;
    }
  }
  return best;
}

/**
 * Генерация полной поездки из принятого предложения:
 * реальные POI + погода → Gemini (JSON mode) → обогащение маршрутами, фото, deep-link'ами.
 */
export async function buildTripFromProposal({ proposal, userId, sessionId, onEvent }) {
  const { lat, lon } = proposal;
  const days = Math.min(Math.max(proposal.days || 1, 1), 14);
  const startDate = proposal.startDate || nextFriday().toISOString().slice(0, 10);

  // 1. Реальные данные
  onEvent?.('status', { label: 'Собираю реальные отели, кафе и места…' });
  const [sleep, food, sight, activity] = await Promise.all([
    searchPlaces({ lat, lon, category: 'sleep', radiusKm: 12, limit: 10 }).catch(() => []),
    searchPlaces({ lat, lon, category: 'food', radiusKm: 10, limit: 14 }).catch(() => []),
    searchPlaces({ lat, lon, category: 'sight', radiusKm: 25, limit: 14 }).catch(() => []),
    searchPlaces({ lat, lon, category: 'activity', radiusKm: 20, limit: 10 }).catch(() => [])
  ]);
  const allPois = [...sleep, ...food, ...sight, ...activity];

  onEvent?.('status', { label: 'Проверяю прогноз погоды…' });
  const forecast = await getForecast(lat, lon, 16).catch(() => null);

  // 2. Генерация плана
  onEvent?.('status', { label: 'ИИ расписывает поездку по часам…' });
  const poiBlock = (list, label) =>
    `${label}:\n` +
    (list.length
      ? list.map((p) => `- ${p.name}${p.stars ? ` (${p.stars}★)` : ''}${p.cuisine ? ` [${p.cuisine}]` : ''} — ${p.distanceKm} км от центра`).join('\n')
      : '- (не найдено, не выдумывай, используй пустое place_name и общие активности)');

  const weatherBlock = forecast
    ? forecast.daily
        .slice(0, days + 2)
        .map((w) => `${w.date}: ${w.description}, ${w.tempMin}…${w.tempMax}°C, осадки ${w.precipProb ?? '?'}%`)
        .join('\n')
    : 'нет данных';

  const prompt = `Составь детальный почасовой план поездки.

ТУР: ${proposal.title}
МЕСТО: ${proposal.destination}
ДНЕЙ: ${days}, начало ${startDate}
ИНТЕРЕСЫ: ${(proposal.interests || []).join(', ') || 'универсальные'}
ПЕРЕДВИЖЕНИЕ: ${proposal.transport === 'driving' ? 'на машине' : 'пешком/такси'}
ПУТЕШЕСТВЕННИКОВ: ${proposal.travelers || 1}
ПОЖЕЛАНИЯ: ${proposal.summary}

РЕАЛЬНЫЕ МЕСТА (используй ТОЛЬКО их в place_name, точно копируя название):
${poiBlock(sleep, 'ОТЕЛИ (sleep)')}
${poiBlock(food, 'ЕДА (food)')}
${poiBlock(sight, 'ДОСТОПРИМЕЧАТЕЛЬНОСТИ (sight)')}
${poiBlock(activity, 'РАЗВЛЕЧЕНИЯ (activity)')}

ПОГОДА:
${weatherBlock}

Требования:
- Ровно ${days} дн. (массив days), в каждом 4-7 пунктов с 08:00 до 22:00.
- День 1 начинается с заселения (category=sleep, отель из списка). Каждый день: завтрак/обед/ужин (food), 2-3 активности (sight/activity).
- Учитывай погоду: в дождь — крытые места, в ясные дни — природа и смотровые.
- Расстояния: не ставь подряд места в 20+ км друг от друга без необходимости.
- description — живой, конкретный: что попробовать, что взять с собой, почему стоит.
- place_name — СТРОГО название из списков выше или пустая строка "".`;

  const response = await generateContent({
    contents: [{ role: 'user', parts: [{ text: prompt }] }],
    generationConfig: {
      temperature: 0.6,
      maxOutputTokens: 8192,
      responseMimeType: 'application/json',
      responseSchema: TRIP_SCHEMA
    }
  });

  let plan;
  try {
    plan = JSON.parse(extractText(response));
  } catch {
    throw new Error('ИИ вернул некорректный план, попробуйте ещё раз');
  }
  if (!plan.days?.length) throw new Error('ИИ не смог составить план');

  // 3. Обогащение: координаты, маршруты, погода, фото
  onEvent?.('status', { label: 'Строю маршруты и подбираю фото…' });

  const usedPlaces = new Map();
  const tripDays = plan.days.slice(0, days).map((d, i) => {
    const date = addDays(startDate, i);
    const wx = forecast?.daily?.find((w) => w.date === date) || null;

    const items = (d.items || []).map((it, j) => {
      const poi = it.place_name ? matchPlace(it.place_name, allPois) : null;
      if (poi) usedPlaces.set(poi.osmId || poi.name, poi);
      return {
        id: `d${i + 1}-${j + 1}`,
        time: it.time,
        endTime: null,
        category: it.category || 'other',
        title: it.title,
        description: it.description,
        durationMin: it.duration_min || null,
        place: poi
          ? {
              name: poi.name,
              lat: poi.lat,
              lon: poi.lon,
              address: poi.address,
              stars: poi.stars,
              rating: null,
              photo: null,
              website: poi.website,
              phone: poi.phone,
              osmId: poi.osmId
            }
          : null,
        googleMapsUrl: poi ? googleMapsPlaceUrl(poi.lat, poi.lon, poi.name) : null
      };
    });

    return {
      index: i,
      date,
      title: d.title,
      summary: d.summary,
      weather: wx
        ? {
            tempMax: wx.tempMax,
            tempMin: wx.tempMin,
            code: wx.code,
            precipProb: wx.precipProb,
            ...describeWeatherCode(wx.code)
          }
        : null,
      items,
      route: { polyline: [], distanceKm: null, durationMin: null, profile: proposal.transport === 'driving' ? 'driving' : 'foot', googleMapsUrl: null }
    };
  });

  // Маршруты по дням (OSRM) + Google Maps deep-link
  const mode = proposal.transport === 'driving' ? 'driving' : 'walking';
  await Promise.all(
    tripDays.map(async (day) => {
      const pts = day.items.filter((it) => it.place).map((it) => ({ lat: it.place.lat, lon: it.place.lon }));
      if (pts.length >= 2) {
        day.route.googleMapsUrl = googleMapsDirUrl(pts, mode);
        const r = await buildRoute(pts, proposal.transport === 'driving' ? 'driving' : 'foot').catch(() => null);
        if (r) {
          day.route.polyline = r.polyline;
          day.route.distanceKm = r.distanceKm;
          day.route.durationMin = r.durationMin;
        }
      }
    })
  );

  // Фото: обложка и галерея места + фото для ключевых точек
  const gallery = await findPlacePhotos({ query: proposal.destination, lat, lon, limit: 8 }).catch(() => []);
  const placeList = [...usedPlaces.values()].slice(0, 8);
  await Promise.allSettled(
    placeList.map(async (poi) => {
      const shots = await photosByGeo(poi.lat, poi.lon, { radiusM: 300, limit: 1 });
      if (shots[0]) poi._photo = shots[0].url;
    })
  );
  for (const day of tripDays) {
    for (const it of day.items) {
      if (it.place) {
        const poi = placeList.find((p) => p.name === it.place.name);
        if (poi?._photo) it.place.photo = poi._photo;
      }
    }
  }

  // 4. Сохранение
  const trip = await Trip.create({
    user: userId,
    chatSession: sessionId || null,
    title: proposal.title,
    destination: proposal.destination,
    country: proposal.country,
    center: { lat, lon },
    startDate,
    endDate: addDays(startDate, days - 1),
    coverPhoto: gallery[0]?.url || null,
    photos: gallery.map((g) => g.url),
    days: tripDays,
    meta: {
      interests: proposal.interests || [],
      budget: null,
      travelers: proposal.travelers || 1,
      transport: proposal.transport
    }
  });

  return trip;
}
