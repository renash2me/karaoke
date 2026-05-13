import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'services/api_service.dart';
import 'screens/setup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/join_room_screen.dart';
import 'screens/display_screen.dart';
import 'screens/admin_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(const KaraokeApp());
}

final _router = GoRouter(
  initialLocation: ApiService.serverUrl.isEmpty ? '/setup' : '/home',
  routes: [
    GoRoute(path: '/setup', builder: (_, __) => const SetupScreen()),
    GoRoute(
      path: '/home',
      builder: (_, __) => const HomeScreen(),
      routes: [
        GoRoute(path: 'join', builder: (_, __) => const JoinRoomScreen()),
        GoRoute(path: 'admin/login', builder: (_, __) => const AdminLoginScreen()),
      ],
    ),
    GoRoute(
      path: '/display/:roomId',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return DisplayScreen(
          roomId: state.pathParameters['roomId']!,
          room: extra['room'],
        );
      },
    ),
  ],
);

class KaraokeApp extends StatelessWidget {
  const KaraokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Karaoké',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFa855f7),
          secondary: Color(0xFF3b82f6),
        ),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
