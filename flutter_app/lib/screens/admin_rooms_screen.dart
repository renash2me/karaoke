import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

class AdminRoomsScreen extends StatefulWidget {
  const AdminRoomsScreen({super.key});

  @override
  State<AdminRoomsScreen> createState() => _AdminRoomsScreenState();
}

class _AdminRoomsScreenState extends State<AdminRoomsScreen> {
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _rooms = await ApiService.getRooms();
    setState(() => _loading = false);
  }

  Future<void> _createRoom() async {
    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova sala'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Nome da sala'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => context.pop(true), child: const Text('Criar')),
        ],
      ),
    );
    if (confirmed == true && nameController.text.isNotEmpty) {
      await ApiService.createRoom(nameController.text);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salas'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () async {
              await ApiService.adminLogout();
              if (mounted) context.go('/home');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRoom,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova sala'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.meeting_room, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Nenhuma sala ativa', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _rooms.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, i) {
                    final room = _rooms[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.meeting_room, color: Colors.deepPurple),
                        title: Text(room['name'] ?? ''),
                        subtitle: Text('Código: ${room['code']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(room['code'] ?? ''),
                              backgroundColor: Colors.deepPurple.shade50,
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios),
                              onPressed: () => context.go(
                                '/room/${room['id']}',
                                extra: {'room': room, 'singerName': 'Admin'},
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
