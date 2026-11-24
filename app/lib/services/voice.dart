import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Push-to-talk voice notes.
///
/// [start] when the finger goes down, [stop] when it lifts; [stop] returns the
/// file path (or null if nothing was recorded). Real recording uses the
/// `record` package (Android MediaRecorder under the hood), AAC in an .m4a file.
abstract interface class VoiceRecorder {
  Future<bool> start();
  Future<String?> stop();
}

abstract interface class VoicePlayer {
  Future<void> play(String path);
  Future<void> stop();
}

class DeviceVoiceRecorder implements VoiceRecorder {
  final _recorder = AudioRecorder();

  @override
  Future<bool> start() async {
    try {
      if (!await _recorder.hasPermission()) return false; // asks the first time
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<String?> stop() async {
    try {
      final path = await _recorder.stop();
      return path != null && File(path).existsSync() ? path : null;
    } on Object {
      return null;
    }
  }
}

class DeviceVoicePlayer implements VoicePlayer {
  final _player = AudioPlayer();

  @override
  Future<void> play(String path) async {
    try {
      await _player.stop();
      await _player.play(DeviceFileSource(path));
    } on Object {
      // Missing file (e.g. the demo's sample notes): stay quiet.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } on Object {
      // ignore
    }
  }
}

class FakeVoiceRecorder implements VoiceRecorder {
  bool recording = false;
  @override
  Future<bool> start() async => recording = true;
  @override
  Future<String?> stop() async {
    recording = false;
    return 'fake-voice.m4a';
  }
}

class FakeVoicePlayer implements VoicePlayer {
  final played = <String>[];
  @override
  Future<void> play(String path) async => played.add(path);
  @override
  Future<void> stop() async {}
}
