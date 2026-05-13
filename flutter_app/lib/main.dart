import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'services/api_service.dart';
import 'screens/setup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/join_room_screen.dart';
import 'screens/room_screen.dart';
import 'screens/player_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_rooms_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(const KaraokeApp());
}

final _router = GoRouter(
  initialLocation: ApiService.serverUrl.isEmpty ? '/setup' : '/home',
  routes: [
    GoRoute(
      path: '/setup',
      builder: (_, __) => const SetupScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (_, __) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'join',
          builder: (_, __) => const JoinRoomScreen(),
        ),
        GoRoute(
          path: 'admin/login',
          builder: (_, __) => const AdminLoginScreen(),
        ),
        GoRoute(
          path: 'admin',
          builder: (_, __) => const AdminRoomsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/room/:roomId',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return RoomScreen(
          roomId: state.pathParameters['roomId']!,
          room: extra['room'],
          singerName: extra['singerName'],
        );
      },
      routes: [
        GoRoute(
          path: 'play/:songId',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            return PlayerScreen(
              roomId: state.pathParameters['roomId']!,
              songId: state.pathParameters['songId']!,
              song: extra['song'],
              singerName: extra['singerName'],
            );
          },
        ),
      ],
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
