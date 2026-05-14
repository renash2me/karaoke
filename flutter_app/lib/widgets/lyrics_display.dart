import 'package:flutter/material.dart';

class LyricsLine {
  final int timeMs;
  final String text;
  LyricsLine({required this.timeMs, required this.text});
}

class LyricsDisplay extends StatefulWidget {
  final List<LyricsLine> lines;
  final Stream<Duration> positionStream;

  const LyricsDisplay({
    super.key,
    required this.lines,
    required this.positionStream,
  });

  @override
  State<LyricsDisplay> createState() => _LyricsDisplayState();
}

class _LyricsDisplayState extends State<LyricsDisplay> {
  int _currentIndex = -1;
  final _scrollController = ScrollController();
  late final List<GlobalKey> _lineKeys;

  @override
  void initState() {
    super.initState();
    _lineKeys = widget.lines.map((_) => GlobalKey()).toList();
    widget.positionStream.listen(_onPosition);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onPosition(Duration pos) {
    if (widget.lines.isEmpty) return;
    final ms = pos.inMilliseconds;
    int newIndex = -1;
    for (int i = widget.lines.length - 1; i >= 0; i--) {
      if (ms >= widget.lines[i].timeMs) { newIndex = i; break; }
    }
    if (newIndex != _currentIndex) {
      setState(() => _currentIndex = newIndex);
      _scrollToLine(newIndex);
    }
  }

  void _scrollToLine(int index) {
    if (index < 0 || index >= _lineKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _lineKeys[index].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.4,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) {
      return const Center(
        child: Text('♪  ♪  ♪', style: TextStyle(color: Colors.white24, fontSize: 32)),
      );
    }
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
        stops: [0.0, 0.15, 0.85, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 60),
        itemCount: widget.lines.length,
        itemBuilder: (context, i) {
          final isCurrent = i == _currentIndex;
          final isPast = i < _currentIndex;
          final isNext = i == _currentIndex + 1;
          return Container(
            key: _lineKeys[i],
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: isCurrent ? 38 : isNext ? 26 : 22,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? Colors.white : isPast ? Colors.white24 : Colors.white54,
                shadows: isCurrent
                    ? [const Shadow(color: Color(0xFFa855f7), blurRadius: 20)]
                    : [],
              ),
              child: Text(
                widget.lines[i].text.isEmpty ? '♪' : widget.lines[i].text,
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}
