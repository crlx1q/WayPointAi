import { cached } from './cache.js';
import { fetchJson } from './http.js';

const WMO = {
  0: ['Ясно', 'sunny'],
  1: ['Преимущественно ясно', 'sunny'],
  2: ['Переменная облачность', 'partly_cloudy'],
  3: ['Пасмурно', 'cloudy'],
  45: ['Туман', 'fog'],
  48: ['Изморозь', 'fog'],
  51: ['Лёгкая морось', 'drizzle'],
  53: ['Морось', 'drizzle'],
  55: ['Сильная морось', 'drizzle'],
  61: ['Небольшой дождь', 'rain'],
  63: ['Дождь', 'rain'],
  65: ['Ливень', 'rain'],
  66: ['Ледяной дождь', 'rain'],
  67: ['Сильный ледяной дождь', 'rain'],
  71: ['Небольшой снег', 'snow'],
  73: ['Снег', 'snow'],
  75: ['Сильный снег', 'snow'],
  77: ['Снежные зёрна', 'snow'],
  80: ['Кратковременный дождь', 'rain'],
  81: ['Ливни', 'rain'],
  82: ['Сильные ливни', 'rain'],
  85: ['Снегопад', 'snow'],
  86: ['Сильный снегопад', 'snow'],
  95: ['Гроза', 'storm'],
  96: ['Гроза с градом', 'storm'],
  99: ['Сильная гроза с градом', 'storm']
};

export function describeWeatherCode(code) {
  const [description, icon] = WMO[code] || ['Неизвестно', 'cloudy'];
  return { description, icon };
}

/**
 * Прогноз Open-Meteo (бесплатно, без ключа): до 16 дней, по дням и по часам.
 */
export async function getForecast(lat, lon, days = 7) {
  const key = `wx:${lat.toFixed(2)}:${lon.toFixed(2)}:${days}`;
  return cached(key, 3 * 3600, async () => {
    const url =
      `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}` +
      `&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset` +
      `&hourly=temperature_2m,weather_code` +
      `&current=temperature_2m,weather_code,wind_speed_10m` +
      `&timezone=auto&forecast_days=${Math.min(days, 16)}`;
    const d = await fetchJson(url);

    const current = d.current
      ? {
          temp: Math.round(d.current.temperature_2m),
          wind: d.current.wind_speed_10m,
          ...describeWeatherCode(d.current.weather_code)
        }
      : null;

    const daily = (d.daily?.time || []).map((date, i) => ({
      date,
      tempMax: Math.round(d.daily.temperature_2m_max[i]),
      tempMin: Math.round(d.daily.temperature_2m_min[i]),
      code: d.daily.weather_code[i],
      precipProb: d.daily.precipitation_probability_max?.[i] ?? null,
      sunrise: d.daily.sunrise?.[i]?.slice(11) || null,
      sunset: d.daily.sunset?.[i]?.slice(11) || null,
      ...describeWeatherCode(d.daily.weather_code[i])
    }));

    return { current, daily, timezone: d.timezone };
  });
}
