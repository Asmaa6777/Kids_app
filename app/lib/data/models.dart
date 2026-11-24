import '../theme/colors.dart';

/// Plain data classes. Each one can turn itself into JSON and back, so the same
/// classes work with local storage today and Firestore later.

enum Role { child, family }

/// A person the child is allowed to talk to.
class Contact {
  const Contact({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final FamilyColor color;

  Contact copyWith({String? name, FamilyColor? color}) =>
      Contact(id: id, name: name ?? this.name, color: color ?? this.color);

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'color': color.name};

  factory Contact.fromJson(Map<String, Object?> j) => Contact(
    id: j['id'] as String,
    name: j['name'] as String,
    color: FamilyColor.byName(j['color'] as String? ?? 'coral'),
  );
}

enum MessageType { voice, sticker, drawing, photo, text }

/// One chat bubble. [data] depends on [type]: a sticker key, a text, or
/// (later) a Firebase Storage URL for voice notes, drawings and photos.
class ChatMessage {
  const ChatMessage({required this.fromMe, required this.type, this.data, this.durationSeconds, required this.sentAt});

  final bool fromMe;
  final MessageType type;
  final String? data;
  final int? durationSeconds;
  final DateTime sentAt;

  Map<String, Object?> toJson() => {
    'fromMe': fromMe,
    'type': type.name,
    'data': data,
    'dur': durationSeconds,
    'at': sentAt.millisecondsSinceEpoch,
  };

  factory ChatMessage.fromJson(Map<String, Object?> j) => ChatMessage(
    fromMe: j['fromMe'] as bool,
    type: MessageType.values.byName(j['type'] as String),
    data: j['data'] as String?,
    durationSeconds: j['dur'] as int?,
    sentAt: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
  );
}

/// Parent-controlled switches (prototype: `S.settings`).
class AppSettings {
  const AppSettings({
    this.typingAllowed = false,
    this.filtersAllowed = true,
    this.quietOn = false,
    this.quietFromMinutes = 20 * 60, // 20:00
    this.quietToMinutes = 7 * 60, //    07:00
  });

  final bool typingAllowed;
  final bool filtersAllowed;
  final bool quietOn;

  /// Minutes after midnight. Storing an int avoids time-zone and format bugs.
  final int quietFromMinutes;
  final int quietToMinutes;

  AppSettings copyWith({
    bool? typingAllowed,
    bool? filtersAllowed,
    bool? quietOn,
    int? quietFromMinutes,
    int? quietToMinutes,
  }) => AppSettings(
    typingAllowed: typingAllowed ?? this.typingAllowed,
    filtersAllowed: filtersAllowed ?? this.filtersAllowed,
    quietOn: quietOn ?? this.quietOn,
    quietFromMinutes: quietFromMinutes ?? this.quietFromMinutes,
    quietToMinutes: quietToMinutes ?? this.quietToMinutes,
  );

  Map<String, Object?> toJson() => {
    'typing': typingAllowed,
    'filters': filtersAllowed,
    'quietOn': quietOn,
    'quietFrom': quietFromMinutes,
    'quietTo': quietToMinutes,
  };

  factory AppSettings.fromJson(Map<String, Object?> j) => AppSettings(
    typingAllowed: j['typing'] as bool? ?? false,
    filtersAllowed: j['filters'] as bool? ?? true,
    quietOn: j['quietOn'] as bool? ?? false,
    quietFromMinutes: j['quietFrom'] as int? ?? 20 * 60,
    quietToMinutes: j['quietTo'] as int? ?? 7 * 60,
  );
}

/// A single-use code the parent sends to a relative.
class Invite {
  const Invite({required this.code, required this.createdAt, this.usedBy});

  final String code;
  final DateTime createdAt;
  final String? usedBy;

  bool get used => usedBy != null;

  /// Codes expire after 48 hours so an old message can't be reused.
  bool isValidAt(DateTime now) => !used && now.difference(createdAt) < const Duration(hours: 48);

  Invite markUsed(String by) => Invite(code: code, createdAt: createdAt, usedBy: by);

  Map<String, Object?> toJson() => {'code': code, 'at': createdAt.millisecondsSinceEpoch, 'by': usedBy};

  factory Invite.fromJson(Map<String, Object?> j) => Invite(
    code: j['code'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
    usedBy: j['by'] as String?,
  );
}

class ActivityEntry {
  const ActivityEntry(this.at, this.text);
  final DateTime at;
  final String text;

