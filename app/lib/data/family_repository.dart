import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Where the family's data lives.
///
/// The screens never talk to storage directly; they go through this interface.
/// Today: [LocalFamilyRepository] (on the phone). Later: a Firestore
/// implementation with the same two methods, and no screen has to change.
abstract interface class FamilyRepository {
  Future<FamilyState> load();
  Future<void> save(FamilyState state);
}

/// Saves everything as one JSON string in SharedPreferences.
class LocalFamilyRepository implements FamilyRepository {
  static const _key = 'familycall-v1';

  @override
  Future<FamilyState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return FamilyState.demo();
    try {
      return FamilyState.fromJson((jsonDecode(raw) as Map).cast());
    } on Object {
      return FamilyState.demo(); // corrupted data: start fresh rather than crash
    }
  }

  @override
  Future<void> save(FamilyState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }
}

/// Keeps data in memory only. Used by tests.
class InMemoryFamilyRepository implements FamilyRepository {
  InMemoryFamilyRepository([FamilyState? initial]) : state = initial ?? FamilyState.demo();

  FamilyState state;
  int saves = 0;

  @override
  Future<FamilyState> load() async => state;

  @override
  Future<void> save(FamilyState s) async {
    state = s;
    saves++;
  }
}
