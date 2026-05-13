import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karaoké 🎤'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (ApiService.isAdmin)
            TextButton.icon(
              onPressed: () => context.go('/home/admin'),
              icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
              label: const Text('Admin', style: TextStyle(color: Colors.white)),
            )
          else
            TextButton.icon(
              onPressed: () => context.go('/home/admin/login'),
              icon: const Icon(Icons.lock_outline, color: Colors.white),
              label: const Text('Admin', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mic, size: 80, color: Colors.deepPurple),
                const SizedBox(height: 24),
                _BigButton(
                  icon: Icons.group_add,
                  label: 'Entrar numa sala',
                  subtitle: 'Digite o código da sala',
                  onTap: () => context.go('/home/join'),
                ),
                const SizedBox(height: 16),
                if (ApiService.isAdmin)
                  _BigButton(
                    icon: Icons.add_circle,
                    label: 'Criar sala',
                    subtitle: 'Somente admin',
                    color: Colors.deepPurple,
                    onTap: () => context.go('/home/admin'),
                  ),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () => context.go('/setup'),
                  child: Text(
                    'Servidor: ${ApiService.serverUrl}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  const _BigButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.color = Colors.deepPurpleAccent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 36),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
