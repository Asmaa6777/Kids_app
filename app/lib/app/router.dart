import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/home/family_view.dart';
import '../features/home/gate_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/person_screen.dart';
import '../features/onboarding/join_screen.dart';
import '../features/onboarding/setup_screen.dart';
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
    GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
    GoRoute(path: '/join', builder: (_, _) => const JoinScreen()),
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/family', builder: (_, _) => const FamilyView()),
    GoRoute(path: '/gate', builder: (_, _) => const GateScreen()),
    GoRoute(
      path: '/person/:id',
      builder: (_, s) => PersonScreen(contactId: s.pathParameters['id']!),
    ),
    // Filled in by later iterations:
    GoRoute(path: '/parent', builder: (_, _) => const _ComingSoon('Parent area')),
    GoRoute(path: '/chat/:id', builder: (_, _) => const _ComingSoon('Messages')),
    GoRoute(path: '/call/:id', builder: (_, _) => const _ComingSoon('Video call')),
    GoRoute(path: '/games/:id', builder: (_, _) => const _ComingSoon('Games')),
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
