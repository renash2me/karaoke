import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// CDG packet: 24 bytes cada, 75 packets por segundo
const int _kPacketSize = 24;
const int _kPacketsPerSecond = 75;
const int _kWidth = 288;
const int _kHeight = 216; // 192 + 24 border
const int _kVisibleTop = 12;
const int _kVisibleLeft = 6;

// Comandos CDG
const int _kCmdMemoryPreset = 1;
const int _kCmdBorderPreset = 2;
const int _kCmdTileBlock = 6;
const int _kCmdScrollPreset = 20;
const int _kCmdScrollCopy = 24;
const int _kCmdDefinePalette = 30; // low
const int _kCmdDefinePaletteLow = 30;
const int _kCmdDefinePaletteHigh = 31;
const int _kCmdTileBlockXOR = 38;

class CdgParser {
  final Uint8List _data;

  // Estado da tela
  final List<int> _pixels = List.filled(_kWidth * _kHeight, 0);
  final List<Color> _palette = List.filled(16, Colors.black);
  int _transparentColor = 0;
  int _currentPacket = 0;

  CdgParser(this._data);

  int get totalPackets => _data.length ~/ _kPacketSize;

  /// Avança até o packet correspondente à posição atual do áudio
  void seekTo(Duration position) {
    final targetPacket = (position.inMilliseconds * _kPacketsPerSecond / 1000).floor();
    
    if (targetPacket < _currentPacket) {
      // Volta ao início
      _reset();
    }
    
    while (_currentPacket < targetPacket && _currentPacket < totalPackets) {
      _processPacket(_currentPacket);
      _currentPacket++;
    }
  }

  void _reset() {
    _pixels.fillRange(0, _pixels.length, 0);
    for (int i = 0; i < 16; i++) _palette[i] = Colors.black;
    _transparentColor = 0;
    _currentPacket = 0;
  }

  void _processPacket(int index) {
    final offset = index * _kPacketSize;
    if (offset + _kPacketSize > _data.length) return;

    final command = _data[offset] & 0x3F;
    final instruction = _data[offset + 1] & 0x3F;

    if (command != 9) return; // Só processa comandos CDG (command = 9)

    switch (instruction) {
      case _kCmdMemoryPreset:
        _memoryPreset(offset);
        break;
      case _kCmdBorderPreset:
        _borderPreset(offset);
        break;
      case _kCmdTileBlock:
        _tileBlock(offset, xor: false);
        break;
      case _kCmdTileBlockXOR:
        _tileBlock(offset, xor: true);
        break;
      case _kCmdDefinePaletteLow:
        _definePalette(offset, high: false);
        break;
      case _kCmdDefinePaletteHigh:
        _definePalette(offset, high: true);
        break;
      case _kCmdScrollPreset:
        _scroll(offset, copy: false);
        break;
      case _kCmdScrollCopy:
        _scroll(offset, copy: true);
        break;
    }
  }

  void _memoryPreset(int offset) {
    final color = _data[offset + 4] & 0x0F;
    final repeat = _data[offset + 5] & 0x0F;
    if (repeat == 0) {
      _pixels.fillRange(0, _pixels.length, color);
    }
  }

  void _borderPreset(int offset) {
    final color = _data[offset + 4] & 0x0F;
    // Bordas superior e inferior
    for (int x = 0; x < _kWidth; x++) {
      for (int y = 0; y < _kVisibleTop; y++) {
        _pixels[y * _kWidth + x] = color;
        _pixels[(_kHeight - 1 - y) * _kWidth + x] = color;
      }
    }
    // Bordas esquerda e direita
    for (int y = 0; y < _kHeight; y++) {
      for (int x = 0; x < _kVisibleLeft; x++) {
        _pixels[y * _kWidth + x] = color;
        _pixels[y * _kWidth + (_kWidth - 1 - x)] = color;
      }
    }
  }

  void _tileBlock(int offset, {required bool xor}) {
    final color0 = _data[offset + 4] & 0x0F;
    final color1 = _data[offset + 5] & 0x0F;
    final row = (_data[offset + 6] & 0x1F) * 12;
    final col = (_data[offset + 7] & 0x3F) * 6;

    for (int y = 0; y < 12; y++) {
      final byte = _data[offset + 8 + y] & 0x3F;
      for (int x = 0; x < 6; x++) {
        final bit = (byte >> (5 - x)) & 1;
        final pixelColor = bit == 1 ? color1 : color0;
        final px = col + x;
        final py = row + y;
        if (px < _kWidth && py < _kHeight) {
          if (xor) {
            _pixels[py * _kWidth + px] ^= pixelColor;
          } else {
            _pixels[py * _kWidth + px] = pixelColor;
          }
        }
      }
    }
  }

