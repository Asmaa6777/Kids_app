import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/family_store.dart';
import '../../data/models.dart';
import '../../services/call_service.dart';
import '../../services/speaker.dart';
import '../../theme/colors.dart';
import '../../widgets/bubbly_button.dart';

/// Face "filters": an icon floating over your own picture.
/// Next step: ML Kit Face Detection to stick them to the real face.
enum FaceFilter {
  none(Icons.block_rounded, FamilyColor.white),
  stars(Icons.auto_awesome_rounded, FamilyColor.yellow),
  hearts(Icons.favorite_rounded, FamilyColor.pink),
  flower(Icons.local_florist_rounded, FamilyColor.green),
  sun(Icons.wb_sunny_rounded, FamilyColor.blue);

  const FaceFilter(this.icon, this.color);
  final IconData icon;
  final FamilyColor color;
}

/// Design page 5: in a call.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.contactId, this.answering = false});

  final String contactId;

  /// True when picking up an incoming call (so we don't ring them back).
  final bool answering;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  CallSession? _session;
  String? _error;
  FaceFilter _filter = FaceFilter.none;
  // Count ticks of a 1-second Timer instead of using a Stopwatch: same result on a
  // phone, and tests can fast-forward Timers (but not a real Stopwatch).
  int _seconds = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final store = context.read<FamilyStore>();
    final me = store.state.role == Role.family ? store.state.me?.name ?? 'relative' : store.state.childName;
    try {
      if (!widget.answering) store.ring(widget.contactId); // push "ringing" to the other phone
      // Both phones ask for the same room, so they meet there.
      final session = await context.read<CallService>().start(
        contactId: widget.contactId,
        identity: me,
        target: store.callTarget(widget.contactId),
      );
      if (!mounted) {
        await session.hangUp();
        return;
      }
      session.addListener(_onSession);
      setState(() => _session = session);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _onSession() {
    if (_session!.connected && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    _session?.removeListener(_onSession);
    super.dispose();
  }

  Future<void> _hangUp() async {
    final store = context.read<FamilyStore>();
    _tick?.cancel();
    _session?.removeListener(_onSession);
    await _session?.hangUp();
    if (_seconds > 0) store.logCall(widget.contactId, Duration(seconds: _seconds));
    if (mounted) context.canPop() ? context.pop() : context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FamilyStore>();
    final c = store.contact(widget.contactId);
    if (c == null) return const Scaffold(body: Center(child: Text('Not found')));
    final s = _session;
    final secs = _seconds;
    final status = _error != null
        ? "Couldn't connect"
        : (s?.connected ?? false)
        ? '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}'
        : 'Calling…';

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: ColoredBox(
                    color: c.color.light,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (s != null) s.buildRemote(context, ring: c.color.main),
                        Positioned(
                          top: 18,
                          left: 18,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                                Text(
                                  status,
                                  key: const Key('call-status'),
                                  style: const TextStyle(color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 18,
                          right: 18,
                          width: 110,
                          height: 146,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: Colors.white, width: 6),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (s != null) s.buildLocal(context),
                                  if (_filter != FaceFilter.none)
                                    Align(
                                      alignment: const Alignment(0, -0.75),
                                      child: Icon(
                                        _filter.icon,
                                        key: const Key('filter-overlay'),
                                        size: 44,
                                        color: _filter.color.dark,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_error != null)
                          Center(
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.ink),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                decoration: BoxDecoration(color: AppColors.night2, borderRadius: BorderRadius.circular(36)),
                child: Column(
                  children: [
                    if (store.state.settings.filtersAllowed)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final f in FaceFilter.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: BubblyButton(
                                  key: Key('filter-${f.name}'),
                                  color: f == _filter ? FamilyColor.yellow : f.color,
                                  borderRadius: BorderRadius.circular(22),
                                  padding: const EdgeInsets.all(14),
                                  depth: 5,
                                  semanticLabel: f.name,
                                  onPressed: () => setState(() => _filter = f),
                                  child: Icon(f.icon, size: 34),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        BubblyButton.circle(
                          key: const Key('mic'),
                          semanticLabel: 'Microphone',
                          color: (s?.micOn ?? true) ? FamilyColor.white : FamilyColor.yellow,
                          onPressed: s == null ? null : () => s.setMic(!s.micOn),
                          child: Icon((s?.micOn ?? true) ? Icons.mic_rounded : Icons.mic_off_rounded, size: 34),
                        ),
                        BubblyButton.circle(
                          key: const Key('hangup'),
                          size: 88,
                          color: FamilyColor.red,
                          semanticLabel: 'Hang up',
                          onPressed: _hangUp,
                          child: const Icon(Icons.call_end_rounded, size: 44, color: Colors.white),
                        ),
                        BubblyButton.circle(
                          key: const Key('flip'),
                          semanticLabel: 'Flip camera',
                          onPressed: s?.flipCamera,
                          child: const Icon(Icons.cameraswitch_rounded, size: 34),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Design page 4: "Grandma is calling". A push notification (FCM) will open
/// `/incoming/<id>` once the backend exists.
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key, required this.contactId});

  final String contactId;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = context.read<FamilyStore>().contact(widget.contactId);
      if (c != null) context.read<Speaker>().say('${c.name} is calling');
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<FamilyStore>().contact(widget.contactId);
    if (c == null) return const Scaffold(body: Center(child: Text('Not found')));
    return Scaffold(
      backgroundColor: c.color.main,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.25), spreadRadius: 40)],
                ),
                child: CircleAvatar(
                  radius: 110,
                  backgroundColor: AppColors.cream,
                  child: Icon(Icons.person_rounded, size: 140, color: AppColors.silhouette),
                ),
              ),
              const SizedBox(height: 60),
              Text(c.name, style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, height: 1)),
              const Text('is calling…', style: TextStyle(fontSize: 26)),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: BubblyButton(
                      key: const Key('decline'),
                      color: FamilyColor.red,
                      semanticLabel: 'Not now',
                      onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                      child: const Center(child: Icon(Icons.call_end_rounded, size: 46, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: BubblyButton(
                      key: const Key('accept'),
                      color: FamilyColor.green,
                      semanticLabel: 'Answer',
                      onPressed: () => context.pushReplacement('/call/${c.id}?answer=1'),
                      child: const Center(child: Icon(Icons.videocam_rounded, size: 46)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
