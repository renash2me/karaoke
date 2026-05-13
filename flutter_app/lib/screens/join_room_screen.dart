import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  String _name = '';
  String _code = '';
  bool _loading = false;
  String? _error;

  Future<void> _editField({
    required String label,
    required String current,
    required Function(String) onSave,
    bool allCaps = false,
  }) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization:
              allCaps ? TextCapitalization.characters : TextCapitalization.words,
          onSubmitted: (v) => Navigator.of(context).pop(v),
          decoration: InputDecoration(
            hintText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null) onSave(result);
  }

  Future<void> _join() async {
    if (_name.isEmpty || _code.isEmpty) {
      setState(() => _error = 'Preencha todos os campos');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final room = await ApiService.joinRoom(_code);
      if (mounted) {
        context.go('/room/${room['id']}', extra: {
          'room': room,
          'singerName': _name,
        });
      }
    } catch (e) {
      setState(() => _error = 'Sala não encontrada. Verifique o código.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrar na sala'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Campo nome
                _TVField(
                  label: 'Seu nome',
                  value: _name,
                  hint: 'Toque OK para digitar',
                  icon: Icons.person,
                  onTap: () => _editField(
                    label: 'Seu nome',
                    current: _name,
                    onSave: (v) => setState(() => _name = v),
                  ),
                ),
                const SizedBox(height: 16),
                // Campo código
                _TVField(
                  label: 'Código da sala',
                  value: _code,
                  hint: 'Toque OK para digitar',
                  icon: Icons.meeting_room,
                  onTap: () => _editField(
                    label: 'Código da sala',
                    current: _code,
                    allCaps: true,
                    onSave: (v) => setState(() => _code = v.toUpperCase()),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _join,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Entrar', style: TextStyle(fontSize: 16)),
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

/// Campo estilo TV — focável pelo D-pad, abre dialog ao pressionar OK
class _TVField extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;

  const _TVField({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
        child: Text(
          value.isEmpty ? hint : value,
          style: TextStyle(
            color: value.isEmpty ? Colors.grey : Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
