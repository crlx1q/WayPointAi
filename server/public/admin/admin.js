/* ── WayPoint AI · Admin SPA ── */
const $ = (sel, root = document) => root.querySelector(sel);
const API = '/api';

let token = localStorage.getItem('wp-admin-token') || null;

async function api(path, options = {}) {
  const res = await fetch(API + path, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers || {})
    }
  });
  const data = await res.json().catch(() => ({}));
  if (res.status === 401 || res.status === 403) {
    logout();
    throw new Error(data.error || 'Сессия истекла');
  }
  if (!res.ok) throw new Error(data.error || `Ошибка ${res.status}`);
  return data;
}

function toast(msg) {
  const el = $('#toast');
  el.textContent = msg;
  el.classList.remove('hidden');
  clearTimeout(el._t);
  el._t = setTimeout(() => el.classList.add('hidden'), 2600);
}

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}

const fmtDate = (d) => (d ? new Date(d).toLocaleString('ru-RU', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : '—');
const avatarColor = (name) => ['#007AFF', '#00C2BB', '#C64F00', '#7C3AED', '#DB2777'][(name || '?').charCodeAt(0) % 5];

function openModal(html) {
  $('#modalBody').innerHTML = html;
  $('#modal').classList.remove('hidden');
}
$('#modal').addEventListener('click', (e) => {
  if (e.target === $('#modal')) $('#modal').classList.add('hidden');
});

/* ── Auth ── */
function logout() {
  token = null;
  localStorage.removeItem('wp-admin-token');
  $('#app').classList.add('hidden');
  $('#loginScreen').classList.remove('hidden');
}
$('#logoutBtn').addEventListener('click', logout);

$('#loginForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  const errEl = $('#loginError');
  errEl.classList.add('hidden');
  try {
    const data = await fetch(API + '/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: $('#loginEmail').value, password: $('#loginPassword').value })
    }).then((r) => r.json());
    if (!data.token) throw new Error(data.error || 'Ошибка входа');
    if (data.user?.role !== 'admin') throw new Error('Этот аккаунт — не администратор');
    token = data.token;
    localStorage.setItem('wp-admin-token', token);
    boot();
  } catch (err) {
    errEl.textContent = err.message;
    errEl.classList.remove('hidden');
  }
});

/* ── Router ── */
const routes = {
  dashboard: renderDashboard,
  users: renderUsers,
  trips: renderTrips,
  chats: renderChats,
  notifications: renderNotifications,
  settings: renderSettings
};

function navigate() {
  const route = (location.hash.replace('#/', '') || 'dashboard').split('/')[0];
  document.querySelectorAll('.sidebar nav a').forEach((a) => a.classList.toggle('active', a.dataset.route === route));
  (routes[route] || renderDashboard)().catch((err) => {
    $('#content').innerHTML = `<div class="empty"><span class="material-symbols-rounded">error</span>${esc(err.message)}</div>`;
  });
}
window.addEventListener('hashchange', navigate);

/* ── Дашборд ── */
async function renderDashboard() {
  const s = await api('/admin/stats');
  const pill = $('#sysPill');
  pill.className = 'sys-pill ' + (s.system.gemini.ok && s.system.db.ok ? 'ok' : 'bad');
  $('#sysPillText').textContent = `${s.system.gemini.activeModel || 'gemini: ?'} · ${s.system.db.mode}`;

  const maxDay = Math.max(...s.tripsByDay.map((d) => d.count), 1);
  const days14 = [...Array(14)].map((_, i) => {
    const d = new Date(Date.now() - (13 - i) * 864e5).toISOString().slice(0, 10);
    return { date: d, count: s.tripsByDay.find((x) => x.date === d)?.count || 0 };
  });
  const maxDest = Math.max(...s.topDestinations.map((d) => d.count), 1);

  $('#content').innerHTML = `
    <div class="page-head"><div><h1>Дашборд</h1><div class="sub">Что происходит в WayPoint AI</div></div></div>
    <div class="stat-grid">
      <div class="stat-card"><div class="stat-ic blue"><span class="material-symbols-rounded">group</span></div><div><b>${s.users}</b><span>Пользователей</span></div></div>
      <div class="stat-card"><div class="stat-ic teal"><span class="material-symbols-rounded">person_pin</span></div><div><b>${s.guests}</b><span>Гостей</span></div></div>
      <div class="stat-card"><div class="stat-ic orange"><span class="material-symbols-rounded">luggage</span></div><div><b>${s.trips}</b><span>Поездок</span></div></div>
      <div class="stat-card"><div class="stat-ic violet"><span class="material-symbols-rounded">forum</span></div><div><b>${s.messages}</b><span>Сообщений ИИ</span></div></div>
      <div class="stat-card"><div class="stat-ic blue"><span class="material-symbols-rounded">bolt</span></div><div><b>${s.activeToday}</b><span>Активны сегодня</span></div></div>
    </div>
    <div class="two-col">
      <div class="card">
        <h3>Поездки за 14 дней (+${s.tripsWeek} за неделю)</h3>
        <div class="chart">${days14.map((d) => `<div class="bar" style="height:${Math.max((d.count / maxDay) * 100, 3)}%" data-tip="${d.date}: ${d.count}"></div>`).join('')}</div>
      </div>
      <div class="card">
        <h3>Популярные направления</h3>
        <div class="dest-list">${
          s.topDestinations.length
            ? s.topDestinations.map((d) => `<div class="dest-row"><span class="name">${esc(d.destination)}</span><div class="track"><div class="fill" style="width:${(d.count / maxDest) * 100}%"></div></div><span class="n">${d.count}</span></div>`).join('')
            : '<div class="empty" style="padding:20px">Пока нет поездок</div>'
        }</div>
      </div>
    </div>
    <div class="card" style="margin-top:16px">
      <h3>Система</h3>
      <div style="display:flex;gap:12px;flex-wrap:wrap">
        <span class="badge ${s.system.db.ok ? 'teal' : 'orange'}">MongoDB: ${esc(s.system.db.detail)}</span>
        <span class="badge ${s.system.gemini.ok ? 'teal' : 'orange'}">Gemini: ${esc(s.system.gemini.detail)}</span>
        <span class="badge gray">Аптайм: ${Math.floor(s.system.uptimeSec / 3600)}ч ${Math.floor((s.system.uptimeSec % 3600) / 60)}м</span>
        <span class="badge gray">RAM: ${s.system.memoryMb} МБ</span>
      </div>
    </div>`;
}

