import { geocode, reverseGeocode } from '../services/geo.js';
import { searchPlaces } from '../services/places.js';
import { getForecast } from '../services/weather.js';
import { findPlacePhotos } from '../services/photos.js';
import { wikiLookup } from '../services/wiki.js';

/**
 * Инструменты ИИ-агента (Gemini function calling).
 * Через них модель получает доступ к актуальным данным:
 * геокодинг, реальные отели/кафе/достопримечательности, погода, фото, справка.
 */
export const toolDeclarations = [
  {
    name: 'geocode_place',
    description:
      'Найти место по названию и получить его точные координаты (lat/lon), полное название и страну. Всегда вызывай перед поиском мест и погоды.',
    parameters: {
      type: 'OBJECT',
      properties: {
        query: { type: 'STRING', description: 'Название места, например "Боровое Казахстан"' }
      },
      required: ['query']
    }
  },
  {
    name: 'search_places',
    description:
      'Найти реальные места вокруг координат из OpenStreetMap: отели (со звёздами), кафе и рестораны, достопримечательности, развлечения. Возвращает названия, координаты, звёзды отелей, сайты, телефоны, расстояние.',
    parameters: {
      type: 'OBJECT',
      properties: {
        lat: { type: 'NUMBER' },
        lon: { type: 'NUMBER' },
        category: {
          type: 'STRING',
          enum: ['sleep', 'food', 'sight', 'activity'],
          description: 'sleep=отели, food=еда, sight=достопримечательности, activity=развлечения'
        },
        radius_km: { type: 'NUMBER', description: 'Радиус поиска в км (по умолчанию 10)' }
      },
      required: ['lat', 'lon', 'category']
    }
  },
  {
    name: 'get_weather',
    description: 'Актуальный прогноз погоды по координатам (Open-Meteo): текущая погода и прогноз до 16 дней.',
    parameters: {
      type: 'OBJECT',
      properties: {
        lat: { type: 'NUMBER' },
        lon: { type: 'NUMBER' },
        days: { type: 'NUMBER', description: 'Сколько дней прогноза нужно (1-16)' }
      },
      required: ['lat', 'lon']
    }
  },
  {
    name: 'get_place_photos',
    description: 'Реальные фотографии места (Wikimedia Commons — геопривязанные снимки). Возвращает URL картинок.',
    parameters: {
      type: 'OBJECT',
      properties: {
        query: { type: 'STRING', description: 'Название места' },
        lat: { type: 'NUMBER' },
        lon: { type: 'NUMBER' }
      },
      required: ['query']
    }
  },
  {
    name: 'lookup_info',
    description:
      'Поиск справочной информации о месте (энциклопедия): что это, чем известно, что посмотреть. Используй, чтобы дать точные факты.',
    parameters: {
      type: 'OBJECT',
      properties: {
        query: { type: 'STRING', description: 'Поисковый запрос, например "Бурабай национальный парк"' }
      },
      required: ['query']
    }
  },
  {
    name: 'propose_trip',
    description:
      'Показать пользователю карточку-предложение тура, когда собрано достаточно информации (место, длительность, интересы). Пользователь сможет принять её кнопкой — после этого будет сгенерирован полный маршрут. Вызывай только когда место подтверждено геокодингом.',
    parameters: {
      type: 'OBJECT',
      properties: {
        title: { type: 'STRING', description: 'Название тура, например "Поездка в Боровое"' },
        destination: { type: 'STRING', description: 'Место назначения, например "Боровое, Казахстан"' },
        country: { type: 'STRING' },
        lat: { type: 'NUMBER' },
        lon: { type: 'NUMBER' },
        days: { type: 'NUMBER', description: 'Количество дней' },
        start_date: { type: 'STRING', description: 'Дата начала YYYY-MM-DD (если не сказано — ближайшая пятница)' },
        interests: { type: 'ARRAY', items: { type: 'STRING' }, description: 'Интересы: природа, еда, история...' },
        transport: { type: 'STRING', enum: ['walking', 'driving'], description: 'Основной способ передвижения' },
        travelers: { type: 'NUMBER', description: 'Число путешественников' },
        highlights: { type: 'ARRAY', items: { type: 'STRING' }, description: '3-5 главных пунктов программы (реальные места)' },
        summary: { type: 'STRING', description: 'Короткое (2 предложения) описание тура' }
      },
      required: ['title', 'destination', 'lat', 'lon', 'days', 'highlights', 'summary']
    }
  }
];

const STATUS_LABELS = {
  geocode_place: (a) => `Ищу «${a.query}» на карте…`,
  search_places: (a) =>
    ({
      sleep: 'Подбираю отели и смотрю звёзды…',
      food: 'Ищу кафе и рестораны рядом…',
      sight: 'Собираю достопримечательности…',
      activity: 'Ищу развлечения и активности…'
    })[a.category] || 'Ищу места рядом…',
  get_weather: () => 'Проверяю прогноз погоды…',
  get_place_photos: (a) => `Ищу реальные фото «${a.query}»…`,
  lookup_info: (a) => `Читаю про «${a.query}»…`,
  propose_trip: () => 'Собираю предложение тура…'
};

export function toolStatusLabel(name, args) {
  const fn = STATUS_LABELS[name];
  return fn ? fn(args || {}) : 'Думаю…';
}

/** Выполняет инструмент и возвращает результат для functionResponse. */
export async function executeTool(name, args) {
  try {
    switch (name) {
      case 'geocode_place': {
        const results = await geocode(args.query, 5);
        return results.length ? { results } : { results: [], note: 'Ничего не найдено, уточни запрос' };
      }
      case 'search_places': {
        const places = await searchPlaces({
          lat: args.lat,
          lon: args.lon,
          category: args.category,
          radiusKm: args.radius_km || 10,
          limit: 12
        });
        return { count: places.length, places };
      }
      case 'get_weather': {
        return await getForecast(args.lat, args.lon, args.days || 7);
      }
      case 'get_place_photos': {
        const photos = await findPlacePhotos({ query: args.query, lat: args.lat, lon: args.lon, limit: 6 });
        return { photos: photos.map((p) => ({ url: p.url, title: p.title, source: p.source })) };
      }
      case 'lookup_info': {
        return await wikiLookup(args.query);
      }
      case 'propose_trip': {
        // Обрабатывается отдельно в agent.js — сюда не доходит
        return { ok: true };
      }
      default:
        return { error: `Неизвестный инструмент: ${name}` };
    }
  } catch (err) {
    return { error: String(err.message).slice(0, 200) };
  }
}

export async function resolvePlaceContext(destination) {
  const results = await geocode(destination, 1);
  return results[0] || null;
}

export { reverseGeocode };
