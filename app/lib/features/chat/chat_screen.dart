import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/family_store.dart';
import '../../data/models.dart';
import '../../services/speaker.dart';
import '../../services/voice.dart';
import '../../theme/colors.dart';
import '../../widgets/back_button.dart';
import '../../widgets/bubbly_button.dart';
import '../../widgets/family_avatar.dart';
import '../../widgets/sticker.dart';
import 'drawing.dart';

/// Design page 3: the conversation with one person.
///
/// A pre-reader can do everything without typing: hold the big button to talk,
/// send a sticker, or draw. Typing appears only if the parent allowed it.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.contactId, this.demoReplies = true});

  final String contactId;

  /// No backend yet, so the other person "answers" with a sticker after 2 s.
  final bool demoReplies;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _showStickers = false;
  bool _recording = false;
  final _recordTimer = Stopwatch();
  final _text = TextEditingController();
  final _scroll = ScrollController();
  Timer? _reply;

  FamilyStore get _store => context.read<FamilyStore>();

  @override
  void initState() {
    super.initState();
    // Opening the chat counts as reading it. Run after the first frame,
    // because notifying listeners during build is not allowed.
    WidgetsBinding.instance.addPostFrameCallback((_) => _store.markRead(widget.contactId));
  }

  @override
  void dispose() {
    _reply?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(MessageType type, {String? data, int? seconds}) {
    _store.sendMessage(
      widget.contactId,
      ChatMessage(fromMe: true, type: type, data: data, durationSeconds: seconds, sentAt: _store.now),
    );
    _scrollToEnd();
    if (widget.demoReplies) {
      _reply?.cancel();
      _reply = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        final sticker = Sticker.values[Random().nextInt(Sticker.values.length)];
        _store.sendMessage(
          widget.contactId,
          ChatMessage(fromMe: false, type: MessageType.sticker, data: sticker.name, sentAt: _store.now),
        );
        _store.markRead(widget.contactId); // we're looking at it
        _scrollToEnd();
      });
    }
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _startTalking() async {
    final ok = await context.read<VoiceRecorder>().start();
    if (!mounted) return;
    if (!ok) {
      context.read<Speaker>().say('I need the microphone');
      return;
    }
    _recordTimer
      ..reset()
      ..start();
    setState(() => _recording = true);
  }

  Future<void> _stopTalking() async {
    if (!_recording) return;
    _recordTimer.stop();
    setState(() => _recording = false);
    final path = await context.read<VoiceRecorder>().stop();
    final seconds = max(1, _recordTimer.elapsed.inSeconds);
    // Ignore accidental taps shorter than half a second.
    if (path != null && _recordTimer.elapsedMilliseconds >= 500) {
      _send(MessageType.voice, data: path, seconds: seconds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FamilyStore>();
    final c = store.contact(widget.contactId);
    if (c == null) return const Scaffold(body: Center(child: Text('Not found')));
    final messages = store.messagesWith(widget.contactId);
    final isChild = store.state.role == Role.child;
    final canType = !isChild || store.state.settings.typingAllowed;

    return Scaffold(
      backgroundColor: FamilyColor.blue.light,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  RoundBackButton(fallback: isChild ? '/person/${c.id}' : '/family'),
                  const SizedBox(width: 14),
                  FamilyAvatar(ring: c.color.main, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(c.name, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800), maxLines: 1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.waving_hand_rounded, size: 48, color: AppColors.muted),
                          Text('Say hello!', style: TextStyle(color: AppColors.muted, fontSize: 20)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      key: const Key('messages'),
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: messages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (_, i) => _Bubble(message: messages[i], theirColor: c.color),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BubblyButton.circle(
                        key: const Key('stickers'),
                        semanticLabel: 'Stickers',
                        color: _showStickers ? FamilyColor.yellow : FamilyColor.white,
                        onPressed: () => setState(() => _showStickers = !_showStickers),
                        child: const Icon(Icons.emoji_emotions_rounded, size: 34),
                      ),
                      const SizedBox(width: 22),
                      BubblyButton.circle(
                        key: const Key('draw'),
                        semanticLabel: 'Draw',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            fullscreenDialog: true,
                            builder: (_) => DrawingPad(
                              onSend: (strokes) => _send(MessageType.drawing, data: Stroke.encode(strokes)),
                            ),
                          ),
                        ),
                        child: const Icon(Icons.brush_rounded, size: 34),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_showStickers) _StickerTray(onPick: (s) => _send(MessageType.sticker, data: s.name)),
                  if (canType)
                    _TextRow(
                      controller: _text,
                      onSend: (t) => _send(MessageType.text, data: t),
                    ),
                  // Listener (not onTap) because we need finger-down AND finger-up.
                  Listener(
                    key: const Key('talk'),
                    onPointerDown: (_) => _startTalking(),
                    onPointerUp: (_) => _stopTalking(),
                    onPointerCancel: (_) => _stopTalking(),
                    child: AnimatedScale(
                      scale: _recording ? 1.03 : 1,
                      duration: const Duration(milliseconds: 120),
                      child: BubblyButton(
                        color: _recording ? FamilyColor.red : FamilyColor.coral,
                        semanticLabel: 'Hold to talk',
                        borderRadius: BorderRadius.circular(52),
                        onPressed: () {},
                        child: SizedBox(
                          height: 64,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_recording ? Icons.graphic_eq_rounded : Icons.mic_rounded, size: 48),
                              const SizedBox(width: 12),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _recording ? 'Listening…' : 'Hold to talk',
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.theirColor});

  final ChatMessage message;
  final FamilyColor theirColor;

  @override
  Widget build(BuildContext context) {
    final me = message.fromMe;
    final bg = me ? FamilyColor.blue.main : Colors.white;

    final Widget content = switch (message.type) {
      MessageType.sticker => StickerView(Sticker.byName(message.data)),
      MessageType.text => Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(44)),
        child: Text(message.data ?? '', style: const TextStyle(fontSize: 22)),
      ),
      MessageType.drawing => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(36)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: ColoredBox(
            color: Colors.white,
            child: CustomPaint(size: const Size(240, 300), painter: StrokesPainter(Stroke.decode(message.data))),
          ),
        ),
      ),
      MessageType.voice ||
      MessageType.photo => _VoiceBubble(message: message, bg: bg, playColor: me ? Colors.white : theirColor.main),
    };

    return Align(alignment: me ? Alignment.centerRight : Alignment.centerLeft, child: content);
  }
}