/* ── Пользователи ── */
async function renderUsers(q = '') {
  const { users } = await api('/admin/users' + (q ? `?q=${encodeURIComponent(q)}` : ''));
  $('#content').innerHTML = `
    <div class="page-head">
      <div><h1>Пользователи</h1><div class="sub">${users.length} аккаунтов</div></div>
      <div class="search-box"><span class="material-symbols-rounded">search</span><input id="userSearch" placeholder="Поиск по email или имени" value="${esc(q)}"></div>
    </div>
    <div class="table-wrap"><table>
      <thead><tr><th>Пользователь</th><th>Тип</th><th>Поездок</th><th>Был онлайн</th><th>Регистрация</th><th></th></tr></thead>
      <tbody>${users.map((u) => `
        <tr>
          <td><div class="cell-user"><span class="avatar" style="background:${avatarColor(u.name)}">${esc((u.name || '?')[0].toUpperCase())}</span><div>${esc(u.name)}<small>${esc(u.email || 'без email')}</small></div></div></td>
          <td>${u.role === 'admin' ? '<span class="badge orange">Админ</span>' : u.isGuest ? '<span class="badge gray">Гость</span>' : '<span class="badge blue">Аккаунт</span>'}</td>
          <td>${u.trips}</td>
          <td>${fmtDate(u.lastSeenAt)}</td>
          <td>${fmtDate(u.createdAt)}</td>
          <td>${u.role !== 'admin' ? `<button class="btn-icon" data-del="${u.id}" title="Удалить"><span class="material-symbols-rounded">delete</span></button>` : ''}</td>
        </tr>`).join('')}
      </tbody>
    </table></div>`;

  let t;
  $('#userSearch').addEventListener('input', (e) => {
    clearTimeout(t);
    t = setTimeout(() => renderUsers(e.target.value.trim()), 350);
  });
  $('#content').addEventListener('click', async (e) => {
    const btn = e.target.closest('[data-del]');
    if (!btn) return;
    if (!confirm('Удалить пользователя вместе с его поездками и чатами?')) return;
    await api(`/admin/users/${btn.dataset.del}`, { method: 'DELETE' });
    toast('Пользователь удалён');
    renderUsers(q);
  });
}

