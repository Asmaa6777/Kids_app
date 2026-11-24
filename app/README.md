# Family Call — Flutter app

The real app behind `../prototype`. See `../CLAUDE.md` for the plan and rules.

```bash
flutter pub get
flutter analyze
flutter test
flutter run            # with an Android phone/emulator connected
```

Every push builds a debug APK in GitHub Actions ("Flutter app" workflow →
artifact `family-call-debug-apk`) that can be installed on a phone.

## Layout

```
lib/
  main.dart            entry point
  app/                 root widget + router (all URLs in one table)
  theme/               colours and text styles from the prototype
  widgets/             shared building blocks (BubblyButton, FamilyAvatar)
  features/<feature>/  one folder per area: onboarding, home, chat, call, games, parent
test/                  one test file per iteration
```
