import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/family_store.dart';
import '../theme/app_theme.dart';
import 'router.dart';

/// The root widget: shares the [FamilyStore] with every screen, plus theme + router.
class FamilyCallApp extends StatefulWidget {
  const FamilyCallApp({super.key, required this.store, this.initialLocation});

  final FamilyStore store;

  /// Where to start. If null: welcome screen until set up, then home.
  final String? initialLocation;

  @override
  State<FamilyCallApp> createState() => _FamilyCallAppState();
}

class _FamilyCallAppState extends State<FamilyCallApp> {
  // Created once, not on every rebuild (rebuilding a router resets navigation).
  late final GoRouter _router = buildRouter(
    initialLocation: widget.initialLocation ?? (widget.store.state.isSetUp ? '/home' : '/'),
  );

  @override
  Widget build(BuildContext context) {
    // ChangeNotifierProvider puts the store above every screen, so any screen
    // can call context.watch<FamilyStore>() (rebuild on change) or
    // context.read<FamilyStore>() (just call a method).
    return ChangeNotifierProvider.value(
      value: widget.store,
      child: MaterialApp.router(
        title: 'Family Call',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        routerConfig: _router,
      ),
    );
  }
}