/* ── Поездки ── */
async function renderTrips() {
  const { trips } = await api('/admin/trips');
  $('#content').innerHTML = `
    <div class="page-head"><div><h1>Поездки</h1><div class="sub">${trips.length} сгенерировано</div></div></div>
    ${trips.length ? `<div class="table-wrap"><table>
      <thead><tr><th>Тур</th><th>Даты</th><th>Дней / пунктов</th><th>Пользователь</th><th>Создано</th><th></th></tr></thead>
      <tbody>${trips.map((t) => `
        <tr>
          <td><div class="cell-user">${t.coverPhoto ? `<img src="${esc(t.coverPhoto)}" style="width:44px;height:44px;border-radius:12px;object-fit:cover">` : '<span class="avatar" style="background:#007AFF"><span class="material-symbols-rounded">luggage</span></span>'}<div><b>${esc(t.title)}</b><small>${esc(t.destination)}</small></div></div></td>
          <td>${esc(t.startDate)} → ${esc(t.endDate)}</td>
          <td><span class="badge blue">${t.days} дн</span> <span class="badge teal">${t.items} пунктов</span></td>
          <td>${t.user ? esc(t.user.name || t.user.email) : '—'}</td>
          <td>${fmtDate(t.createdAt)}</td>
          <td><button class="btn-icon" data-view="${t.id}" title="Смотреть"><span class="material-symbols-rounded" style="color:var(--primary)">visibility</span></button><button class="btn-icon" data-del="${t.id}" title="Удалить"><span class="material-symbols-rounded">delete</span></button></td>
        </tr>`).join('')}
      </tbody>
    </table></div>` : '<div class="empty"><span class="material-symbols-rounded">luggage</span>Поездок пока нет</div>'}`;

  $('#content').addEventListener('click', async (e) => {
    const view = e.target.closest('[data-view]');
    const del = e.target.closest('[data-del]');
    if (view) {
      const { trip } = await api(`/admin/trips/${view.dataset.view}`);
      openModal(`
        <button class="btn btn-ghost btn-sm modal-close" onclick="document.getElementById('modal').classList.add('hidden')">Закрыть</button>
        <h2>${esc(trip.title)}</h2>
        <div class="sub">${esc(trip.destination)} · ${esc(trip.startDate)} → ${esc(trip.endDate)} · ${esc(trip.user?.email || '')}</div>
        ${trip.days.map((d) => `
          <div style="margin-bottom:18px">
            <b>День ${d.index + 1} · ${esc(d.title)}</b>
            ${d.weather ? `<span class="badge gray" style="margin-left:8px">${esc(d.weather.description)}, ${d.weather.tempMin}…${d.weather.tempMax}°C</span>` : ''}
            <div style="margin-top:8px;display:flex;flex-direction:column;gap:6px">
              ${d.items.map((it) => `<div style="display:flex;gap:10px;font-size:13.5px"><b style="min-width:44px;color:var(--primary)">${esc(it.time)}</b><div><b>${esc(it.title)}</b>${it.place ? ` · <span style="color:var(--text-soft)">${esc(it.place.name)}${it.place.stars ? ` ${it.place.stars}★` : ''}</span>` : ''}<div style="color:var(--text-soft)">${esc(it.description)}</div></div></div>`).join('')}
            </div>
          </div>`).join('')}`);
    }
    if (del) {
      if (!confirm('Удалить поездку?')) return;
      await api(`/admin/trips/${del.dataset.del}`, { method: 'DELETE' });
      toast('Поездка удалена');
      renderTrips();
    }
  });
}

/* ── Чаты ── */
async function renderChats() {
  const { chats } = await api('/admin/chats');
  $('#content').innerHTML = `
    <div class="page-head"><div><h1>Чаты с ИИ</h1><div class="sub">${chats.length} диалогов</div></div></div>
    ${chats.length ? `<div class="table-wrap"><table>
      <thead><tr><th>Диалог</th><th>Статус</th><th>Сообщений</th><th>Пользователь</th><th>Обновлён</th><th></th></tr></thead>
      <tbody>${chats.map((c) => `
        <tr>
          <td><b>${esc(c.title)}</b></td>
          <td>${c.status === 'trip_created' ? '<span class="badge teal">Тур создан</span>' : '<span class="badge gray">Открыт</span>'}</td>
          <td>${c.messages}</td>
          <td>${c.user ? esc(c.user.name || c.user.email) : '—'}</td>
          <td>${fmtDate(c.updatedAt)}</td>
          <td><button class="btn-icon" data-view="${c.id}"><span class="material-symbols-rounded" style="color:var(--primary)">visibility</span></button></td>
        </tr>`).join('')}
      </tbody>
    </table></div>` : '<div class="empty"><span class="material-symbols-rounded">forum</span>Диалогов пока нет</div>'}`;

  $('#content').addEventListener('click', async (e) => {
    const view = e.target.closest('[data-view]');
    if (!view) return;
    const { chat } = await api(`/admin/chats/${view.dataset.view}`);
    openModal(`
      <button class="btn btn-ghost btn-sm modal-close" onclick="document.getElementById('modal').classList.add('hidden')">Закрыть</button>
      <h2>${esc(chat.title)}</h2>
      <div class="sub">${esc(chat.user?.email || '')}</div>
      <div class="chat-log">
        ${chat.messages.map((m) => `<div class="chat-msg ${m.role}">${esc(m.text)}${m.toolTrace?.length ? `<span class="trace">инструменты: ${esc(m.toolTrace.join(', '))}</span>` : ''}</div>`).join('')}
      </div>`);
  });
}

