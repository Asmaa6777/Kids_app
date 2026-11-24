import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:material_ui/material_ui.dart';

import '../theme/colors.dart';
import '../widgets/family_avatar.dart';

/// Video calls, without writing any WebRTC ourselves.
///
/// The call screen only knows [CallService] and [CallSession]. Two implementations:
///   * [DemoCallService]: no server needed; the other person "picks up" after 2 s.
///   * [LiveKitCallService]: real calls through LiveKit (rooms, TURN, reconnects
///     all handled by the SDK). Turned on by passing two build-time settings:
///       `flutter run --dart-define=LIVEKIT_URL=wss://PROJECT.livekit.cloud`
///       `            --dart-define=LIVEKIT_TOKEN_URL=https://YOUR-FUNCTION/token`
abstract interface class CallService {
  Future<CallSession> start({required String room, required String identity});
}

abstract class CallSession extends ChangeNotifier {
  /// True once the other person has joined.
  bool get connected;
  bool get micOn;
  bool get cameraOn;

  Future<void> setMic(bool on);
  Future<void> setCamera(bool on);
  Future<void> flipCamera();
  Future<void> hangUp();

  /// The session decides how video is drawn (real video, or a placeholder).
  Widget buildRemote(BuildContext context, {required Color ring});
  Widget buildLocal(BuildContext context);
}

/// Picks LiveKit when configured, otherwise the demo.
CallService defaultCallService() {
  const url = String.fromEnvironment('LIVEKIT_URL');
  const tokenUrl = String.fromEnvironment('LIVEKIT_TOKEN_URL');
  return url.isNotEmpty && tokenUrl.isNotEmpty
      ? LiveKitCallService(url: url, tokenUrl: Uri.parse(tokenUrl))
      : DemoCallService();
}

// ---------------------------------------------------------------------------
// Demo
// ---------------------------------------------------------------------------

class DemoCallService implements CallService {
  DemoCallService({this.answerAfter = const Duration(seconds: 2)});

  final Duration answerAfter;
  DemoCallSession? last; // handy for tests

  @override
  Future<CallSession> start({required String room, required String identity}) async =>
      last = DemoCallSession(answerAfter);
}

class DemoCallSession extends CallSession {
  DemoCallSession(Duration answerAfter) {
    _answer = Timer(answerAfter, () {
      _connected = true;
      notifyListeners();
    });
  }

  late final Timer _answer;
  bool _connected = false, _mic = true, _camera = true, ended = false;
  int flips = 0;

  @override
  bool get connected => _connected;
  @override
  bool get micOn => _mic;
  @override
  bool get cameraOn => _camera;

  @override
  Future<void> setMic(bool on) async {
    _mic = on;
    notifyListeners();
  }

  @override
  Future<void> setCamera(bool on) async {
    _camera = on;
    notifyListeners();
  }

  @override
  Future<void> flipCamera() async => flips++;

  @override
  Future<void> hangUp() async {
    _answer.cancel();
    ended = true;
  }

  @override
  Widget buildRemote(BuildContext context, {required Color ring}) => Center(child: FamilyAvatar(ring: ring, size: 220));

  @override
  Widget buildLocal(BuildContext context) => ColoredBox(
    color: FamilyColor.blue.light,
    child: Icon(_camera ? Icons.person_rounded : Icons.videocam_off_rounded, size: 64, color: AppColors.silhouette),
  );
}

// ---------------------------------------------------------------------------
// LiveKit
// ---------------------------------------------------------------------------

/// Real calls. The token comes from our own backend (a Cloud Function), never
/// from the app, because the LiveKit API secret must stay on the server.
class LiveKitCallService implements CallService {
  LiveKitCallService({required this.url, required this.tokenUrl});

  final String url;
  final Uri tokenUrl;

  @override
  Future<CallSession> start({required String room, required String identity}) async {
    final res = await http.get(tokenUrl.replace(queryParameters: {'room': room, 'identity': identity}));
    if (res.statusCode != 200) throw Exception('Token server said ${res.statusCode}');
    final token = (jsonDecode(res.body) as Map)['token'] as String;

    final r = lk.Room(roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true));
    final session = _LiveKitSession(r);
    await r.connect(url, token);
    await r.localParticipant?.setCameraEnabled(true);
    await r.localParticipant?.setMicrophoneEnabled(true);
    return session;
  }
}

class _LiveKitSession extends CallSession {
  _LiveKitSession(this._room) {
    _room.addListener(notifyListeners); // participants / tracks changed → rebuild
  }

  final lk.Room _room;
  lk.CameraPosition _position = lk.CameraPosition.front;

  lk.RemoteParticipant? get _remote => _room.remoteParticipants.values.firstOrNull;

  @override
  bool get connected => _remote != null;
  @override
  bool get micOn => _room.localParticipant?.isMicrophoneEnabled() ?? false;
  @override
  bool get cameraOn => _room.localParticipant?.isCameraEnabled() ?? false;

  @override
  Future<void> setMic(bool on) async {
    await _room.localParticipant?.setMicrophoneEnabled(on);
    notifyListeners();
  }

  @override
  Future<void> setCamera(bool on) async {
    await _room.localParticipant?.setCameraEnabled(on);
    notifyListeners();
  }

  @override
  Future<void> flipCamera() async {
    final track = _room.localParticipant?.videoTrackPublications.firstOrNull?.track;
    if (track is! lk.LocalVideoTrack) return;
    _position = _position.switched();
    await track.setCameraPosition(_position);
  }

  @override
  Future<void> hangUp() async {
    _room.removeListener(notifyListeners);
    await _room.disconnect();
    await _room.dispose();
  }

  @override
  Widget buildRemote(BuildContext context, {required Color ring}) {
    final track = _remote?.videoTrackPublications.firstOrNull?.track;
    return track != null
        ? lk.VideoTrackRenderer(track, fit: lk.VideoViewFit.cover)
        : Center(child: FamilyAvatar(ring: ring, size: 220));
  }

  @override
  Widget buildLocal(BuildContext context) {
    final track = _room.localParticipant?.videoTrackPublications.firstOrNull?.track;
    return track != null
        ? lk.VideoTrackRenderer(track, fit: lk.VideoViewFit.cover)
        : const ColoredBox(color: Colors.black26);
  }
}
