import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../services/api_service.dart';
import '../services/pitch_service.dart';

class PlayerScreen extends StatefulWidget {
  final String roomId;
  final String songId;
  final Map<String, dynamic> song;
  final String singerName;

  const PlayerScreen({
    super.key,
    required this.roomId,
    required this.songId,
    required this.song,
    required this.singerName,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _player = AudioPlayer();
  final _scoreCalc = ScoreCalculator();
  bool _playing = false;
  bool _finished = false;
  int _currentScore = 0;
  double _accuracy = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final url = ApiService.audioUrl(widget.songId);
    await _player.setUrl(url);
    setState(() => _duration = _player.duration ?? Duration.zero);

    _positionSub = _player.positionStream.listen((pos) {
      setState(() {
        _position = pos;
        _currentScore = _scoreCalc.score;
        _accuracy = _scoreCalc.accuracy;
      });
    });

    _stateSub = _player.playerStateStream.listen((state) {
      setState(() => _playing = state.playing);
      if (state.processingState == ProcessingState.completed) {
        _onFinished();
      }
    });

    // Auto-play ao entrar na tela
    await _player.play();
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _onFinished() async {
    if (_finished) return;
    setState(() => _finished = true);
    await _player.stop();

    await ApiService.submitScore(
      widget.roomId,
      widget.singerName,
      _scoreCalc.score,
      _scoreCalc.accuracy,
    );

    if (mounted) _showResultDialog();
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Performance concluída! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _scoreCalc.grade,
              style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple),
            ),
            Text('Score: ${_scoreCalc.score} pts',
                style: const TextStyle(fontSize: 20)),
            Text(
                'Precisão: ${(_scoreCalc.accuracy * 100).toStringAsFixed(1)}%'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/room/${widget.roomId}', extra: {
                'room': {'id': widget.roomId, 'name': '', 'code': ''},
                'singerName': widget.singerName,
              });
            },
            child: const Text('Voltar para a sala'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        await _player.stop();
        if (context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // Barra superior
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.deepPurple.shade900,
                child: Row(
                  children: [
                    const Icon(Icons.music_note, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.song['title'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          Text(widget.song['artist'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(widget.singerName,
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),

              // Área da letra
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lyrics, size: 64, color: Colors.white24),
                        SizedBox(height: 16),
                        Text('Letra sincronizada aqui',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 18)),
                        Text('(renderização CDG — Fase 2)',
                            style: TextStyle(
                                color: Colors.white24, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),

              // Score
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                color: Colors.deepPurple.shade900,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ScoreWidget(label: 'Score', value: '$_currentScore'),
                    _ScoreWidget(
                        label: 'Precisão',
                        value:
                            '${(_accuracy * 100).toStringAsFixed(0)}%'),
                    _ScoreWidget(label: 'Nota', value: _scoreCalc.grade),
                  ],
                ),
              ),

              // Progresso — sem foco para não travar no D-pad
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey.shade900,
                child: Row(
                  children: [
                    Text(_formatDuration(_position),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                    Expanded(
                      child: ExcludeFocus(
                        child: Slider(
                          value: _duration.inSeconds > 0
                              ? (_position.inSeconds /
                                      _duration.inSeconds)
                                  .clamp(0.0, 1.0)
                              : 0,
                          onChanged: (v) {
                            _player.seek(Duration(
                                seconds:
                                    (v * _duration.inSeconds).round()));
                          },
                          activeColor: Colors.deepPurple,
                        ),
                      ),
                    ),
                    Text(_formatDuration(_duration),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),

              // Controles
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.grey.shade900,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.stop, color: Colors.white),
                      onPressed: _onFinished,
                      iconSize: 36,
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: Icon(
                        _playing
                            ? Icons.pause_circle
                            : Icons.play_circle,
                        color: Colors.deepPurple.shade200,
                      ),
                      onPressed: _togglePlay,
                      iconSize: 64,
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: const Icon(Icons.mic, color: Colors.white),
                      onPressed: () {},
                      iconSize: 36,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreWidget extends StatelessWidget {
  final String label;
  final String value;

  const _ScoreWidget({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}
