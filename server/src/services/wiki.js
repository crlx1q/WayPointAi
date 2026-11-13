import { cached } from './cache.js';
import { fetchJson } from './http.js';

const WEEK = 7 * 24 * 3600;

/**
 * «Гугл» агента: поиск актуальной справочной информации о месте
 * через Wikipedia (ru → en): описание, факты, что посмотреть.
 */
export async function wikiLookup(query) {
  const key = `wiki:${query.toLowerCase()}`;
  return cached(key, WEEK, async () => {
    for (const lang of ['ru', 'en']) {
      try {
        const api = `https://${lang}.wikipedia.org/w/api.php`;
        const search = await fetchJson(
          `${api}?${new URLSearchParams({
            format: 'json',
            origin: '*',
            action: 'query',
            list: 'search',
            srsearch: query,
            srlimit: '3'
          })}`
        );
        const hits = search.query?.search || [];
        if (!hits.length) continue;

        const summaries = [];
        for (const hit of hits.slice(0, 2)) {
          try {
            const s = await fetchJson(
              `https://${lang}.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(hit.title)}`
            );
            if (s.extract) {
              summaries.push({
                title: s.title,
                extract: s.extract,
                lat: s.coordinates?.lat ?? null,
                lon: s.coordinates?.lon ?? null,
                url: s.content_urls?.desktop?.page || null
              });
            }
          } catch {
            /* пропускаем */
          }
        }
        if (summaries.length) return { lang, results: summaries };
      } catch {
        /* следующий язык */
      }
    }
    return { lang: null, results: [] };
  });
}
