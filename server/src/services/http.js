import { config } from '../config.js';

export async function fetchJson(url, { timeoutMs = 15000, headers = {}, method = 'GET', body } = {}) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      method,
      body,
      signal: ctrl.signal,
      headers: { 'User-Agent': config.userAgent, Accept: 'application/json', ...headers }
    });
    if (!res.ok) {
      const text = await res.text().catch(() => '');
      throw new Error(`HTTP ${res.status} ${url.split('?')[0]} ${text.slice(0, 200)}`);
    }
    return await res.json();
  } finally {
    clearTimeout(timer);
  }
}
