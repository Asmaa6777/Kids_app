import '../backend/family_backend.dart';
import 'call_service.dart';
import 'kiosk.dart';
import 'push.dart';
import 'speaker.dart';
import 'voice.dart';

/// Every device feature the app uses, in one bundle.
///
/// `AppServices.device()` talks to the real phone; `AppServices.fake()` is for
/// tests. Screens only see the interfaces, so they can't tell the difference.
class AppServices {
  const AppServices({
    required this.speaker,
    required this.kiosk,
    required this.recorder,
    required this.player,
    required this.calls,
    required this.push,
  });

  /// [backend] is set when Firebase is configured: calls then use real LiveKit tokens and push is on.
  factory AppServices.device({FamilyBackend? backend}) => AppServices(
    speaker: TtsSpeaker(),
    kiosk: AndroidKiosk(),
    recorder: DeviceVoiceRecorder(),
    player: DeviceVoicePlayer(),
    calls: defaultCallService(backend: backend),
    push: backend != null ? FirebasePushService() : NoPushService(),
  );

  factory AppServices.fake() => AppServices(
    speaker: RecordingSpeaker(),
    kiosk: FakeKiosk(),
    recorder: FakeVoiceRecorder(),
    player: FakeVoicePlayer(),
    calls: DemoCallService(),
    push: NoPushService(),
  );

  final Speaker speaker;
  final Kiosk kiosk;
  final VoiceRecorder recorder;
  final VoicePlayer player;
  final CallService calls;
  final PushService push;
}
