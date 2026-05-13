import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String _url = ApiService.serverUrl.isNotEmpty ? ApiService.serverUrl : 'http://';
  bool _testing = false;
  String? _error;

  Future<void> _editUrl() async {
    final controller = TextEditingController(text: _url);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('URL do servidor'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          onSubmitted: (v) => Navigator.of(context).pop(v),
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.100:9881',
            border: OutlineInputBorder(),
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
    if (result != null) setState(() => _url = result);
  }

  Future<void> _connect() async {
    setState(() {
      _testing = true;
      _error = null;
    });
    try {
      await ApiService.setServerUrl(_url);
      await ApiService.init();
      await ApiService.getSongs();
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = 'Não foi possível conectar. Verifique a URL.');
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
                Text('Karaoké',
                    style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                const Text('Conecte ao seu servidor',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),
                InkWell(
                  onTap: _editUrl,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'URL do servidor',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.dns),
                    ),
                    child: Text(
                      _url,
                      style: const TextStyle(fontSize: 16),
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
                    onPressed: _testing ? null : _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: _testing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Conectar',
                            style: TextStyle(fontSize: 16)),
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