  void _definePalette(int offset, {required bool high}) {
    final base = high ? 8 : 0;
    for (int i = 0; i < 8; i++) {
      final byte1 = _data[offset + 4 + i * 2];
      final byte2 = _data[offset + 5 + i * 2];
      final r = ((byte1 & 0x3C) >> 2) * 17;
      final g = ((byte1 & 0x03) << 2 | (byte2 & 0x30) >> 4) * 17;
      final b = (byte2 & 0x0F) * 17;
      _palette[base + i] = Color.fromARGB(255, r, g, b);
    }
  }

  void _scroll(int offset, {required bool copy}) {
    final color = _data[offset + 4] & 0x0F;
    final hScroll = _data[offset + 5] & 0x3F;
    final vScroll = _data[offset + 6] & 0x3F;

    final hCmd = (hScroll & 0x30) >> 4;
    final hOffset = hScroll & 0x07;
    final vCmd = (vScroll & 0x30) >> 4;
    final vOffset = vScroll & 0x0F;

    final temp = List<int>.from(_pixels);

    if (hCmd == 2) {
      // Scroll right
      for (int y = 0; y < _kHeight; y++) {
        for (int x = _kWidth - 1; x >= 0; x--) {
          final srcX = (x - 6 + _kWidth) % _kWidth;
          _pixels[y * _kWidth + x] = copy ? temp[y * _kWidth + srcX] : color;
        }
      }
    } else if (hCmd == 1) {
      // Scroll left
      for (int y = 0; y < _kHeight; y++) {
        for (int x = 0; x < _kWidth; x++) {
          final srcX = (x + 6) % _kWidth;
          _pixels[y * _kWidth + x] = copy ? temp[y * _kWidth + srcX] : color;
        }
      }
    }

    if (vCmd == 2) {
      // Scroll down
      for (int y = _kHeight - 1; y >= 0; y--) {
        final srcY = (y - 12 + _kHeight) % _kHeight;
        for (int x = 0; x < _kWidth; x++) {
          _pixels[y * _kWidth + x] = copy ? temp[srcY * _kWidth + x] : color;
        }
      }
    } else if (vCmd == 1) {
      // Scroll up
      for (int y = 0; y < _kHeight; y++) {
        final srcY = (y + 12) % _kHeight;
        for (int x = 0; x < _kWidth; x++) {
          _pixels[y * _kWidth + x] = copy ? temp[srcY * _kWidth + x] : color;
        }
      }
    }
  }

  /// Renderiza o frame atual como imagem
  Future<ui.Image?> render() async {
    final bytes = Uint8List(_kWidth * _kHeight * 4);
    for (int i = 0; i < _pixels.length; i++) {
      final color = _palette[_pixels[i] & 0x0F];
      bytes[i * 4] = color.red;
      bytes[i * 4 + 1] = color.green;
      bytes[i * 4 + 2] = color.blue;
      bytes[i * 4 + 3] = 255;
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      _kWidth,
      _kHeight,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}

/// Widget que exibe o CDG sincronizado com o áudio
class CdgPlayer extends StatefulWidget {
  final Uint8List cdgData;
  final Stream<Duration> positionStream;

  const CdgPlayer({
    super.key,
    required this.cdgData,
    required this.positionStream,
  });

  @override
  State<CdgPlayer> createState() => _CdgPlayerState();
}

class _CdgPlayerState extends State<CdgPlayer> {
  late CdgParser _parser;
  ui.Image? _image;
  StreamSubscription<Duration>? _sub;
  Duration _lastPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _parser = CdgParser(widget.cdgData);
    _sub = widget.positionStream.listen(_onPosition);
  }

  void _onPosition(Duration pos) {
    // Atualiza a cada ~100ms para não sobrecarregar
    if ((pos - _lastPosition).inMilliseconds.abs() < 80) return;
    _lastPosition = pos;
    _parser.seekTo(pos);
    _parser.render().then((img) {
      if (mounted && img != null) setState(() => _image = img);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFa855f7)),
      );
    }
    return RawImage(
      image: _image,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none, // Pixel art — sem anti-aliasing
    );
  }
}
