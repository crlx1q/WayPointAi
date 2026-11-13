import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { ChatSession } from '../models/ChatSession.js';
import { AppSettings } from '../models/AppSettings.js';
import { runAgentTurn } from '../agent/agent.js';
import { buildTripFromProposal } from '../agent/tripBuilder.js';

const router = Router();
router.use(requireAuth);

router.get('/sessions', async (req, res) => {
  const sessions = await ChatSession.find({ user: req.user._id })
    .sort({ updatedAt: -1 })
    .limit(30)
    .select('title status createdAt updatedAt')
    .lean();
  res.json({ sessions });
});

router.post('/sessions', async (req, res) => {
  const settings = await AppSettings.get();
  const session = await ChatSession.create({
    user: req.user._id,
    messages: [{ role: 'model', text: settings.welcomeMessage }]
  });
  res.json({ session });
});

router.get('/sessions/:id', async (req, res) => {
  const session = await ChatSession.findOne({ _id: req.params.id, user: req.user._id }).lean();
  if (!session) return res.status(404).json({ error: 'Чат не найден' });
  res.json({ session });
});

function sseInit(res) {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream; charset=utf-8',
    'Cache-Control': 'no-cache, no-transform',
    Connection: 'keep-alive',
    'X-Accel-Buffering': 'no'
  });
  res.flushHeaders?.();
}

function sseSend(res, event, data) {
  res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

/**
 * Сообщение агенту. SSE-стрим: status → (proposal) → text → done.
 * body: { text?, imageBase64?, imageMime? }
 */
router.post('/sessions/:id/message', async (req, res) => {
  const session = await ChatSession.findOne({ _id: req.params.id, user: req.user._id });
  if (!session) return res.status(404).json({ error: 'Чат не найден' });

  const { text, imageBase64, imageMime } = req.body || {};
  if (!text && !imageBase64) return res.status(400).json({ error: 'Пустое сообщение' });

  sseInit(res);
  const onEvent = (event, data) => sseSend(res, event, data);

  try {
    session.messages.push({ role: 'user', text: text || '', imageUrl: imageBase64 ? 'attached' : null });

    const result = await runAgentTurn({
      history: session.agentHistory || [],
      userText: text,
      imageBase64,
      imageMime,
      onEvent
    });

    session.messages.push({
      role: 'model',
      text: result.text,
      proposal: result.proposal,
      toolTrace: result.toolTrace
    });
    session.agentHistory = [...(session.agentHistory || []), ...result.historyDelta].slice(-40);
    if (result.proposal) session.pendingProposal = result.proposal;
    if (session.title === 'Новая поездка' && result.proposal) session.title = result.proposal.title;
    await session.save();

    sseSend(res, 'done', { ok: true });
  } catch (err) {
    sseSend(res, 'error', { error: String(err.message).slice(0, 300) });
  }
  res.end();
});

/**
 * Принять предложение тура → генерация полной поездки. SSE: status → trip → done.
 */
router.post('/sessions/:id/accept', async (req, res) => {
  const session = await ChatSession.findOne({ _id: req.params.id, user: req.user._id });
  if (!session) return res.status(404).json({ error: 'Чат не найден' });
  const proposal = req.body?.proposal || session.pendingProposal;
  if (!proposal) return res.status(400).json({ error: 'Нет предложения для принятия' });

  sseInit(res);
  const onEvent = (event, data) => sseSend(res, event, data);

  try {
    const trip = await buildTripFromProposal({
      proposal,
      userId: req.user._id,
      sessionId: session._id,
      onEvent
    });

    const doneText = `Поездка «${trip.title}» готова! ${trip.days.length} дн., ${trip.days.reduce((n, d) => n + d.items.length, 0)} пунктов. Открывай карту и таймлайн — хорошего путешествия! ✨`;
    session.messages.push({ role: 'model', text: doneText, tripId: trip._id });
    session.agentHistory = [
      ...(session.agentHistory || []),
      { role: 'model', parts: [{ text: `[Поездка создана: ${trip.title}, id=${trip._id}]` }] }
    ];
    session.pendingProposal = null;
    session.status = 'trip_created';
    await session.save();

    sseSend(res, 'trip', { tripId: trip._id.toString() });
    sseSend(res, 'text', { text: doneText });
    sseSend(res, 'done', { ok: true });
  } catch (err) {
    sseSend(res, 'error', { error: String(err.message).slice(0, 300) });
  }
  res.end();
});

export default router;
