import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  String _username = 'admin';
  String _password = '';
  bool _loading = false;
  String? _error;

  Future<void> _editField({
    required String label,
    required String current,
    required Function(String) onSave,
    bool obscure = false,
  }) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: obscure,
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

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await ApiService.adminLogin(_username, _password);
    if (ok && mounted) {
      context.go('/home');
    } else {
      setState(() => _error = 'Credenciais inválidas');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Admin'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.admin_panel_settings,
                    size: 64, color: Colors.deepPurple),
                const SizedBox(height: 24),
                InkWell(
                  onTap: () => _editField(
                    label: 'Usuário',
                    current: _username,
                    onSave: (v) => setState(() => _username = v),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Usuário',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    child: Text(_username,
                        style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _editField(
                    label: 'Senha',
                    current: _password,
                    obscure: true,
                    onSave: (v) => setState(() => _password = v),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    child: Text(
                      _password.isEmpty ? 'Toque OK para digitar' : '••••••••',
                      style: TextStyle(
                        fontSize: 16,
                        color: _password.isEmpty ? Colors.grey : Colors.black87,
                      ),
                    ),
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
                    onPressed: _loading ? null : _login,
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
