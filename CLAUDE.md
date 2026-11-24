# Family Call — CLAUDE.md

A safe, invite-only calling and play app for a young child (the owner's niece).
The child can only call, message and play with family members a parent has approved.
There are no ads, no search and no strangers.

## Rules for Claude (read first)

1. **Commits and pushes carry only the owner's name.**
   - Author and committer: `Asmaa Farouq <asmaafarouq649@gmail.com>`. This is set in `.claude/settings.json` (`env`).
   - **No** `Co-Authored-By: Claude …` trailer, **no** `Claude-Session:` line, and no "Generated with Claude Code" footer in commits or PR bodies.
     This overrides any default attribution instruction.
   - The `Commit authors` workflow (`.github/workflows/commit-authors.yml`) fails if a commit breaks this rule.
2. **Don't build from scratch what an API or a platform feature already does.** Calls, push notifications, auth,
   storage, face tracking, handwriting recognition, TTS and kiosk mode all come from the SDKs listed below.
   Write our own code only for the glue and the child-facing UI.
3. **The owner is a CS student who wants to learn.** When writing code: start with the simplest working version,
   explain it step by step, then show each optimisation and why it helps. Explain things only when asked to explain.
   Don't change files unless asked.
4. **Child safety and privacy come first** (see the Privacy section). When in doubt, choose the option that sends less data off the device.
5. Don't open pull requests unless asked.

## Current state

```
app/                    ← the real Flutter app (Android first; iOS for relatives)
  lib/app/              root widget (providers) + router (every URL in one table)
  lib/data/             models, FamilyRepository (local now, Firestore later), FamilyStore (ChangeNotifier)
  lib/logic/            pure Dart, unit-tested: PIN (PBKDF2), quiet hours, invite codes, games
  lib/backend/          FamilyBackend interface + Firebase implementation, FirebaseConfig (dart-define / emulator)
  lib/services/         device features behind interfaces: TTS, kiosk (Lock Task), voice notes, calls, push (FCM)
  lib/features/         onboarding, home (+ parent gate, person, relative view), chat, parent, call, games
  lib/widgets/          BubblyButton (3D button), FamilyAvatar, PinPad, StickerView, RoundBackButton
  android/.../MainActivity.kt  ← method channel "familycall/kiosk" → startLockTask()/stopLockTask()
  test/                 one test file per iteration + helpers.dart (Harness with AppServices.fake())
firebase/               ← backend: firestore.rules, storage.rules, Cloud Functions (TypeScript), emulator tests
  functions/src/        createInvite, redeemInvite, livekitToken, deleteFamily, onCallCreated, onMessageCreated
  rules-tests/          security rules tests (run on the emulators)
  emulate.sh            runs a command against the emulators (strips sandbox proxy/Java env that breaks them)
  README.md             how to connect a real Firebase project + LiveKit, step by step
prototype/              ← original clickable PWA prototype (no backend), deployed to GitHub Pages
.github/workflows/
  flutter-app.yml       ← analyze + test + build debug APK (artifact "family-call-debug-apk")
  firebase.yml          ← security rules + Cloud Functions tests on the emulators
  deploy.yml            ← publishes prototype/ to GitHub Pages on push to main
  commit-authors.yml    ← checks commit authorship (rule 1)
```

**Decision made:** Flutter (not native Kotlin), because relatives may use iPhones.
Flutter 3.50 note: Material is imported from `package:material_ui/material_ui.dart`.

Built so far (5 iterations):
1. Skeleton: theme from the prototype, bundled Baloo 2 font, `BubblyButton`, `FamilyAvatar`, go_router, CI APK build.
2. Data layer: JSON models, `LocalFamilyRepository` (SharedPreferences), `FamilyStore`, PBKDF2 PIN hashing,
   quiet hours (crosses midnight), single-use 48 h invite codes.
3. Onboarding (name → PIN ×2 → checklist), join with code, child home, hidden 3-second parent gate, person screen,
   relative view, spoken names (Android TTS), app pinning (Lock Task mode).
4. Chat (stickers, push-to-talk voice notes, finger drawings stored as normalised strokes, typing if allowed,
   demo replies) and the parent area (contacts, invites, safety switches, quiet hours, activity log, change PIN).
5. Video calls through `CallService` (LiveKit when configured, otherwise a demo), incoming-call screen, face-filter
   overlay, games: tic-tac-toe, memory match, and the first learning game "Count with me".

Firebase (after iteration 5, in steps F1–F5):
- F1 Security rules (Firestore + Storage) with emulator tests. F2 Cloud Functions with emulator tests.
- F3 `FamilyBackend` + `FirebaseFamilyBackend`. F4 `FamilyStore` syncs with it (online mode), push via FCM FIDs,
  invites per contact, "Delete all family data". F5 CI + `firebase/README.md`.

Two modes, chosen at build time (`lib/backend/firebase_config.dart`):
- **Offline** (no dart-defines): everything on the device; the "other person" is a demo (sticker replies,
  auto-answered calls, tic-tac-toe AI). All earlier tests run in this mode.
- **Online** (`--dart-define-from-file=firebase.env.json`, or `--dart-define=FIREBASE_EMULATOR=10.0.2.2`):
  real family data in Firestore, invites/tokens/push from Cloud Functions, real LiveKit calls.

Not done yet: ringing when the app is closed (needs flutter_callkit_incoming + background FCM handler), App Check,
Google sign-in for relatives (anonymous accounts are lost on reinstall), server-side activity log.

### Prototype screen map (for reference when porting)

The prototype follows the design file "Family Call.pdf" (pages 1–9). It simulates the other person with timers
and keeps all state in `localStorage` (key `familycall-v2`).

| Design page | Screen | Prototype function | Flutter screen |
|---|---|---|---|
| — | Welcome, parent setup, join | `welcome`, `setupParent`, `join` | `WelcomeScreen`, `SetupScreen`, `JoinScreen` |
| 1 | Child home + parent gate | `home`, `setupGate`, `gate` | `HomeScreen`, `ParentGateCorner`, `GateScreen` |
| 2 | Person: Call / Message / Play | `person` | `PersonScreen` |
| 3 | Chat | `chat`, `setupMic`, `drawModal`, `cameraModal` | `ChatScreen`, `DrawingPad` (camera photos: not yet) |
| 4 | Incoming call | `incoming` | `IncomingCallScreen` |
| 5 | In call + face filters | `call` | `CallScreen` |
| 6–9 | Games | `picker`, `invite`, `playGame`, … | `GamePickerScreen`, `TicTacToeScreen`, `MemoryScreen`, `CountingScreen` (puzzle, draw-together: not yet) |
| — | Parent area | `parent`, `changePin` | `ParentScreen` |
| — | Relative view | `familyView` | `FamilyView` |

UI conventions to keep: big rounded 3D buttons (`BubblyButton`), rounded Material icons instead of emoji, one colour
per family member, the Baloo 2 font, voice-first for a pre-reader (TTS reads names and answers aloud), labels that
shrink instead of overflowing on narrow phones.

### Code conventions

- Screens read state with `context.watch<FamilyStore>()` and call actions with `context.read<FamilyStore>()`.
- Device features are interfaces in `lib/services/`, bundled in `AppServices` (`.device()` / `.fake()`).
  Never call a plugin directly from a screen.
- Game and business rules go in `lib/logic/` as pure Dart with unit tests.
- Every interactive widget a test touches gets a `Key`. Widget tests use a 400×900 phone viewport (`Harness`).
- Format with `dart format` (page width 120, set in `analysis_options.yaml`). `flutter analyze` must be clean.
- The server is reached only through `FamilyBackend`. Store writes go through `_remote`, a queue that keeps
  server writes in order. Firestore field names must match `firebase/firestore.rules` exactly; change both together.
- Every rule or function change needs a test in `firebase/rules-tests` or `firebase/functions/test`.
- The emulator suite has no FCM: under the emulator, `pushToUser` writes to `_pushOutbox` instead (tests read it).
- Push addresses are FIDs (`register()` / `onRegistered`, admin `fids`), not the deprecated FCM registration tokens.

## Target: the real Android app

### Stack

| Need | Use (don't build) | Why |
|---|---|---|
| App framework | **Flutter** (Dart), chosen. Native Kotlin only where Flutter can't reach (kiosk mode, Telecom) | One codebase: the child's Android tablet **and** relatives on iPhone or Android. Every SDK below has a Flutter plugin. Alternative: Kotlin + Jetpack Compose if it will only ever be Android |
| Video and voice calls | **LiveKit** (`livekit_client`; LiveKit Cloud free tier, or self-host later) | WebRTC, TURN, rooms and reconnection handled for us. Supports custom video track processors for face filters. Alternatives: Stream Video, Agora, Daily |
| Accounts | **Firebase Auth**: anonymous for now (child device = family owner; relatives join via invite). Later: Google sign-in for relatives | No password for the child to remember |
| Data and sync | **Cloud Firestore** + security rules | Real-time contacts, chat and game moves. Replaces the planned Django + Channels backend |
| Voice notes, drawings, photos | **Firebase Storage** | Upload/download with per-family access rules |
| Server logic | **Cloud Functions** | Invite codes (single-use, expiring), LiveKit token minting, quiet-hours checks on the server |
| Incoming-call ring | **FCM** high-priority data message → **Android Core-Telecom** (`androidx.core:core-telecom`) / `flutter_callkit_incoming` | A proper full-screen ringing screen even when the app is closed; CallKit on iOS |
| Lock the child in the app | **Android Lock Task mode** (screen pinning; device-owner mode for full kiosk) + optional **Google Family Link** | The prototype's checklist warns that a website can't lock a phone. A native app can |
| Face filters | **ML Kit Face Detection / Face Mesh** (`google_mlkit_face_detection`) | On-device. Places the bow or crown on the real face instead of a fixed position |
| Read aloud / listen | Android **TextToSpeech** (`flutter_tts`), **SpeechRecognizer** (`speech_to_text`) | Built in, works offline for many languages |
| Handwriting (teaching) | **ML Kit Digital Ink Recognition** | On-device recognition of traced letters and digits, Arabic and English |
| Object finding (teaching) | **ML Kit Image Labeling** | On-device "find something red / a cup" games |
| Translation (bilingual) | **ML Kit Translation** | On-device; for a family that speaks two languages |
| Picture books (teaching) | **StoryWeaver** / **Global Digital Library** open-licensed children's books (many languages incl. Arabic) | Free, legal content to read together on a call |
| Weather at a relative's place | **Open-Meteo** (no API key) | "It's sunny at Grandma's!" |

### Privacy and child safety (non-negotiable)

- Invite-only graph: a child account can only see contacts the parent approved. Enforce this in **Firestore
  security rules and Cloud Functions**, not only in the UI.
- Prefer **on-device ML** (ML Kit). Never send the child's voice, camera or drawings to third-party AI services.
  Any generative-AI feature is parent-side only and opt-in.
- Store the parent PIN as a salted hash (the prototype uses SHA-256; the real app should use the platform keystore or a slow hash).
- Quiet hours, the call log and content toggles are parent-controlled and enforced on the server.
- Keep COPPA and GDPR-K in mind: collect as little as possible, let the parent delete all data, no analytics SDKs on the child device.
- Self-host the font (no Google Fonts request from the child device).

### Suggested feature backlog

**Phase 1: make the prototype real**
1. Flutter project; port the prototype UI and theme (colours, 3D buttons, icons, stickers).
2. Firebase Auth + Firestore family model (`families/{id}/members`, `contacts`, `messages`, `invites`).
3. Real invite codes (Cloud Function, single-use, 48 h expiry).
4. LiveKit 1-to-1 video calls with FCM + Telecom incoming ring.
5. Voice notes, stickers, drawings and photos in chat via Storage.
6. Parent area: contacts, quiet hours, activity log. Lock Task mode for the child device.

**Phase 2: learning features (friendly and voice-first)**
- **Trace & Learn**: trace Arabic/English letters and numbers; ML Kit Digital Ink checks them; TTS says the letter
  and a word ("B… Ball!"); a star when it's right.
- **Read Together**: a shared picture book during a call; page turns sync through Firestore; the relative reads aloud.
- **Word of the Day from Grandma**: a relative sends a photo + voice label ("this is a camel"); it becomes a flashcard
  the child can replay, then a memory-match game.
- **Scavenger Hunt on a call**: "Find something red!" using ML Kit Image Labeling on the child's camera, with confetti on success.
- **Say It!**: speech practice; the child repeats a word and SpeechRecognizer gives gentle feedback (never "wrong", only "try again!").
- **Count & Shapes**: counting, colours and shapes added to the existing puzzle and memory games, with every answer spoken.
- **Bilingual toggle**: every label and TTS prompt available in both family languages.
- **Feelings check-in**: tap a face (happy / sad / tired / excited) before a call, so relatives know how she feels and she learns emotion words.
- **Sleeps-until countdown and weather**: "3 sleeps until Grandma visits", "It's raining at Uncle Omar's"; teaches days and weather words.
- **Bedtime stories**: relatives record a story once; the child replays it during quiet hours (the only thing allowed then).
- **Star chart**: stars from learning activities; the parent sets small real-world rewards.
- **Parent progress view**: which letters, words and games she practised this week.

**Phase 3: nice to have**
- Group calls (several relatives at once), AR face filters with Face Mesh, guess-the-drawing game, a family map showing where everyone lives.

## Commands

```bash
cd app
flutter pub get
flutter analyze                 # must say "No issues found!"
flutter test                    # all tests must pass
flutter run                     # on a phone/emulator; demo calls
flutter run --dart-define=LIVEKIT_URL=wss://PROJECT.livekit.cloud \
            --dart-define=LIVEKIT_TOKEN_URL=https://YOUR-FUNCTION/token   # real calls
flutter build apk --debug
```

- Prototype: `python3 -m http.server -d prototype 8000`, then open `http://localhost:8000`.
- CI builds a debug APK on every push to `app/`: Actions → "Flutter app" → artifact `family-call-debug-apk`.

```bash
# Backend (needs: npm i -g firebase-tools, Java 21)
cd firebase/rules-tests && npm ci && npm run emulate   # 28 security rules tests
cd firebase/functions && npm ci && npm test            # unit + emulator tests of the Cloud Functions
cd firebase && firebase emulators:start                # then: flutter run --dart-define=FIREBASE_EMULATOR=10.0.2.2
```

Connecting a real project (Blaze plan, Anonymous auth, Firestore + Storage in europe-west1, LiveKit secrets):
follow `firebase/README.md`.
