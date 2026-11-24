import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/family_store.dart';
import '../data/models.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import 'router.dart';

/// The root widget: shares the store and services with every screen, plus theme + router.
///
/// Services are passed in (not created inside screens) so tests can hand in
/// fakes: `FamilyCallApp(store: ..., services: AppServices.fake())`.
class FamilyCallApp extends StatefulWidget {
  const FamilyCallApp({super.key, required this.store, required this.services, this.initialLocation});

  final FamilyStore store;
  final AppServices services;

  /// Where to start. If null: welcome until set up, then the child home or the relative's view.
  final String? initialLocation;

  @override
  State<FamilyCallApp> createState() => _FamilyCallAppState();
}

class _FamilyCallAppState extends State<FamilyCallApp> {
  // Created once, not on every rebuild (rebuilding a router resets navigation).
  late final GoRouter _router = buildRouter(initialLocation: widget.initialLocation ?? _startLocation());

  StreamSubscription<Map<String, String>>? _pushSub;
  bool _tokenSent = false;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_registerPush);
    _registerPush();
    _pushSub = widget.services.push.messages.listen(_onPush);
  }

  @override
  void dispose() {
    widget.store.removeListener(_registerPush);
    _pushSub?.cancel();
    super.dispose();
  }

  /// Once this device belongs to a family on the server, tell the server where to send pushes.
  Future<void> _registerPush() async {
    final backend = widget.store.backend;
    if (_tokenSent || backend == null || !widget.store.online) return;
    _tokenSent = true;
    final token = await widget.services.push.token();
    if (token != null) await backend.registerPushToken(token);
  }

  /// A call push opens the ringing screen. Message pushes need nothing: the
  /// live Firestore stream already shows the new message and its dot.
  void _onPush(Map<String, String> data) {
    if (data['type'] != 'call') return;
    final s = widget.store.state;
    if (data['familyId'] != s.familyId || widget.store.isQuiet) return;
    // On the child's device the caller is that contact; on a relative's device it's the child.
    final who = s.role == Role.family ? 'child' : data['contactId'];
    if (who != null) _router.push('/incoming/$who');
  }

  String _startLocation() {
    final s = widget.store.state;
    if (!s.isSetUp) return '/';
    return s.role == Role.family ? '/family' : '/home';
  }

  @override
  Widget build(BuildContext context) {
    // MultiProvider puts these objects above every screen:
    //   context.watch<FamilyStore>()  → read + rebuild when it changes
    //   context.read<Speaker>()       → just use it
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.store),
        Provider.value(value: widget.services.speaker),
        Provider.value(value: widget.services.kiosk),
        Provider.value(value: widget.services.recorder),
        Provider.value(value: widget.services.player),
        Provider.value(value: widget.services.calls),
      ],
      child: MaterialApp.router(
        title: 'Family Call',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        routerConfig: _router,
      ),
    );
  }
}
