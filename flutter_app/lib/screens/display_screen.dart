import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';

class DisplayScreen extends StatefulWidget {
  final String roomId;
  final Map<String, dynamic> room;

  const DisplayScreen({
    super.key,
    required this.roomId,
    required this.room,
  });

  @override
  State<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends State<DisplayScreen> {
  List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> _scores = [];
  List<Map<String, dynamic>> _songs = [];
  WebSocketChannel? _ws;
  Timer? _refreshTimer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _connectWS();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _ws?.sink.close();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final songs = await ApiService.getSongs();
      final queue = await ApiService.getQueue(widget.roomId);
      final scores = await ApiService.getScoreboard(widget.roomId);
      if (mounted) {
        setState(() {
          _songs = songs;
          _queue = queue;
          _scores = scores;
          _loading = false;
        });
      }
    } catch (_) {}

    // Autoplay: se tem música waiting e nenhuma singing, inicia automaticamente
    _checkAutoplay();
  }

  void _checkAutoplay() {
    if (!mounted) return;
    final singing = _queue.where((i) => i['status'] == 'singing').toList();
    final waiting = _queue.where((i) => i['status'] == 'waiting').toList();
    
    if (singing.isEmpty && waiting.isNotEmpty) {
      final next = waiting.first;
      final song = _songs.firstWhere(
        (s) => s['id'] == next['song_id'],
        orElse: () => {'id': next['song_id'], 'title': '', 'artist': ''},
      );
      // Pequeno delay para garantir que a tela está montada
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && context.mounted) {
          context.go('/display/${widget.roomId}/play/${next['song_id']}', extra: {
            'song': song,
            'singerName': next['singer_name'],
            'roomId': widget.roomId,
          });
        }
      });
    }
  }

  void _connectWS() {
    final wsUrl = ApiService.serverUrl
        .replaceFirst('http', 'ws')
        .replaceFirst('https', 'wss');
    try {
      _ws = WebSocketChannel.connect(Uri.parse('$wsUrl/ws/${widget.roomId}'));
      _ws!.stream.listen((data) {
        final msg = jsonDecode(data);
        if (msg['type'] == 'queue_update' || msg['type'] == 'score_update') {
          _load();
        }
      }, onDone: () {
        Future.delayed(const Duration(seconds: 3), _connectWS);
      });
    } catch (_) {}
  }

  String _songTitle(String songId) {
    final song = _songs.firstWhere(
      (s) => s['id'] == songId,
      orElse: () => {'title': songId},
    );
    return song['title'] ?? songId;
  }

  Map<String, dynamic>? get _current =>
      _queue.where((i) => i['status'] == 'singing').isNotEmpty
          ? _queue.firstWhere((i) => i['status'] == 'singing')
          : _queue.where((i) => i['status'] == 'waiting').isNotEmpty
              ? _queue.firstWhere((i) => i['status'] == 'waiting')
              : null;

  Map<String, dynamic>? get _next {
    final waiting = _queue.where((i) => i['status'] == 'waiting').toList();
    if (_current?['status'] == 'singing' && waiting.isNotEmpty) return waiting.first;
    if (_current?['status'] == 'waiting' && waiting.length > 1) return waiting[1];
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFa855f7)))
          : _queue.isEmpty
              ? _buildWaiting()
              : _buildDisplay(),
    );
  }

  Widget _buildWaiting() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mic, size: 80, color: Color(0xFFa855f7)),
          const SizedBox(height: 24),
          Text(widget.room['name'] ?? 'Sala',
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFa855f7),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              widget.room['code'] ?? '',
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 32),
          const Text('Acesse pelo celular para adicionar músicas',
              style: TextStyle(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 8),
          Text('${ApiService.serverUrl}/app',
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDisplay() {
    final current = _current;
    final next = _next;
    final waiting = _queue.where((i) => i['status'] == 'waiting').toList();

    return Column(
      children: [
        // Topo com info da sala
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: const Color(0xFF1a1a2e),
          child: Row(
            children: [
              Text(widget.room['name'] ?? '',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFa855f7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(widget.room['code'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Text('${ApiService.serverUrl}/app',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),

        Expanded(
          child: Row(
            children: [
              // Área principal — quem está cantando
              Expanded(
                flex: 3,
                child: current == null
                    ? const Center(
                        child: Text('Fila vazia',
                            style: TextStyle(color: Colors.white38, fontSize: 24)))
                    : _buildCurrentCard(current),
              ),

              // Sidebar — próximo + placar
              Container(
                width: 320,
                color: const Color(0xFF0d0d1a),
                child: Column(
                  children: [
                    if (next != null) _buildNextCard(next),
                    Expanded(child: _buildScoreboard()),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Fila
        if (waiting.length > 1)
          Container(
            height: 64,
            color: const Color(0xFF1a1a2e),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: waiting.length - (current?.containsValue('waiting') == true ? 0 : 0),
              itemBuilder: (context, i) {
                final item = waiting[i];
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2a2a3e),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${i + 1}. ',
                          style: const TextStyle(color: Colors.white38, fontSize: 13)),
                      Text(item['singer_name'] ?? '',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentCard(Map<String, dynamic> item) {
    final isSinging = item['status'] == 'singing';
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSinging)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFa855f7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('🎤 CANTANDO AGORA',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3b82f6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('⏳ PRÓXIMO',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1)),
                ),
              const SizedBox(height: 32),
              Text(item['singer_name'] ?? '',
                  style: const TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(_songTitle(item['song_id'] ?? ''),
                  style: const TextStyle(fontSize: 24, color: Colors.white60),
                  textAlign: TextAlign.center),
              if (isSinging) ...[
                const SizedBox(height: 48),
                ElevatedButton.icon(
                  onPressed: () => context.go(
                    '/room/${widget.roomId}/play/${item['song_id']}',
                    extra: {
                      'song': _songs.firstWhere(
                        (s) => s['id'] == item['song_id'],
                        orElse: () => {'id': item['song_id'], 'title': _songTitle(item['song_id']), 'artist': ''},
                      ),
                      'singerName': item['singer_name'],
                      'roomId': widget.roomId,
                    },
                  ),
                  icon: const Icon(Icons.play_circle),
                  label: const Text('Iniciar música'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFa855f7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextCard(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2a2a3e))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('A SEGUIR', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(item['singer_name'] ?? '',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text(_songTitle(item['song_id'] ?? ''),
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildScoreboard() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏆 PLACAR', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 12),
          Expanded(
            child: _scores.isEmpty
                ? const Center(
                    child: Text('Nenhum score ainda',
                        style: TextStyle(color: Colors.white24, fontSize: 13)))
                : ListView.builder(
                    itemCount: _scores.take(10).length,
                    itemBuilder: (context, i) {
                      final s = _scores[i];
                      final medals = ['🥇', '🥈', '🥉'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Text(i < 3 ? medals[i] : '${i + 1}.',
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(s['singer_name'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text('${s['score']}',
                                style: const TextStyle(
                                    color: Color(0xFFa855f7),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
