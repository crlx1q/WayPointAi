import { cached } from './cache.js';
import { fetchJson } from './http.js';
import { config } from '../config.js';

const WEEK = 7 * 24 * 3600;
const COMMONS = 'https://commons.wikimedia.org/w/api.php';

function commonsUrl(params) {
  return `${COMMONS}?${new URLSearchParams({ format: 'json', origin: '*', ...params })}`;
}

/**
 * Реальные геопривязанные фото места из Wikimedia Commons —
 * снимки, сделанные именно в этих координатах (горы, озёра, кафе, виды).
 */
export async function photosByGeo(lat, lon, { radiusM = 5000, limit = 8 } = {}) {
  const key = `photo:geo:${lat.toFixed(3)}:${lon.toFixed(3)}:${radiusM}`;
  return cached(key, WEEK, async () => {
    const list = await fetchJson(
      commonsUrl({
        action: 'query',
        generator: 'geosearch',
        ggscoord: `${lat}|${lon}`,
        ggsradius: String(Math.min(radiusM, 10000)),
        ggslimit: '40',
        ggsnamespace: '6', // File:
        prop: 'imageinfo',
        iiprop: 'url|extmetadata|mime',
        iiurlwidth: '1200'
      })
    );
    const pages = Object.values(list.query?.pages || {});
    return pages
      .map((p) => {
        const info = p.imageinfo?.[0];
        if (!info || !/^image\/(jpeg|png|webp)/.test(info.mime || '')) return null;
        return {
          url: info.thumburl || info.url,
          fullUrl: info.url,
          title: (p.title || '').replace(/^File:/, '').replace(/\.\w+$/, ''),
          author: info.extmetadata?.Artist?.value?.replace(/<[^>]+>/g, '') || null,
          source: 'wikimedia'
        };
      })
      .filter(Boolean)
      .slice(0, limit);
  });
}

/** Заглавные фото статей Wikipedia по названию места (ru → en). */
export async function photosByName(query, limit = 6) {
  const key = `photo:name:${query.toLowerCase()}:${limit}`;
  return cached(key, WEEK, async () => {
    const results = [];
    for (const lang of ['ru', 'en']) {
      try {
        const api = `https://${lang}.wikipedia.org/w/api.php`;
        const data = await fetchJson(
          `${api}?${new URLSearchParams({
            format: 'json',
            origin: '*',
            action: 'query',
            generator: 'search',
            gsrsearch: query,
            gsrlimit: '5',
            prop: 'pageimages',
            piprop: 'original|thumbnail',
            pithumbsize: '1200'
          })}`
        );
        for (const p of Object.values(data.query?.pages || {})) {
          const img = p.thumbnail?.source || p.original?.source;
          if (img) results.push({ url: img, fullUrl: p.original?.source || img, title: p.title, author: null, source: `wikipedia-${lang}` });
        }
        if (results.length >= limit) break;
      } catch {
        /* пробуем следующий язык */
      }
    }
    return results.slice(0, limit);
  });
}

/** Unsplash — фолбэк для атмосферных обложек (ключ добавляется в .env). */
export async function photosUnsplash(query, limit = 6) {
  if (!config.unsplashKey) return [];
  const key = `photo:unsplash:${query.toLowerCase()}:${limit}`;
  return cached(key, WEEK, async () => {
    const data = await fetchJson(
      `https://api.unsplash.com/search/photos?query=${encodeURIComponent(query)}&per_page=${limit}&orientation=landscape`,
      { headers: { Authorization: `Client-ID ${config.unsplashKey}` } }
    );
    return (data.results || []).map((p) => ({
      url: p.urls.regular,
      fullUrl: p.urls.full,
      title: p.alt_description || query,
      author: p.user?.name || null,
      source: 'unsplash'
    }));
  });
}

/**
 * Главный метод: реальные фото места.
 * Сначала геопривязанные снимки Commons, затем фото из Wikipedia, потом Unsplash.
 */
export async function findPlacePhotos({ query, lat, lon, limit = 8 }) {
  const collected = [];
  const seen = new Set();
  const push = (arr) => {
    for (const p of arr || []) {
      if (p && p.url && !seen.has(p.url)) {
        seen.add(p.url);
        collected.push(p);
      }
    }
  };

  if (lat != null && lon != null) {
    await photosByGeo(lat, lon, { limit }).then(push).catch(() => {});
  }
  if (collected.length < limit && query) {
    await photosByName(query, limit - collected.length).then(push).catch(() => {});
  }
  if (collected.length < limit && query) {
    await photosUnsplash(query, limit - collected.length).then(push).catch(() => {});
  }
  return collected.slice(0, limit);
}
