import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  const ChatScreen({super.key, this.initialQuery});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final inputCtrl = TextEditingController();
  final scrollCtrl = ScrollController();

  String? sessionId;
  List<ChatMessage> messages = [];
  String? statusLabel; // «Ищу отели…» во время работы агента
  bool sending = false;
  bool generating = false; // генерация полной поездки после принятия
  TripProposal? pendingProposal;
  XFile? attachedImage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    inputCtrl.dispose();
    scrollCtrl.dispose();
    super.dispose();
  }

  ApiClient get api => ref.read(apiProvider);

  Future<void> _init() async {
    try {
      final data = await api.post('/chat/sessions');
      final session = data['session'] as Map<String, dynamic>;
      setState(() {
        sessionId = session['_id'] as String;
        messages = (session['messages'] as List)
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList();
      });
      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        inputCtrl.text = widget.initialQuery!;
        _send();
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollCtrl.hasClients) {
        scrollCtrl.animateTo(
          scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 82);
    if (img != null) setState(() => attachedImage = img);
  }

  Future<void> _send() async {
    final text = inputCtrl.text.trim();
    if ((text.isEmpty && attachedImage == null) || sessionId == null || sending) return;

    String? imageBase64;
    String? imageMime;
    if (attachedImage != null) {
      final bytes = await attachedImage!.readAsBytes();
      imageBase64 = base64Encode(bytes);
      imageMime = attachedImage!.mimeType ?? 'image/jpeg';
    }

    setState(() {
      messages.add(ChatMessage(role: 'user', text: text, hasImage: attachedImage != null));
      inputCtrl.clear();
      attachedImage = null;
      sending = true;
      statusLabel = 'Думаю…';
    });
    _scrollDown();

    try {
      await for (final ev in api.postSse('/chat/sessions/$sessionId/message', body: {
        if (text.isNotEmpty) 'text': text,
        if (imageBase64 != null) 'imageBase64': imageBase64,
        if (imageMime != null) 'imageMime': imageMime,
      })) {
        if (!mounted) return;
        switch (ev.event) {
          case 'status':
            setState(() => statusLabel = ev.data['label'] as String?);
          case 'proposal':
            setState(() => pendingProposal = TripProposal.fromJson(ev.data));
          case 'text':
            setState(() {
              messages.add(ChatMessage(
                role: 'model',
                text: ev.data['text'] as String? ?? '',
                proposal: pendingProposal,
              ));
              pendingProposal = null;
              statusLabel = null;
            });
            _scrollDown();
          case 'error':
            throw ApiException(ev.data['error'] as String? ?? 'Ошибка агента');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => statusLabel = null);
        showSnack(context, e.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _accept(TripProposal proposal) async {
    if (generating || sessionId == null) return;
    setState(() {
      generating = true;
      statusLabel = 'Начинаю собирать поездку…';
    });
    _scrollDown();

    String? tripId;
    try {
      await for (final ev in api.postSse('/chat/sessions/$sessionId/accept', body: {'proposal': proposal.raw})) {
        if (!mounted) return;
        switch (ev.event) {
          case 'status':
            setState(() => statusLabel = ev.data['label'] as String?);
          case 'trip':
            tripId = ev.data['tripId'] as String?;
          case 'text':
            setState(() {
              messages.add(ChatMessage(role: 'model', text: ev.data['text'] as String? ?? '', tripId: tripId));
              statusLabel = null;
            });
            _scrollDown();
          case 'error':
            throw ApiException(ev.data['error'] as String? ?? 'Не удалось создать поездку');
        }
      }
      ref.invalidate(tripsProvider);
      if (tripId != null && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) context.push('/trip/$tripId');
      }
    } catch (e) {
      if (mounted) {
        setState(() => statusLabel = null);
        showSnack(context, e.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
        title: const Text('WayPoint AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Новый диалог',
            onPressed: () {
              setState(() {
                messages = [];
                sessionId = null;
              });
              _init();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: sessionId == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: messages.length + (statusLabel != null ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == messages.length) {
                        return _TypingIndicator(label: statusLabel!);
                      }
                      final m = messages[i];
                      return _MessageBubble(
                        message: m,
                        onAccept: generating ? null : _accept,
                        onOpenTrip: (id) => context.push('/trip/$id'),
                      ).animate().fadeIn(duration: 300.ms).slideY(begin: .05, curve: Curves.easeOutCubic);
                    },
                  ),
          ),

          // ── Поле ввода ──
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  if (attachedImage != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: kIsWeb
                                  ? Image.network(attachedImage!.path, width: 88, height: 88, fit: BoxFit.cover)
                                  : Image.file(File(attachedImage!.path), width: 88, height: 88, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(() => attachedImage = null),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded, size: 15, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().scale(duration: 250.ms, curve: Curves.easeOutBack),
                    ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: sending ? null : _pickImage,
                        icon: Icon(Icons.add_circle_outline_rounded, color: scheme.onSurfaceVariant, size: 28),
                        tooltip: 'Прикрепить фото локации',
                      ),
                      Expanded(
                        child: TextField(
                          controller: inputCtrl,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Напишите сообщение…',
                            suffixIcon: ShaderMask(
                              shaderCallback: (b) => wpGradient.createShader(b),
                              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: sending ? null : _send,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: sending ? null : wpGradient,
                            color: sending ? scheme.surfaceContainerHigh : null,
                            shape: BoxShape.circle,
                            boxShadow: sending
                                ? null
                                : [
                                    BoxShadow(
                                      color: WpColors.primaryBright.withValues(alpha: .35),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: sending
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Future<void> Function(TripProposal)? onAccept;
  final void Function(String tripId) onOpenTrip;

  const _MessageBubble({required this.message, this.onAccept, required this.onOpenTrip});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(gradient: wpGradient, shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .74),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? scheme.primary : scheme.surfaceContainerLowest,
                    border: isUser ? null : Border.all(color: scheme.outlineVariant.withValues(alpha: .5)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 6),
                      bottomRight: Radius.circular(isUser ? 6 : 20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.hasImage)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.image_rounded,
                                  size: 16, color: isUser ? Colors.white70 : scheme.onSurfaceVariant),
                              const SizedBox(width: 5),
                              Text('Фото локации',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isUser ? Colors.white70 : scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      Text(
                        message.text,
                        style: TextStyle(
                          color: isUser ? scheme.onPrimary : scheme.onSurface,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Карточка предложения тура
          if (message.proposal != null)
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 40),
              child: _ProposalCard(proposal: message.proposal!, onAccept: onAccept),
            ),

          // Кнопка перехода к созданной поездке
          if (message.tripId != null)
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 40),
              child: FilledButton.icon(
                onPressed: () => onOpenTrip(message.tripId!),
                icon: const Icon(Icons.map_rounded, size: 20),
                label: const Text('Открыть поездку'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final TripProposal proposal;
  final Future<void> Function(TripProposal)? onAccept;

  const _ProposalCard({required this.proposal, this.onAccept});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            WpColors.primaryBright.withValues(alpha: .1),
            WpColors.teal.withValues(alpha: .1),
          ],
        ),
        border: Border.all(color: WpColors.teal.withValues(alpha: .4), width: 1.2),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (b) => wpGradient.createShader(b),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 6),
              Text('ПРЕДЛОЖЕНИЕ ТУРА',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                      color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          Text(proposal.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -.3)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.place_rounded, size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(
                child: Text(proposal.destination,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5)),
              ),
              const SizedBox(width: 10),
              Icon(Icons.calendar_month_rounded, size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${proposal.days} дн.', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: 12),
          Text(proposal.summary, style: const TextStyle(fontSize: 14, height: 1.45)),
          const SizedBox(height: 12),
          ...proposal.highlights.take(5).map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_circle_rounded, size: 17, color: WpColors.teal),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(h, style: const TextStyle(fontSize: 13.5, height: 1.35))),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAccept == null ? null : () => onAccept!(proposal),
              icon: const Icon(Icons.rocket_launch_rounded, size: 19),
              label: const Text('Принять и построить маршрут'),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(.95, .95), curve: Curves.easeOutBack);
  }
}

class _TypingIndicator extends StatelessWidget {
  final String label;
  const _TypingIndicator({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(gradient: wpGradient, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1500.ms, color: Colors.white54),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: .5)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
                ),
                const SizedBox(width: 10),
                Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5))
                    .animate(key: ValueKey(label))
                    .fadeIn(duration: 250.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
