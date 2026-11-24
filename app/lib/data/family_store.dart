import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../backend/family_backend.dart';
import '../logic/invite_code.dart';
import '../logic/pin.dart';
import '../logic/quiet_hours.dart';
import '../theme/colors.dart';
import 'family_repository.dart';
import 'models.dart';

/// The app's single source of truth.
///
/// Pattern: screens *read* `store.state` and *call* methods like
/// `store.addContact(...)`. Each method builds a new [FamilyState], saves it,
/// and calls `notifyListeners()`, which rebuilds every screen that watches the
/// store (via `context.watch<FamilyStore>()` from the provider package).
///
/// Two modes:
///   * Offline (no [backend]): everything stays on this device, like the prototype.
///   * Online: the same methods also write to Firebase, and live updates from
///     Firebase (another phone sent a message, the parent added someone) flow
///     back in through [_listen]. Screens don't know which mode they're in.
class FamilyStore extends ChangeNotifier {
  FamilyStore(this._repo, this._state, {DateTime Function()? clock, this.backend}) : _clock = clock ?? DateTime.now {
    if (online) _listen();
  }

  final FamilyRepository _repo;
  final DateTime Function() _clock; // injectable so tests can fake the time
  final FamilyBackend? backend;
  FamilyState _state;

  FamilyState get state => _state;
  DateTime get now => _clock();

  /// Connected to a family on the server.
  bool get online => backend != null && _state.familyId != null;

  /// The last server error, for a screen to show (then clear with [clearError]).
  String? lastError;

  static Future<FamilyStore> open(FamilyRepository repo, {DateTime Function()? clock, FamilyBackend? backend}) async =>
      FamilyStore(repo, await repo.load(), clock: clock, backend: backend);

  void _update(FamilyState next) {
    _state = next;
    notifyListeners();
    _repo.save(next); // fire-and-forget: the UI doesn't wait for the disk
  }

  void _log(String text) {
    final entry = ActivityEntry(now, text);
    _update(_state.copyWith(activity: [entry, ..._state.activity].take(60).toList()));
  }

  /// Server writes wait in line, so they land in the order they were made.
  /// (Without this, a slow voice-note upload could arrive *after* a sticker
  /// sent later, or two quick reorders could overwrite each other.)
  Future<void> _queue = Future.value();

  /// Runs a server write without blocking the UI. A failure is remembered in [lastError].
  void _remote(Future<void> Function(FamilyBackend b, String familyId) write) {
    if (!online) return;
    final b = backend!, fid = _state.familyId!;
    _queue = _queue.then((_) => write(b, fid)).catchError((Object e) {
      lastError = '$e';
      notifyListeners();
    });
  }

  /// Completes when every queued server write has finished (used by tests).
  Future<void> get pendingWrites => _queue;

  void clearError() => lastError = null;

  // ---------- derived values ----------

  bool get isQuiet => _state.role == Role.child && isQuietTime(_state.settings, now);
  bool get _iAmChild => _state.role != Role.family;

  Contact? contact(String id) => id == 'child'
      ? Contact(id: 'child', name: _state.childName.isEmpty ? 'Mia' : _state.childName, color: FamilyColor.blue)
      : _state.contacts.where((c) => c.id == id).firstOrNull;

  List<ChatMessage> messagesWith(String id) => _state.messages[id] ?? const [];

  /// UI id → server thread id. A relative's app shows the child as 'child';
  /// on the server their thread is named after their own contact tile.
  String _thread(String uiId) => (uiId == 'child' ? _state.myContactId : null) ?? uiId;

  // ---------- live sync (online only) ----------

  final _subs = <String, StreamSubscription<Object?>>{};
  String? _viewing; // the chat currently open, so its messages don't count as unread

  void _listen() {
    final b = backend!, fid = _state.familyId!;
    _subs['family'] ??= b.watchFamily(fid).listen((f) {
      _update(_state.copyWith(childName: f.childName, settings: f.settings, contacts: f.contacts, joined: f.joined));
      _syncThreads();
    }, onError: (Object e) => lastError = '$e');
    _syncThreads();
  }

  /// One message subscription per conversation this device takes part in.
  void _syncThreads() {
    final wanted = _iAmChild ? {for (final c in _state.contacts) c.id} : {'child'};
    for (final id in [..._subs.keys]) {
      if (id != 'family' && !wanted.contains(id)) _subs.remove(id)!.cancel();
    }
    for (final uiId in wanted) {
      var first = true;
      _subs[uiId] ??= backend!.watchMessages(_state.familyId!, _thread(uiId), iAmChild: _iAmChild).listen((list) {
        final before = messagesWith(uiId).length;
        final gotNew = !first && list.length > before && !list.last.fromMe;
        first = false;
        final unread = gotNew && _viewing != uiId ? {..._state.unread, uiId} : null;
        _update(_state.copyWith(messages: {..._state.messages, uiId: list}, unread: unread));
      }, onError: (Object e) => lastError = '$e');
    }
  }

  @override
  void dispose() {
    for (final s in _subs.values) {
      s.cancel();
    }
    super.dispose();
  }

  // ---------- onboarding ----------

  /// Sets up this device for the child. Online, it also creates the family on the server.
  Future<void> completeParentSetup({required String childName, required String pin}) async {
    _update(_state.copyWith(isSetUp: true, role: Role.child, childName: childName, pinHash: PinHasher.hash(pin)));
    _log('Device set up');
    if (backend == null) return;
    try {
      final fid = await backend!.createFamily(
        childName: childName,
        settings: _state.settings,
        contacts: _state.contacts,
      );
      _update(_state.copyWith(familyId: fid));
      _listen();
    } on Object catch (e) {
      // Still usable offline; the parent can retry from the parent area.
      lastError = "Couldn't reach the server: $e";
      notifyListeners();
    }
  }

