import '../data/models.dart';

/// Everything the app needs from the server, as one interface.
///
/// Why an interface? The store and screens only talk to this, so:
///   * tests run against fakes (no network, no emulator),
///   * the app still works with no backend at all (offline demo mode),
///   * swapping Firebase for something else later touches one file.
abstract interface class FamilyBackend {
  /// Signs this device in (anonymously the first time) and returns its user id.
  Future<String> signIn();

  // ---- parent (owner) ----

  /// Creates the family with the starting contacts. Returns the new family id.
  Future<String> createFamily({
    required String childName,
    required AppSettings settings,
    required List<Contact> contacts,
  });
  Future<void> saveContacts(String familyId, List<Contact> contacts);
  Future<void> deleteContact(String familyId, String contactId);
  Future<void> saveSettings(String familyId, AppSettings settings);
  Future<Invite> createInvite(String familyId, String contactId);
  Future<void> deleteFamily(String familyId);

  // ---- relative ----

  Future<JoinResult> redeemInvite(String code, String name);

  // ---- both sides ----

  Stream<RemoteFamily> watchFamily(String familyId);

  /// [iAmChild] decides which messages count as "mine" in [ChatMessage.fromMe].
  Stream<List<ChatMessage>> watchMessages(String familyId, String contactId, {required bool iAmChild});
  Future<void> sendMessage(String familyId, String contactId, ChatMessage message, {required bool iAmChild});

  /// Writes a "ringing" call document; a Cloud Function pushes it to the other phone.
  Future<void> ring(String familyId, String contactId, {required bool iAmChild});
  Future<CallToken> callToken(String familyId, String contactId);
  Future<void> registerPushToken(String token);
}

/// What the server knows about the family (the parts every member may read).
class RemoteFamily {
  const RemoteFamily({required this.childName, required this.settings, required this.contacts, required this.joined});

  final String childName;
  final AppSettings settings;
  final List<Contact> contacts; // already in home-screen order

  /// Contact ids whose relative has redeemed their invite.
  final Set<String> joined;
}

class JoinResult {
  const JoinResult({
    required this.familyId,
    required this.contactId,
    required this.childName,
    required this.contactName,
    required this.color,
  });

  final String familyId;
  final String contactId;
  final String childName;
  final String contactName;
  final String color;
}

class CallToken {
  const CallToken({required this.url, required this.token, required this.room});
  final String url;
  final String token;
  final String room;
}

/// A server refusal turned into words the app can show (e.g. "Sleepy time").
class BackendException implements Exception {
  const BackendException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}