/* ── Уведомления ── */
async function renderNotifications() {
  const { notifications } = await api('/admin/notifications');
  $('#content').innerHTML = `
    <div class="page-head"><div><h1>Уведомления</h1><div class="sub">Рассылка в приложение · база под Firebase push</div></div></div>
    <div class="card">
      <h3>Новое уведомление</h3>
      <form class="notif-form" id="notifForm">
        <label>Заголовок<input id="nTitle" placeholder="Скидка на Pro-подписку!" required></label>
        <label>Тип<select id="nKind"><option value="system">Системное</option><option value="promo">Промо</option><option value="trip">Поездка</option><option value="ai">От ИИ</option></select></label>
        <label class="full">Текст<textarea id="nBody" rows="3" placeholder="Расскажите пользователям о новинке…"></textarea></label>
        <div class="full" style="display:flex;justify-content:flex-end">
          <button class="btn btn-primary" type="submit"><span class="material-symbols-rounded">send</span>Отправить всем</button>
        </div>
      </form>
    </div>
    <div style="height:16px"></div>
    ${notifications.length ? `<div class="table-wrap"><table>
      <thead><tr><th>Уведомление</th><th>Тип</th><th>Кому</th><th>Прочитали</th><th>Отправлено</th><th></th></tr></thead>
      <tbody>${notifications.map((n) => `
        <tr>
          <td><b>${esc(n.title)}</b><br><small style="color:var(--text-soft)">${esc(n.body)}</small></td>
          <td><span class="badge ${n.kind === 'promo' ? 'orange' : n.kind === 'ai' ? 'teal' : 'blue'}">${esc(n.kind)}</span></td>
          <td>${n.user ? esc(n.user.email) : 'Все'}</td>
          <td>${n.readBy?.length || 0}</td>
          <td>${fmtDate(n.createdAt)}</td>
          <td><button class="btn-icon" data-del="${n._id}"><span class="material-symbols-rounded">delete</span></button></td>
        </tr>`).join('')}
      </tbody>
    </table></div>` : '<div class="empty"><span class="material-symbols-rounded">notifications_off</span>Уведомлений ещё не было</div>'}`;

  $('#notifForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    await api('/admin/notifications', {
      method: 'POST',
      body: JSON.stringify({ title: $('#nTitle').value, body: $('#nBody').value, kind: $('#nKind').value })
    });
    toast('Уведомление отправлено');
    renderNotifications();
  });
  $('#content').addEventListener('click', async (e) => {
    const del = e.target.closest('[data-del]');
    if (!del) return;
    await api(`/admin/notifications/${del.dataset.del}`, { method: 'DELETE' });
    toast('Удалено');
    renderNotifications();
  });
}

/* ── Настройки ── */
async function renderSettings() {
  const { settings } = await api('/admin/settings');
  $('#content').innerHTML = `
    <div class="page-head"><div><h1>Настройки</h1><div class="sub">Конфигурация сервера и ИИ</div></div></div>
    <div class="card">
      <form class="settings-form" id="settingsForm">
        <label>Модель Gemini (пусто = из .env)
          <input id="sModel" value="${esc(settings.geminiModel || '')}" placeholder="gemini-3.1-flash-lite">
        </label>
        <label>Лимит ИИ-запросов на пользователя в день
          <input id="sLimit" type="number" min="1" value="${settings.maxDailyRequestsPerUser}">
        </label>
        <label>Приветственное сообщение ассистента
          <textarea id="sWelcome" rows="3">${esc(settings.welcomeMessage)}</textarea>
        </label>
        <div class="switch-row">
          <div><b>Режим обслуживания</b><br><small style="color:var(--text-soft)">Приложение покажет заглушку</small></div>
          <label class="switch"><input type="checkbox" id="sMaint" ${settings.maintenanceMode ? 'checked' : ''}><span class="slider"></span></label>
        </div>
        <div style="display:flex;justify-content:flex-end">
          <button class="btn btn-primary" type="submit"><span class="material-symbols-rounded">save</span>Сохранить</button>
        </div>
      </form>
    </div>`;

  $('#settingsForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    await api('/admin/settings', {
      method: 'PATCH',
      body: JSON.stringify({
        geminiModel: $('#sModel').value.trim(),
        maxDailyRequestsPerUser: Number($('#sLimit').value),
        welcomeMessage: $('#sWelcome').value,
        maintenanceMode: $('#sMaint').checked
      })
    });
    toast('Настройки сохранены');
  });
}

/* ── Boot ── */
async function boot() {
  if (!token) return logout();
  try {
    const { user } = await api('/auth/me');
    if (user.role !== 'admin') return logout();
    $('#loginScreen').classList.add('hidden');
    $('#app').classList.remove('hidden');
    navigate();
  } catch {
    /* logout уже вызван */
  }
}
boot();
