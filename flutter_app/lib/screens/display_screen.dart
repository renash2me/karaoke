import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import '../services/cdg_parser.dart';
import '../services/pitch_service.dart';

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
  // Dados
  List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> _scores = [];
  List<Map<String, dynamic>> _songs = [];

  // Player
  final _player = AudioPlayer();
  Uint8List? _cdgData;
  final _scoreCalc = ScoreCalculator();
  bool _playing = false;
  String? _currentSongId;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;

  // Estado
  bool _loading = true;
  bool _finishing = false;
  bool _showingScore = false;
  int _scoreCountdown = 10;
  Timer? _scoreTimer;
  Timer? _refreshTimer;
  WebSocketChannel? _ws;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _load();
    _connectWS();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!_showingScore) _load();
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _scoreTimer?.cancel();
    _refreshTimer?.cancel();
    _ws?.sink.close();
    super.dispose();
  }

  void _initPlayer() {
    _positionSub = _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _stateSub = _player.playerStateStream.listen((state) {
      if (mounted) setState(() => _playing = state.playing);
      if (state.processingState == ProcessingState.completed) {
        _onSongFinished();
      }
    });
  }

  Future<void> _load() async {
    try {
      final songs = await ApiService.getSongs();
      final queue = await ApiService.getQueue(widget.roomId);
      final scores = await ApiService.getScoreboard(widget.roomId);
      if (!mounted) return;
      setState(() {
        _songs = songs;
        _queue = queue;
        _scores = scores;
        _loading = false;
      });
      _checkAutoplay();
    } catch (_) {}
  }

  void _checkAutoplay() {
    if (_showingScore || _currentSongId != null || !mounted) return;
    final waiting = _queue.where((i) => i['status'] == 'waiting').toList();
    if (waiting.isEmpty) return;
    final next = waiting.first;
    _playSong(next);
  }

  Future<void> _playSong(Map<String, dynamic> queueItem) async {
    final songId = queueItem['song_id'] as String;
    if (_currentSongId == songId) return;
    setState(() => _currentSongId = songId);

    try {
      final url = ApiService.audioUrl(songId);
      await _player.setUrl(url);
      setState(() => _duration = _player.duration ?? Duration.zero);
      _scoreCalc.reset();

      // Baixa CDG em paralelo
      _loadCdg(songId);

      await _player.play();
    } catch (e) {
      setState(() => _currentSongId = null);
    }
  }

  Future<void> _loadCdg(String songId) async {
    try {
      final response = await http.get(Uri.parse(ApiService.cdgUrl(songId)));
      if (response.statusCode == 200 && mounted) {
        setState(() => _cdgData = response.bodyBytes);
      }
    } catch (_) {
      setState(() => _cdgData = null);
    }
  }

  Future<void> _onSongFinished() async {
    if (_showingScore || _finishing) return;
    _finishing = true;
    _scoreTimer?.cancel();
    await _player.stop();

    // Submete score
    final currentItem = _queue.firstWhere(
      (i) => i['song_id'] == _currentSongId && i['status'] == 'waiting',
      orElse: () => {},
    );
    if (currentItem.isNotEmpty) {
      await ApiService.submitScore(
        widget.roomId,
        currentItem['singer_name'] ?? '',
        _scoreCalc.score,
        _scoreCalc.accuracy,
      );
      // Marca como done no backend
      await ApiService.markQueueItemDone(widget.roomId);
    }

    if (!mounted) return;
    setState(() {
      _showingScore = true;
      _scoreCountdown = 10;
    });

    _scoreTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (!_showingScore) { t.cancel(); return; }
      setState(() => _scoreCountdown--);
      if (_scoreCountdown <= 0) {
        t.cancel();
        _advanceQueue();
      }
    });
  }

  Future<void> _advanceQueue() async {
    if (!mounted) return;
    _finishing = false;
    setState(() {
      _showingScore = false;
      _currentSongId = null;
      _cdgData = null;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    await _load();
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
          if (!_showingScore) _load();
        }
      }, onDone: () => Future.delayed(const Duration(seconds: 3), _connectWS));
    } catch (_) {}
  }

  String _songTitle(String songId) {
    final song = _songs.firstWhere(
      (s) => s['id'] == songId,
      orElse: () => {'title': songId},
    );
    return song['title'] ?? songId;
  }

  String _songArtist(String songId) {
    final song = _songs.firstWhere(
      (s) => s['id'] == songId,
      orElse: () => {'artist': ''},
    );
    return song['artist'] ?? '';
  }

  Map<String, dynamic>? get _currentQueueItem {
    if (_currentSongId == null) return null;
    return _queue.firstWhere(
      (i) => i['song_id'] == _currentSongId,
      orElse: () => {},
    );
  }

  List<Map<String, dynamic>> get _waitingQueue =>
      _queue.where((i) => i['status'] == 'waiting').toList();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFa855f7)))
            : _queue.isEmpty && _currentSongId == null
                ? _buildWaiting()
                : _buildMain(),
      ),
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
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFa855f7),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(widget.room['code'] ?? '',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 32),
          const Text('Adicione músicas pelo celular para começar',
              style: TextStyle(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 8),
          Text('${ApiService.serverUrl}/app',
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMain() {
    return Row(
      children: [
        // Área principal
        Expanded(
          flex: 3,
          child: _showingScore ? _buildScoreOverlay() : _buildNowPlaying(),
        ),
        // Sidebar
        Container(
          width: 300,
          color: const Color(0xFF0d0d1a),
          child: Column(
            children: [
              _buildSidebarHeader(),
              _buildNextUp(),
              Expanded(child: _buildSidebarQueue()),
              _buildSidebarScoreboard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNowPlaying() {
    final item = _currentQueueItem;
    if (item == null || _currentSongId == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFa855f7)),
      );
    }

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFa855f7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('🎤 CANTANDO AGORA',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
          ),
          const SizedBox(height: 32),
          Text(item['singer_name'] ?? '',
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(_songTitle(_currentSongId!),
              style: const TextStyle(fontSize: 22, color: Colors.white60),
              textAlign: TextAlign.center),
          Text(_songArtist(_currentSongId!),
              style: const TextStyle(fontSize: 16, color: Colors.white38),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          // Letra CDG
          if (_cdgData != null)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CdgPlayerWidget(
                  cdgData: _cdgData!,
                  positionStream: _player.positionStream,
                ),
              ),
            )
          else
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFa855f7)),
              ),
            ),
          const SizedBox(height: 16),
          // Score em tempo real
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ScorePill(label: 'Score', value: '${_scoreCalc.score}'),
              const SizedBox(width: 24),
              _ScorePill(label: 'Precisão', value: '${(_scoreCalc.accuracy * 100).toStringAsFixed(0)}%'),
              const SizedBox(width: 24),
              _ScorePill(label: 'Nota', value: _scoreCalc.grade),
            ],
          ),
          const SizedBox(height: 32),
          // Progresso simples sem slider interativo
          _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final total = _duration.inSeconds > 0 ? _duration.inSeconds : 1;
    final progress = (_position.inSeconds / total).clamp(0.0, 1.0);
    final remaining = _duration - _position;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(Color(0xFFa855f7)),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(_position), style: const TextStyle(color: Colors.white38, fontSize: 12)),
            Text('-${_fmt(remaining)}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildScoreOverlay() {
    final item = _currentQueueItem ?? {};
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_scoreCalc.grade,
                style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold, color: Color(0xFFa855f7))),
            Text('${item['singer_name'] ?? ''}',
                style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('${_scoreCalc.score} pontos • ${(_scoreCalc.accuracy * 100).toStringAsFixed(0)}% precisão',
                style: const TextStyle(fontSize: 20, color: Colors.white60)),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text('Próxima música em $_scoreCountdown s',
                  style: const TextStyle(color: Colors.white54, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2a2a3e))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(widget.room['name'] ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFa855f7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(widget.room['code'] ?? '',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildNextUp() {
    final waiting = _waitingQueue;
    // Pula o primeiro se estiver tocando
    final nextIndex = _currentSongId != null && waiting.isNotEmpty &&
        waiting.first['song_id'] == _currentSongId ? 1 : 0;
    if (waiting.length <= nextIndex) return const SizedBox.shrink();
    final next = waiting[nextIndex];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1a1a2e),
        border: Border(bottom: BorderSide(color: Color(0xFF2a2a3e))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('A SEGUIR', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(next['singer_name'] ?? '',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          Text(_songTitle(next['song_id'] ?? ''),
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSidebarQueue() {
    final waiting = _waitingQueue;
    if (waiting.isEmpty) {
      return const Center(
        child: Text('Fila vazia', style: TextStyle(color: Colors.white24, fontSize: 12)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: waiting.length,
      itemBuilder: (context, i) {
        final item = waiting[i];
        final isCurrent = item['song_id'] == _currentSongId;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isCurrent ? const Color(0xFFa855f7) : const Color(0xFF2a2a3e),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${i + 1}',
                      style: TextStyle(
                          color: isCurrent ? Colors.white : Colors.white38,
                          fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['singer_name'] ?? '',
                        style: TextStyle(
                            color: isCurrent ? Colors.white : Colors.white70,
                            fontSize: 13,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
                        overflow: TextOverflow.ellipsis),
                    Text(_songTitle(item['song_id'] ?? ''),
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebarScoreboard() {
    if (_scores.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2a2a3e))),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏆 TOP', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 8),
          ..._scores.take(5).toList().asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            final medals = ['🥇', '🥈', '🥉'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(i < 3 ? medals[i] : '${i + 1}.', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(s['singer_name'] ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text('${s['score']}',
                      style: const TextStyle(color: Color(0xFFa855f7), fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ScorePill extends StatelessWidget {
  final String label;
  final String value;
  const _ScorePill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }
}
