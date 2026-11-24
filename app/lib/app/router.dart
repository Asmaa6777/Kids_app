import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/home/home_screen.dart';
import '../features/onboarding/welcome_screen.dart';

/// All screens and their URLs in one table.
///
/// go_router maps a path like `/person/g` to a screen. Using paths (instead of
/// pushing widgets by hand) means a push notification can later open
/// "/call/g" directly, and Android's back button behaves correctly.
GoRouter buildRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    // Filled in by later iterations:
    GoRoute(path: '/setup', builder: (_, _) => const _ComingSoon('Parent setup')),
    GoRoute(path: '/join', builder: (_, _) => const _ComingSoon('Join family')),
  ],
);

class _ComingSoon extends StatelessWidget {
  const _ComingSoon(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: const Center(child: Text('Coming in the next iteration')),
  );
}
