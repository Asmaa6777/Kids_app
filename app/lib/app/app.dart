import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'router.dart';

/// The root widget: theme + router.
class FamilyCallApp extends StatefulWidget {
  const FamilyCallApp({super.key, this.initialLocation = '/'});

  final String initialLocation;

  @override
  State<FamilyCallApp> createState() => _FamilyCallAppState();
}

class _FamilyCallAppState extends State<FamilyCallApp> {
  // Created once, not on every rebuild (rebuilding a router resets navigation).
  late final GoRouter _router = buildRouter(initialLocation: widget.initialLocation);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Family Call',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}
