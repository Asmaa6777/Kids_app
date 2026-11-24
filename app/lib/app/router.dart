import 'package:go_router/go_router.dart';

import '../features/call/call_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/games/counting_screen.dart';
import '../features/games/game_picker_screen.dart';
import '../features/games/memory_screen.dart';
import '../features/games/tic_tac_toe_screen.dart';
import '../features/home/family_view.dart';
import '../features/home/gate_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/person_screen.dart';
import '../features/onboarding/join_screen.dart';
import '../features/onboarding/setup_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/parent/parent_screen.dart';

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
    GoRoute(path: '/parent', builder: (_, _) => const ParentScreen()),
    GoRoute(
      path: '/chat/:id',
      builder: (_, s) => ChatScreen(contactId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/call/:id',
      builder: (_, s) => CallScreen(contactId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/incoming/:id',
      builder: (_, s) => IncomingCallScreen(contactId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/games/:id',
      builder: (_, s) => GamePickerScreen(contactId: s.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'ttt',
          builder: (_, s) => TicTacToeScreen(contactId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: 'memory',
          builder: (_, s) => MemoryScreen(contactId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: 'count',
          builder: (_, s) => CountingScreen(contactId: s.pathParameters['id']!),
        ),
      ],
    ),
  ],
);
