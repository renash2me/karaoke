import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _urlController = TextEditingController(text: 'http://');
  bool _testing = false;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _testing = true;
      _error = null;
    });
    try {
      await ApiService.setServerUrl(_urlController.text);
      await ApiService.init();
      // Testa se o servidor responde
      final songs = await ApiService.getSongs();
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = 'Não foi possível conectar ao servidor. Verifique a URL.');
    } finally {
      setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mic, size: 72, color: Colors.deepPurple),
                const SizedBox(height: 16),
                Text('Karaoké', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                const Text('Conecte ao seu servidor', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL do servidor',
                    hintText: 'http://192.168.1.100:9881',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.dns),
                  ),
                  keyboardType: TextInputType.url,
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
                    onPressed: _testing ? null : _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: _testing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Conectar', style: TextStyle(fontSize: 16)),
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
