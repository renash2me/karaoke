import 'dart:math';

/// Algoritmo de detecção de pitch simplificado (YIN)
/// Recebe amostras de áudio e retorna a frequência em Hz
class PitchDetector {
  static const double _threshold = 0.15;

  static double? detect(List<double> samples, int sampleRate) {
    if (samples.isEmpty) return null;
    final n = samples.length;
    final halfN = n ~/ 2;

    // Função de diferença acumulada normalizada (CMNDF)
    final cmndf = List<double>.filled(halfN, 0.0);
    cmndf[0] = 1.0;
    double runningSum = 0.0;

    for (int tau = 1; tau < halfN; tau++) {
      double diff = 0.0;
      for (int i = 0; i < halfN; i++) {
        final d = samples[i] - samples[i + tau];
        diff += d * d;
      }
      runningSum += diff;
      cmndf[tau] = (runningSum == 0) ? 0 : diff * tau / runningSum;
    }

    // Encontra o primeiro mínimo abaixo do threshold
    int? tau;
    for (int t = 2; t < halfN - 1; t++) {
      if (cmndf[t] < _threshold && cmndf[t] < cmndf[t + 1]) {
        tau = t;
        break;
      }
    }

    if (tau == null) return null;
    return sampleRate / tau.toDouble();
  }

  /// Converte frequência para nota MIDI (A4 = 440Hz = MIDI 69)
  static int? frequencyToMidi(double? freq) {
    if (freq == null || freq <= 0) return null;
    return (69 + 12 * log(freq / 440.0) / log(2)).round();
  }

  /// Converte MIDI para nome da nota
  static String midiToNoteName(int midi) {
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final octave = (midi / 12).floor() - 1;
    final note = notes[midi % 12];
    return '$note$octave';
  }
}

/// Calcula o score da performance comparando pitch detectado com pitch esperado
class ScoreCalculator {
  final List<int> _expectedMidi = [];
  final List<int?> _detectedMidi = [];
  int _totalSamples = 0;
  int _hitSamples = 0;
  int _currentScore = 0;

  void addExpectedNote(int midiNote) {
    _expectedMidi.add(midiNote);
  }

  void addDetectedFrequency(double? freq) {
    final midi = PitchDetector.frequencyToMidi(freq);
    _detectedMidi.add(midi);
    _totalSamples++;

    if (_expectedMidi.isNotEmpty && midi != null) {
      final expected = _expectedMidi.last;
      final diff = (midi - expected).abs();

      if (diff == 0) {
        // Nota perfeita
        _hitSamples++;
        _currentScore += 100;
      } else if (diff <= 1) {
        // Meio tom de diferença
        _hitSamples++;
        _currentScore += 60;
      } else if (diff <= 2) {
        // Tom de diferença
        _currentScore += 20;
      }
    }
  }

  int get score => _totalSamples > 0 ? (_currentScore / _totalSamples).round() : 0;

  double get accuracy =>
      _totalSamples > 0 ? _hitSamples / _totalSamples : 0.0;

  String get grade {
    final s = score;
    if (s >= 90) return 'S';
    if (s >= 80) return 'A';
    if (s >= 70) return 'B';
    if (s >= 60) return 'C';
    return 'D';
  }

  void reset() {
    _expectedMidi.clear();
    _detectedMidi.clear();
    _totalSamples = 0;
    _hitSamples = 0;
    _currentScore = 0;
  }
}
