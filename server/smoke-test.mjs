// Смоук-тест API: auth → чат → сообщение агенту (SSE) → принятие тура
const BASE = 'http://127.0.0.1:8080/api';

async function j(path, options = {}) {
  const res = await fetch(BASE + path, {
    ...options,
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) }
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`${path}: ${res.status} ${JSON.stringify(data)}`);
  return data;
}

async function sse(path, token, body, timeoutMs = 240000) {
  const res = await fetch(BASE + path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs)
  });
  if (!res.ok) throw new Error(`${path}: ${res.status} ${await res.text()}`);
  const events = [];
  const reader = res.body.getReader();
  const dec = new TextDecoder();
  let buf = '';
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buf += dec.decode(value, { stream: true });
    let idx;
    while ((idx = buf.indexOf('\n\n')) !== -1) {
      const chunk = buf.slice(0, idx);
      buf = buf.slice(idx + 2);
      const ev = /event: (.+)/.exec(chunk)?.[1];
      const data = /data: (.+)/.exec(chunk)?.[1];
      if (ev) {
        events.push({ ev, data: data ? JSON.parse(data) : null });
        console.log('  [SSE]', ev, data ? data.label || data.text?.slice(0, 90) || JSON.stringify(data).slice(0, 110) : '');
      }
    }
  }
  return events;
}

console.log('1) health');
console.log('  ', JSON.stringify(await j('/health')));

console.log('2) register');
const email = `test${Date.now()}@test.io`;
const { token } = await j('/auth/register', { method: 'POST', body: JSON.stringify({ email, password: 'test123', name: 'Тест' }) });
console.log('   ok,', email);

console.log('3) guest login');
await j('/auth/guest', { method: 'POST', body: JSON.stringify({ deviceId: 'dev-123' }) });
console.log('   ok');

console.log('4) data: geocode Боровое');
const geo = await j('/data/geocode?q=' + encodeURIComponent('Боровое Казахстан'));
console.log('  ', geo.results[0]?.displayName, geo.results[0]?.lat, geo.results[0]?.lon);

console.log('5) create chat session');
const { session } = await j('/chat/sessions', { method: 'POST', headers: { Authorization: `Bearer ${token}` } });
console.log('   ok, приветствие:', session.messages[0].text.slice(0, 60));

console.log('6) message → агент (SSE)');
const ev1 = await sse(`/chat/sessions/${session._id}/message`, token, { text: 'Хочу в Боровое (Казахстан) на 2 дня, люблю природу и вкусно поесть' });

let proposal = ev1.find((e) => e.ev === 'proposal')?.data;
if (!proposal) {
  console.log('6b) уточнение → агент');
  const ev2 = await sse(`/chat/sessions/${session._id}/message`, token, { text: 'Да, всё верно, поехали пешком, нас двое. Предлагай тур!' });
  proposal = ev2.find((e) => e.ev === 'proposal')?.data;
}
if (!proposal) throw new Error('Агент не выдал предложение тура');
console.log('   PROPOSAL:', proposal.title, '| дней:', proposal.days, '| хайлайты:', proposal.highlights.join('; '));

console.log('7) accept → генерация поездки (SSE)');
const ev3 = await sse(`/chat/sessions/${session._id}/accept`, token, {});
const tripId = ev3.find((e) => e.ev === 'trip')?.data?.tripId;
if (!tripId) throw new Error('Поездка не создана: ' + JSON.stringify(ev3.find((e) => e.ev === 'error')?.data));

console.log('8) get trip');
const { trip } = await j(`/trips/${tripId}`, { headers: { Authorization: `Bearer ${token}` } });
console.log('   ', trip.title, '|', trip.destination, '| дней:', trip.days.length, '| обложка:', trip.coverPhoto ? 'есть' : 'нет');
for (const d of trip.days) {
  console.log(`   День ${d.index + 1}: ${d.title} | погода: ${d.weather?.description ?? '—'} ${d.weather?.tempMax ?? ''}° | пунктов: ${d.items.length} | маршрут: ${d.route.polyline.length} точек | gmaps: ${d.route.googleMapsUrl ? 'да' : 'нет'}`);
  for (const it of d.items.slice(0, 3)) {
    console.log(`      ${it.time} [${it.category}] ${it.title}${it.place ? ` @ ${it.place.name}${it.place.stars ? ' ' + it.place.stars + '★' : ''}${it.place.photo ? ' [фото]' : ''}` : ''}`);
  }
}

console.log('9) notifications (пусто) + trips list');
const { trips } = await j('/trips', { headers: { Authorization: `Bearer ${token}` } });
console.log('   поездок у юзера:', trips.length);

console.log('\nSMOKE TEST PASSED');
