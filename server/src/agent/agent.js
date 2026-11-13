import { generateContent, extractText, extractFunctionCalls } from './gemini.js';
import { toolDeclarations, executeTool, toolStatusLabel } from './tools.js';

const MAX_TOOL_ROUNDS = 8;

function systemPrompt() {
  const today = new Date().toISOString().slice(0, 10);
  return `Ты — WayPoint AI, дружелюбный ИИ-ассистент по путешествиям в приложении WayPoint.
Сегодня ${today}. Общайся на русском, тепло и по делу, без воды.

Твоя задача — за несколько сообщений собрать всё для идеальной поездки и предложить тур:
1. Узнай МЕСТО и КОЛИЧЕСТВО ДНЕЙ. Если чего-то не хватает — задай ОДИН короткий уточняющий вопрос (не список вопросов).
2. Полезно узнать интересы (природа/еда/история/релакс), даты, пеший или на машине. Но не устраивай допрос: максимум 1-2 уточнения за весь диалог, дальше действуй сам с разумными допущениями.
3. Пользователь может прислать ФОТО локации — определи по нему место (гора, озеро, город, здание) и подтверди догадку одним предложением.

Правила работы с данными:
- ВСЕГДА проверяй место через geocode_place, прежде чем что-то советовать.
- Реальные отели, кафе и достопримечательности бери ТОЛЬКО из search_places. Никогда не выдумывай названия мест, отелей и кафе.
- Погоду смотри через get_weather, факты о месте — через lookup_info.
- Когда информации достаточно (место + дни) — вызывай propose_trip с 3-5 реальными хайлайтами из search_places. В highlights пиши названия реальных мест.
- После propose_trip коротко (1-2 предложения) скажи, что предложение готово и его можно принять кнопкой.

Стиль: короткие абзацы, без markdown-заголовков, можно 1-2 эмодзи. Не выдавай JSON и внутренние детали в текст.`;
}

/**
 * Один ход агента: сообщение пользователя (текст и/или фото) → 
 * цикл инструментов → текстовый ответ и/или карточка-предложение тура.
 *
 * onEvent(type, data) — SSE-события: status | text | proposal | error
 * Возвращает { text, proposal, toolTrace, historyDelta }
 */
export async function runAgentTurn({ history, userText, imageBase64, imageMime, onEvent }) {
  const userParts = [];
  if (imageBase64) {
    userParts.push({ inlineData: { mimeType: imageMime || 'image/jpeg', data: imageBase64 } });
  }
  userParts.push({ text: userText || 'Определи, что это за место на фото, и предложи, как там отдохнуть.' });

  const contents = [...(history || []), { role: 'user', parts: userParts }];
  const toolTrace = [];
  let proposal = null;
  let finalText = '';

  for (let round = 0; round <= MAX_TOOL_ROUNDS; round++) {
    const response = await generateContent({
      systemInstruction: { parts: [{ text: systemPrompt() }] },
      contents,
      tools: [{ functionDeclarations: toolDeclarations }],
      generationConfig: { temperature: 0.7, maxOutputTokens: 2048 }
    });

    const modelContent = response?.candidates?.[0]?.content;
    if (!modelContent) break;
    contents.push(modelContent);

    const calls = extractFunctionCalls(response);
    const text = extractText(response);
    if (text) finalText = text;

    if (!calls.length) break;

    const responseParts = [];
    for (const call of calls) {
      const args = call.args || {};
      toolTrace.push(call.name);
      onEvent?.('status', { label: toolStatusLabel(call.name, args), tool: call.name });

      if (call.name === 'propose_trip') {
        proposal = {
          title: args.title,
          destination: args.destination,
          country: args.country || null,
          lat: args.lat,
          lon: args.lon,
          days: Math.max(1, Math.round(args.days || 1)),
          startDate: args.start_date || null,
          interests: args.interests || [],
          transport: args.transport === 'driving' ? 'driving' : 'walking',
          travelers: args.travelers || 1,
          highlights: args.highlights || [],
          summary: args.summary || ''
        };
        onEvent?.('proposal', proposal);
        responseParts.push({
          functionResponse: {
            name: call.name,
            response: { ok: true, note: 'Карточка показана пользователю. Он может принять её кнопкой.' }
          }
        });
      } else {
        const result = await executeTool(call.name, args);
        responseParts.push({ functionResponse: { name: call.name, response: result } });
      }
    }
    contents.push({ role: 'user', parts: responseParts });
  }

  if (!finalText && proposal) {
    finalText = `Готово! Я собрал предложение тура «${proposal.title}». Посмотри карточку — если всё нравится, принимай, и я распишу поездку по часам.`;
  }
  if (!finalText) {
    finalText = 'Хм, я задумался. Расскажи ещё раз: куда хочешь поехать и на сколько дней?';
  }

  onEvent?.('text', { text: finalText });

  // В историю кладём текстовый маркер вместо тяжёлого base64
  const historyDelta = [
    { role: 'user', parts: [{ text: (imageBase64 ? '[Пользователь прислал фото локации] ' : '') + (userText || '') }] },
    { role: 'model', parts: [{ text: finalText + (proposal ? `\n[Показана карточка тура: ${proposal.title}]` : '') }] }
  ];

  return { text: finalText, proposal, toolTrace, historyDelta };
}
