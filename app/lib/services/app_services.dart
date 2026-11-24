import 'kiosk.dart';
import 'speaker.dart';
import 'voice.dart';

/// Every device feature the app uses, in one bundle.
///
/// `AppServices.device()` talks to the real phone; `AppServices.fake()` is for
/// tests. Screens only see the interfaces, so they can't tell the difference.
class AppServices {
  const AppServices({required this.speaker, required this.kiosk, required this.recorder, required this.player});

  factory AppServices.device() => AppServices(
    speaker: TtsSpeaker(),
    kiosk: AndroidKiosk(),
    recorder: DeviceVoiceRecorder(),
    player: DeviceVoicePlayer(),
  );

  factory AppServices.fake() => AppServices(
    speaker: RecordingSpeaker(),
    kiosk: FakeKiosk(),
    recorder: FakeVoiceRecorder(),
    player: FakeVoicePlayer(),
  );

  final Speaker speaker;
  final Kiosk kiosk;
  final VoiceRecorder recorder;
  final VoicePlayer player;
}
