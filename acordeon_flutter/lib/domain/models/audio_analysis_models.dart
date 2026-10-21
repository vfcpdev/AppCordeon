class DetectedChordSegment {
  final double startTime;
  final double endTime;
  final int rootMod;
  final String quality;
  final String chordName;
  final String chordSymbol;
  final List<int> noteMods;
  final List<int> playbackMidis;
  final double confidence;

  const DetectedChordSegment({
    required this.startTime,
    required this.endTime,
    required this.rootMod,
    required this.quality,
    required this.chordName,
    required this.chordSymbol,
    required this.noteMods,
    required this.playbackMidis,
    required this.confidence,
  });

  factory DetectedChordSegment.fromJson(Map<String, dynamic> json) {
    return DetectedChordSegment(
      startTime: (json['startTime'] as num).toDouble(),
      endTime: (json['endTime'] as num).toDouble(),
      rootMod: json['rootMod'] as int? ?? 0,
      quality: json['quality'] as String? ?? 'maj',
      chordName: json['chordName'] as String? ?? '',
      chordSymbol: json['chordSymbol'] as String? ?? '',
      noteMods: (json['noteMods'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      playbackMidis: (json['playbackMidis'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
    );
  }

  Map<String, dynamic> toJson() => {
    'startTime': startTime,
    'endTime': endTime,
    'rootMod': rootMod,
    'quality': quality,
    'chordName': chordName,
    'chordSymbol': chordSymbol,
    'noteMods': noteMods,
    'playbackMidis': playbackMidis,
    'confidence': confidence,
  };
}

class KeyDetectionResult {
  final int rootMod;
  final String mode; // 'major' | 'minor'
  final String keyNameLat;
  final String keyNameAle;
  final String recommendedTuning;
  final int recommendedOffset;
  final String recommendedRow;
  final double correlation;

  const KeyDetectionResult({
    required this.rootMod,
    required this.mode,
    required this.keyNameLat,
    required this.keyNameAle,
    required this.recommendedTuning,
    required this.recommendedOffset,
    required this.recommendedRow,
    required this.correlation,
  });

  factory KeyDetectionResult.fromJson(Map<String, dynamic> json) {
    return KeyDetectionResult(
      rootMod: json['rootMod'] as int? ?? 0,
      mode: json['mode'] as String? ?? 'major',
      keyNameLat: json['keyNameLat'] as String? ?? 'Do Mayor',
      keyNameAle: json['keyNameAle'] as String? ?? 'C Major',
      recommendedTuning: json['recommendedTuning'] as String? ?? 'Cinco Letras (Bb-Eb-Ab)',
      recommendedOffset: json['recommendedOffset'] as int? ?? 10,
      recommendedRow: json['recommendedRow'] as String? ?? 'row2',
      correlation: (json['correlation'] as num?)?.toDouble() ?? 0.85,
    );
  }

  Map<String, dynamic> toJson() => {
    'rootMod': rootMod,
    'mode': mode,
    'keyNameLat': keyNameLat,
    'keyNameAle': keyNameAle,
    'recommendedTuning': recommendedTuning,
    'recommendedOffset': recommendedOffset,
    'recommendedRow': recommendedRow,
    'correlation': correlation,
  };
}

class AudioAnalysisReport {
  final double duration;
  final int bpm;
  final KeyDetectionResult mainKey;
  final List<DetectedChordSegment> chords;
  final String engine;

  const AudioAnalysisReport({
    required this.duration,
    required this.bpm,
    required this.mainKey,
    required this.chords,
    this.engine = 'Rust (WebAssembly / Native DSP)',
  });

  factory AudioAnalysisReport.fromJson(Map<String, dynamic> json) {
    return AudioAnalysisReport(
      duration: (json['duration'] as num).toDouble(),
      bpm: json['bpm'] as int? ?? 120,
      mainKey: KeyDetectionResult.fromJson(json['mainKey'] as Map<String, dynamic>),
      chords: (json['chords'] as List<dynamic>?)
              ?.map((e) => DetectedChordSegment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      engine: json['engine'] as String? ?? 'Rust (WebAssembly / Native DSP)',
    );
  }
}
