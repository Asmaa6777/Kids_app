# Family Call — Flutter app

The real app behind `../prototype`. See `../CLAUDE.md` for the plan and rules.

```bash
flutter pub get
flutter analyze
flutter test
flutter run            # with an Android phone/emulator connected (demo calls)
```

Real video calls need a LiveKit project and a token endpoint:

```bash
flutter run --dart-define=LIVEKIT_URL=wss://PROJECT.livekit.cloud \
            --dart-define=LIVEKIT_TOKEN_URL=https://YOUR-FUNCTION/token
```

Every push builds a debug APK in GitHub Actions ("Flutter app" workflow →
artifact `family-call-debug-apk`) that can be installed on a phone.

## Layout

```
lib/
  main.dart            entry point
  app/                 root widget + router (all URLs in one table)
  theme/               colours and text styles from the prototype
  data/                models, repository (local now, Firestore later), FamilyStore
  logic/               pure Dart rules: PIN, quiet hours, invites, games
  services/            device features behind interfaces (TTS, kiosk, voice, calls)
  widgets/             shared building blocks (BubblyButton, FamilyAvatar, PinPad…)
  features/<feature>/  one folder per area: onboarding, home, chat, call, games, parent
test/                one test file per iteration + helpers.dart
```
