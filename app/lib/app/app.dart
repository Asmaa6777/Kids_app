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
