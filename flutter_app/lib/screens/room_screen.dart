import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

class RoomScreen extends StatefulWidget {
  final String roomId;
  final Map<String, dynamic> room;
  final String singerName;

  const RoomScreen({
    super.key,
    required this.roomId,
    required this.room,
    required this.singerName,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  List<Map<String, dynamic>> _songs = [];
  List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> _scoreboard = [];
  final _searchController = TextEditingController();
  bool _loading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final songs = await ApiService.getSongs();
      final queue = await ApiService.getQueue(widget.roomId);
      final scores = await ApiService.getScoreboard(widget.roomId);
      setState(() {
        _songs = songs;
        _queue = queue;
        _scoreboard = scores;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _search(String q) async {
    final songs = await ApiService.getSongs(query: q.isEmpty ? null : q);
    setState(() => _songs = songs);
  }

  Future<void> _addToQueue(Map<String, dynamic> song) async {
    await ApiService.addToQueue(widget.roomId, song['id'], widget.singerName);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${song['title']}" adicionada à fila!')),
    );
    _load();
  }

  Future<void> _sing(Map<String, dynamic> song) async {
    context.go('/play/${widget.roomId}/${song['id']}', extra: {
      'song': song,
      'singerName': widget.singerName,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room['name'] ?? 'Sala'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          Chip(
            label: Text(
              widget.room['code'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
          ),
          const SizedBox(width: 8),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          onTap: (i) => setState(() => _tab = i),
          tabs: const [
            Tab(icon: Icon(Icons.music_note), text: 'Músicas'),
            Tab(icon: Icon(Icons.queue_music), text: 'Fila'),
            Tab(icon: Icon(Icons.leaderboard), text: 'Placar'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _tab,
              children: [
                _SongsTab(
                  songs: _songs,
                  searchController: _searchController,
                  onSearch: _search,
                  onAddToQueue: _addToQueue,
                  onSing: _sing,
                ),
                _QueueTab(queue: _queue, singerName: widget.singerName),
                _ScoreboardTab(scores: _scoreboard),
              ],
            ),
    );
  }
}

class _SongsTab extends StatelessWidget {
  final List<Map<String, dynamic>> songs;
  final TextEditingController searchController;
  final Function(String) onSearch;
  final Function(Map<String, dynamic>) onAddToQueue;
  final Function(Map<String, dynamic>) onSing;

  const _SongsTab({
    required this.songs,
    required this.searchController,
    required this.onSearch,
    required this.onAddToQueue,
    required this.onSing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: searchController,
            onChanged: onSearch,
            decoration: const InputDecoration(
              hintText: 'Buscar músicas...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, i) {
              final song = songs[i];
              return ListTile(
                leading: const Icon(Icons.music_note, color: Colors.deepPurple),
                title: Text(song['title'] ?? ''),
                subtitle: Text(song['artist'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.queue_music),
                      tooltip: 'Adicionar à fila',
                      onPressed: () => onAddToQueue(song),
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_circle, color: Colors.deepPurple),
                      tooltip: 'Cantar agora',
                      onPressed: () => onSing(song),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QueueTab extends StatelessWidget {
  final List<Map<String, dynamic>> queue;
  final String singerName;

  const _QueueTab({required this.queue, required this.singerName});

  @override
  Widget build(BuildContext context) {
    if (queue.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.queue_music, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Fila vazia — adicione músicas!', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: queue.length,
      itemBuilder: (context, i) {
        final item = queue[i];
        final status = item['status'] ?? 'waiting';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: status == 'singing' ? Colors.green : Colors.deepPurple.shade100,
            child: Text('${i + 1}'),
          ),
          title: Text(item['singer_name'] ?? ''),
          subtitle: Text(item['song_id'] ?? ''),
          trailing: status == 'singing'
              ? const Chip(label: Text('Cantando 🎤'), backgroundColor: Colors.green)
              : null,
        );
      },
    );
  }
}

class _ScoreboardTab extends StatelessWidget {
  final List<Map<String, dynamic>> scores;

  const _ScoreboardTab({required this.scores});

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Nenhum score ainda — cante para aparecer aqui!', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: scores.length,
      itemBuilder: (context, i) {
        final s = scores[i];
        final medal = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}.';
        return ListTile(
          leading: Text(medal, style: const TextStyle(fontSize: 24)),
          title: Text(s['singer_name'] ?? ''),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${s['score']}pts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${((s['accuracy'] ?? 0) * 100).toStringAsFixed(0)}% precisão',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}
