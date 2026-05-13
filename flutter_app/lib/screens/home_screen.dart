import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => SystemNavigator.pop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mic, size: 80, color: Color(0xFFa855f7)),
                  const SizedBox(height: 16),
                  const Text('Karaoké',
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 48),
                  _TVButton(
                    icon: Icons.add_circle_outline,
                    label: 'Criar sala',
                    subtitle: 'Iniciar uma nova sessão de karaokê',
                    onTap: () => _createRoom(context),
                  ),
                  const SizedBox(height: 16),
                  _TVButton(
                    icon: Icons.meeting_room,
                    label: 'Entrar numa sala',
                    subtitle: 'Usar código de sala existente',
                    color: const Color(0xFF3b82f6),
                    onTap: () => context.go('/home/join'),
                  ),
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: () => context.go('/setup'),
                    child: Text(
                      'Servidor: ${ApiService.serverUrl}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createRoom(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nome da sala'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
          decoration: const InputDecoration(
            hintText: 'Ex: Festa da Renata',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Criar')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && context.mounted) {
      try {
        // Login admin para criar sala
        if (!ApiService.isAdmin) {
          context.go('/home/admin/login', extra: {'redirect': 'create', 'name': name});
          return;
        }
        final room = await ApiService.createRoom(name);
        context.go('/display/${room['id']}', extra: {'room': room});
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao criar sala')),
          );
        }
      }
    }
  }
}

class _TVButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  const _TVButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.color = const Color(0xFFa855f7),
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
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