class _VoiceBubble extends StatelessWidget {
  const _VoiceBubble({required this.message, required this.bg, required this.playColor});

  final ChatMessage message;
  final Color bg;
  final Color playColor;

  @override
  Widget build(BuildContext context) {
    final secs = message.durationSeconds ?? 1;
    return Container(
      key: const Key('voice-bubble'),
      padding: const EdgeInsets.fromLTRB(10, 10, 18, 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(44)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              final path = message.data;
              if (path != null) context.read<VoicePlayer>().play(path);
            },
            child: CircleAvatar(
              radius: 32,
              backgroundColor: playColor,
              child: const Icon(Icons.play_arrow_rounded, size: 36, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 12),
          // A simple fake waveform: bar heights from a fixed pattern.
          for (var i = 0; i < 10; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: 10 + (i * 7 % 26).toDouble(),
              decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(2)),
            ),
          const SizedBox(width: 12),
          Text('0:${secs.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}

class _StickerTray extends StatelessWidget {
  const _StickerTray({required this.onPick});

  final ValueChanged<Sticker> onPick;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(36)),
    child: GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [
        for (final s in Sticker.values)
          GestureDetector(
            key: Key('sticker-${s.name}'),
            onTap: () => onPick(s),
            child: FittedBox(child: StickerView(s)),
          ),
      ],
    ),
  );
}

class _TextRow extends StatelessWidget {
  const _TextRow({required this.controller, required this.onSend});

  final TextEditingController controller;
  final ValueChanged<String> onSend;

  void _submit() {
    final t = controller.text.trim();
    if (t.isEmpty) return;
    onSend(t);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('text-input'),
            controller: controller,
            maxLength: 200,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Type a message',
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        BubblyButton.circle(
          key: const Key('text-send'),
          size: 56,
          color: FamilyColor.blue,
          semanticLabel: 'Send',
          onPressed: _submit,
          child: const Icon(Icons.send_rounded, size: 26),
        ),
      ],
    ),
  );
}
