import { config } from '../config.js';
import { AppSettings } from '../models/AppSettings.js';

const BASE = 'https://generativelanguage.googleapis.com/v1beta';

export const geminiState = { ok: false, pending: true, detail: 'не проверено', activeModel: null };

async function callModel(model, payload) {
  const res = await fetch(`${BASE}/models/${model}:generateContent`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': config.gemini.apiKey },
    body: JSON.stringify(payload)
  });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    const err = new Error(`Gemini ${res.status}: ${text.slice(0, 300)}`);
    err.status = res.status;
    throw err;
  }
  return res.json();
}

async function resolveModel() {
  if (geminiState.activeModel) return geminiState.activeModel;
  const settings = await AppSettings.get().catch(() => null);
  const preferred = settings?.geminiModel || config.gemini.model;
  return preferred;
}

/**
 * Вызов Gemini с автоматическим фолбэком по цепочке моделей,
 * если указанная в .env модель недоступна для ключа (404/403).
 */
export async function generateContent(payload) {
  const preferred = await resolveModel();
  const chain = [preferred, ...config.gemini.fallbackModels.filter((m) => m !== preferred)];
  let lastErr;
  for (const model of chain) {
    try {
      const out = await callModel(model, payload);
      geminiState.ok = true;
      geminiState.pending = false;
      geminiState.activeModel = model;
      geminiState.detail = model;
      return out;
    } catch (err) {
      lastErr = err;
      // 404 — модели нет, 400 c "not found" — то же; иначе не перебираем
      if (err.status === 404 || (err.status === 400 && /not found|is not supported/i.test(err.message))) {
        continue;
      }
      if (err.status === 403) continue;
      throw err;
    }
  }
  geminiState.ok = false;
  geminiState.pending = false;
  geminiState.detail = `ошибка: ${lastErr?.message?.slice(0, 60)}`;
  throw lastErr;
}

/** Быстрая проверка ключа при старте (не блокирует запуск). */
export async function pingGemini() {
  if (!config.gemini.apiKey) {
    geminiState.ok = false;
    geminiState.pending = false;
    geminiState.detail = 'нет GEMINI_API_KEY';
    return;
  }
  try {
    await generateContent({
      contents: [{ role: 'user', parts: [{ text: 'ping' }] }],
      generationConfig: { maxOutputTokens: 5 }
    });
  } catch (err) {
    geminiState.ok = false;
    geminiState.pending = false;
    geminiState.detail = `ошибка: ${String(err.message).slice(0, 70)}`;
  }
}

/** Достаёт текстовые части из ответа. */
export function extractText(response) {
  const parts = response?.candidates?.[0]?.content?.parts || [];
  return parts
    .filter((p) => typeof p.text === 'string')
    .map((p) => p.text)
    .join('');
}

/** Достаёт functionCall-части из ответа. */
export function extractFunctionCalls(response) {
  const parts = response?.candidates?.[0]?.content?.parts || [];
  return parts.filter((p) => p.functionCall).map((p) => p.functionCall);
}
