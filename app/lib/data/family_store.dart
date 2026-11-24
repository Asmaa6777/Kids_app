import 'package:material_ui/material_ui.dart';

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
class FamilyStore extends ChangeNotifier {
  FamilyStore(this._repo, this._state, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final FamilyRepository _repo;
  final DateTime Function() _clock; // injectable so tests can fake the time
  FamilyState _state;

  FamilyState get state => _state;
  DateTime get now => _clock();

  static Future<FamilyStore> open(FamilyRepository repo, {DateTime Function()? clock}) async =>
      FamilyStore(repo, await repo.load(), clock: clock);

  void _update(FamilyState next) {
    _state = next;
    notifyListeners();
    _repo.save(next); // fire-and-forget: the UI doesn't wait for the disk
  }

  void _log(String text) {
    final entry = ActivityEntry(now, text);
    _update(_state.copyWith(activity: [entry, ..._state.activity].take(60).toList()));
  }

  // ---------- derived values ----------

  bool get isQuiet => _state.role == Role.child && isQuietTime(_state.settings, now);

  Contact? contact(String id) => id == 'child'
      ? Contact(id: 'child', name: _state.childName.isEmpty ? 'Mia' : _state.childName, color: FamilyColor.blue)
      : _state.contacts.where((c) => c.id == id).firstOrNull;

  List<ChatMessage> messagesWith(String id) => _state.messages[id] ?? const [];

  // ---------- onboarding ----------

  void completeParentSetup({required String childName, required String pin}) {
    _update(_state.copyWith(isSetUp: true, role: Role.child, childName: childName, pinHash: PinHasher.hash(pin)));
    _log('Device set up');
  }

  bool checkPin(String pin) => PinHasher.verify(pin, _state.pinHash);

  void changePin(String pin) {
    _update(_state.copyWith(pinHash: PinHasher.hash(pin)));
    _log('Parent PIN changed');
  }

  /// Demo code `KIDS42` always works in the prototype; real codes are single-use.
  static const demoCode = 'KIDS42';

  /// Returns null on success, or an error message to show.
  String? joinFamily({required String code, required String name, required FamilyColor color}) {
    code = code.trim().toUpperCase();
    name = name.trim();
    final index = _state.invites.indexWhere((i) => i.code == code && i.isValidAt(now));
    if (code != demoCode && index < 0) return 'That code is not valid or was already used';
    if (name.isEmpty) return 'Please type your name';
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
  }

  void removeContact(String id) {
    final c = contact(id);
    _update(_state.copyWith(contacts: _state.contacts.where((x) => x.id != id).toList()));
    if (c != null) _log('Removed ${c.name}');
  }

  /// Moves a contact one place up (-1) or down (+1) on the child's home grid.
  void moveContact(String id, int delta) {
    final list = [..._state.contacts];
    final i = list.indexWhere((c) => c.id == id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= list.length) return;
    list.insert(j, list.removeAt(i));
    _update(_state.copyWith(contacts: list));
  }

  void updateSettings(AppSettings settings) => _update(_state.copyWith(settings: settings));

  Invite createInvite() {
    final invite = Invite(code: generateInviteCode(), createdAt: now);
    _update(_state.copyWith(invites: [invite, ..._state.invites]));
    _log('Created invite ${invite.code}');
    return invite;
  }

  void switchRole(Role role) => _update(_state.copyWith(role: role));

  // ---------- chat ----------

  void markRead(String id) {
    if (!_state.unread.contains(id)) return;
    _update(_state.copyWith(unread: {..._state.unread}..remove(id)));
  }

  void sendMessage(String contactId, ChatMessage message) {
    final list = [...messagesWith(contactId), message];
    _update(_state.copyWith(messages: {..._state.messages, contactId: list}));
    if (message.fromMe) {
      _log('Sent a ${message.type.name} to ${contact(contactId)?.name ?? contactId}');
    } else {
      _update(_state.copyWith(unread: {..._state.unread, contactId}));
    }
  }

  void logCall(String contactId, Duration length) =>
      _log('Video call with ${contact(contactId)?.name ?? contactId} (${length.inMinutes} min)');
}
