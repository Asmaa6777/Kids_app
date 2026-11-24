import 'package:flutter/services.dart';

/// Pins the app on the child's device (Android Lock Task mode).
/// The Kotlin side lives in android/.../MainActivity.kt.
abstract interface class Kiosk {
  Future<void> lock();
  Future<void> unlock();
}

class AndroidKiosk implements Kiosk {
  static const _channel = MethodChannel('familycall/kiosk');

  @override
  Future<void> lock() => _call('start');

  @override
  Future<void> unlock() => _call('stop');

  Future<void> _call(String method) async {
    try {
      await _channel.invokeMethod<bool>(method);
    } on Object {
      // iOS, tests, or the user declined pinning: carry on unpinned.
    }
  }
}

class FakeKiosk implements Kiosk {
  bool locked = false;
  @override
  Future<void> lock() async => locked = true;
  @override
  Future<void> unlock() async => locked = false;
}
