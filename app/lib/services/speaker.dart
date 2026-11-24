import 'package:flutter_tts/flutter_tts.dart';

/// Reads words aloud for a child who can't read yet.
///
/// An interface + two implementations: the real one uses Android's built-in
/// TextToSpeech engine (via flutter_tts); tests use [RecordingSpeaker], which
/// only remembers what would have been said.
abstract interface class Speaker {
  Future<void> say(String text);
}

class TtsSpeaker implements Speaker {
  final _tts = FlutterTts();
  bool _ready = false;

  @override
  Future<void> say(String text) async {
    try {
      if (!_ready) {
        await _tts.setSpeechRate(0.45); // a little slower than normal
        await _tts.setPitch(1.2); //       a little higher: friendlier
        _ready = true;
      }
      await _tts.stop();
      await _tts.speak(text);
    } on Object {
      // No TTS engine installed: the app must still work silently.
    }
  }
}

class RecordingSpeaker implements Speaker {
  final said = <String>[];
  @override
  Future<void> say(String text) async => said.add(text);
}