  bool checkPin(String pin) => PinHasher.verify(pin, _state.pinHash);

  void changePin(String pin) {
    _update(_state.copyWith(pinHash: PinHasher.hash(pin)));
    _log('Parent PIN changed');
  }

  /// Demo code `KIDS42` always works offline; real codes are single-use and checked by the server.
  static const demoCode = 'KIDS42';

  /// Returns null on success, or an error message to show.
  Future<String?> joinFamily({required String code, required String name, required FamilyColor color}) async {
    code = code.trim().toUpperCase();
    name = name.trim();
    if (name.isEmpty) return 'Please type your name';

    if (backend != null) {
      try {
        final r = await backend!.redeemInvite(code, name);
        _update(
          _state.copyWith(
            isSetUp: true,
            role: Role.family,
            familyId: r.familyId,
            myContactId: r.contactId,
            childName: r.childName,
            // The parent chose this person's tile name and colour.
            me: Contact(id: 'me', name: r.contactName, color: FamilyColor.byName(r.color)),
          ),
        );
        _listen();
        return null;
      } on Object catch (e) {
        return '$e';
      }
    }

    final index = _state.invites.indexWhere((i) => i.code == code && i.isValidAt(now));
    if (code != demoCode && index < 0) return 'That code is not valid or was already used';
    final invites = [..._state.invites];
    if (index >= 0) invites[index] = invites[index].markUsed(name);
    _update(
      _state.copyWith(
        isSetUp: true,
        role: Role.family,
        me: Contact(id: 'me', name: name, color: color),
        invites: invites,
      ),
    );
    return null;
  }

  // ---------- parent area ----------

  void addContact(String name, FamilyColor color) {
    final id = 'c${now.microsecondsSinceEpoch}';
    _update(
      _state.copyWith(
        contacts: [
          ..._state.contacts,
          Contact(id: id, name: name.trim(), color: color),
        ],
      ),
    );
    _log('Added $name');
    _remote((b, fid) => b.saveContacts(fid, _state.contacts));
  }

  void removeContact(String id) {
    final c = contact(id);
    _update(_state.copyWith(contacts: _state.contacts.where((x) => x.id != id).toList()));
    if (c != null) _log('Removed ${c.name}');
    _remote((b, fid) => b.deleteContact(fid, id));
  }

  /// Moves a contact one place up (-1) or down (+1) on the child's home grid.
  void moveContact(String id, int delta) {
    final list = [..._state.contacts];
    final i = list.indexWhere((c) => c.id == id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= list.length) return;
    list.insert(j, list.removeAt(i));
    _update(_state.copyWith(contacts: list));
    _remote((b, fid) => b.saveContacts(fid, list));
  }

  void updateSettings(AppSettings settings) {
    _update(_state.copyWith(settings: settings));
    _remote((b, fid) => b.saveSettings(fid, settings));
  }

  /// A single-use code for one contact tile. Online, the server creates it.
  Future<Invite> createInvite(String contactId) async {
    final invite = online
        ? await backend!.createInvite(_state.familyId!, contactId)
        : Invite(code: generateInviteCode(), createdAt: now, contactId: contactId);
    final withContact = Invite(code: invite.code, createdAt: invite.createdAt, contactId: contactId);
    _update(_state.copyWith(invites: [withContact, ..._state.invites]));
    _log('Created invite for ${contact(contactId)?.name ?? contactId}');
    return withContact;
  }

  void switchRole(Role role) => _update(_state.copyWith(role: role));

  /// Erases everything: on the server (online) and on this device.
  Future<void> deleteAllData() async {
    if (online) await backend!.deleteFamily(_state.familyId!);
    for (final s in _subs.values) {
      s.cancel();
    }
    _subs.clear();
    _update(FamilyState.demo());
  }

  // ---------- chat ----------

  void openChat(String id) {
    _viewing = id;
    markRead(id);
  }

  void closeChat(String id) {
    if (_viewing == id) _viewing = null;
  }

  void markRead(String id) {
    if (!_state.unread.contains(id)) return;
    _update(_state.copyWith(unread: {..._state.unread}..remove(id)));
  }

  void sendMessage(String contactId, ChatMessage message) {
    if (online && message.fromMe) {
      // Firestore shows our own write in the live stream immediately (even
      // offline), so there's no need to also add it to the list here.
      _remote((b, fid) => b.sendMessage(fid, _thread(contactId), message, iAmChild: _iAmChild));
      if (_iAmChild) _log('Sent a ${message.type.name} to ${contact(contactId)?.name ?? contactId}');
      return;
    }
    final list = [...messagesWith(contactId), message];
    _update(_state.copyWith(messages: {..._state.messages, contactId: list}));
    if (message.fromMe) {
      _log('Sent a ${message.type.name} to ${contact(contactId)?.name ?? contactId}');
    } else {
      _update(_state.copyWith(unread: {..._state.unread, contactId}));
    }
  }

  // ---------- calls ----------

  /// Rings the other phone (online only; offline the demo "answers" by itself).
  void ring(String contactId) => _remote((b, fid) => b.ring(fid, _thread(contactId), iAmChild: _iAmChild));

  /// What the call service needs to join the right room.
  ({String familyId, String threadId})? callTarget(String contactId) =>
      online ? (familyId: _state.familyId!, threadId: _thread(contactId)) : null;

  void logCall(String contactId, Duration length) =>
      _log('Video call with ${contact(contactId)?.name ?? contactId} (${length.inMinutes} min)');
}