  Map<String, Object?> toJson() => {'at': at.millisecondsSinceEpoch, 'text': text};
  factory ActivityEntry.fromJson(Map<String, Object?> j) =>
      ActivityEntry(DateTime.fromMillisecondsSinceEpoch(j['at'] as int), j['text'] as String);
}

/// Everything the app remembers on this device.
class FamilyState {
  const FamilyState({
    this.isSetUp = false,
    this.role,
    this.childName = '',
    this.pinHash,
    this.me,
    this.settings = const AppSettings(),
    this.contacts = const [],
    this.unread = const {},
    this.messages = const {},
    this.invites = const [],
    this.activity = const [],
  });

  final bool isSetUp;
  final Role? role;
  final String childName;

  /// "salt:hash" — see `logic/pin.dart`. Never the PIN itself.
  final String? pinHash;

  /// The relative using this device (only when [role] is [Role.family]).
  final Contact? me;
  final AppSettings settings;
  final List<Contact> contacts;
  final Set<String> unread;
  final Map<String, List<ChatMessage>> messages;
  final List<Invite> invites;
  final List<ActivityEntry> activity;

  /// The demo family the prototype starts with.
  factory FamilyState.demo() => const FamilyState(
    contacts: [
      Contact(id: 'g', name: 'Grandma', color: FamilyColor.coral),
      Contact(id: 'p', name: 'Grandpa', color: FamilyColor.yellow),
      Contact(id: 'd', name: 'Aunt Dina', color: FamilyColor.green),
      Contact(id: 'u', name: 'Uncle Omar', color: FamilyColor.blue),
      Contact(id: 'l', name: 'Lina', color: FamilyColor.purple),
      Contact(id: 'h', name: 'Aunt Hala', color: FamilyColor.pink),
    ],
    unread: {'g', 'u'},
  );

  FamilyState copyWith({
    bool? isSetUp,
    Role? role,
    String? childName,
    String? pinHash,
    Contact? me,
    AppSettings? settings,
    List<Contact>? contacts,
    Set<String>? unread,
    Map<String, List<ChatMessage>>? messages,
    List<Invite>? invites,
    List<ActivityEntry>? activity,
  }) => FamilyState(
    isSetUp: isSetUp ?? this.isSetUp,
    role: role ?? this.role,
    childName: childName ?? this.childName,
    pinHash: pinHash ?? this.pinHash,
    me: me ?? this.me,
    settings: settings ?? this.settings,
    contacts: contacts ?? this.contacts,
    unread: unread ?? this.unread,
    messages: messages ?? this.messages,
    invites: invites ?? this.invites,
    activity: activity ?? this.activity,
  );

  Map<String, Object?> toJson() => {
    'isSetUp': isSetUp,
    'role': role?.name,
    'childName': childName,
    'pinHash': pinHash,
    'me': me?.toJson(),
    'settings': settings.toJson(),
    'contacts': [for (final c in contacts) c.toJson()],
    'unread': unread.toList(),
    'messages': {
      for (final e in messages.entries) e.key: [for (final m in e.value) m.toJson()],
    },
    'invites': [for (final i in invites) i.toJson()],
    'activity': [for (final a in activity) a.toJson()],
  };

  factory FamilyState.fromJson(Map<String, Object?> j) {
    List<Map<String, Object?>> list(String k) => ((j[k] as List?) ?? const []).cast<Map<String, Object?>>();
    final rawMessages = (j['messages'] as Map?)?.cast<String, Object?>() ?? const {};
    return FamilyState(
      isSetUp: j['isSetUp'] as bool? ?? false,
      role: j['role'] == null ? null : Role.values.byName(j['role'] as String),
      childName: j['childName'] as String? ?? '',
      pinHash: j['pinHash'] as String?,
      me: j['me'] == null ? null : Contact.fromJson((j['me'] as Map).cast()),
      settings: AppSettings.fromJson((j['settings'] as Map?)?.cast() ?? const {}),
      contacts: [for (final c in list('contacts')) Contact.fromJson(c)],
      unread: {...((j['unread'] as List?) ?? const []).cast<String>()},
      messages: {
        for (final e in rawMessages.entries)
          e.key: [for (final m in (e.value as List).cast<Map<String, Object?>>()) ChatMessage.fromJson(m)],
      },
      invites: [for (final i in list('invites')) Invite.fromJson(i)],
      activity: [for (final a in list('activity')) ActivityEntry.fromJson(a)],
    );
  }
}
