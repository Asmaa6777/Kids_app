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
prototype/              ← clickable PWA prototype (no backend), deployed to GitHub Pages
  index.html            ← the whole app: HTML + CSS + JS in one file (~1300 lines)
  sw.js                 ← service worker, network-first app-shell cache
  manifest.webmanifest  ← PWA install metadata
  icon.svg
.github/workflows/
  deploy.yml            ← publishes prototype/ to GitHub Pages on push to main
  commit-authors.yml    ← checks commit authorship (rule 1)
```

The prototype follows the design file "Family Call.pdf" (pages 1–9). It simulates the other person with timers
and keeps all state in `localStorage` (key `familycall-v2`). Screens map to functions in `index.html`:

| Design page | Screen | Function |
|---|---|---|
| — | Welcome, parent setup (name → PIN ×2 → checklist), join with invite code | `welcome`, `setupParent`, `join` |
| 1 | Child home: grid of family tiles, hidden parent gate (hold top-left 3 s) | `home`, `setupGate`, `gate` |
| 2 | Person: Call / Message / Play | `person` |
| 3 | Chat: push-to-talk voice notes, stickers, drawing, camera photo, optional typing | `chat`, `setupMic`, `drawModal`, `cameraModal` |
| 4 | Incoming call | `incoming` |
| 5 | In call: real self-camera, face filters (bow, glasses, crown, stars) | `call` |
| 6–9 | Games: picker, invite, draw together, puzzle, memory match, tic-tac-toe | `picker`, `invite`, `playGame`, … |
| — | Parent area: contacts, invites, quiet hours, typing/filters toggles, activity log, change PIN | `parent`, `changePin` |
| — | Family-member (adult) view | `familyView` |

UI conventions to keep in the real app: big rounded 3D buttons (`.b3d`), line icons instead of emoji, one colour
per family member, the Baloo 2 font, voice-first for a pre-reader (`speechSynthesis` reads names aloud), and
`prefers-reduced-motion` support.

## Target: the real Android app

### Recommended stack (proposed; confirm before scaffolding)

| Need | Use (don't build) | Why |
|---|---|---|
| App framework | **Flutter** (Dart). Native Kotlin is used only where Flutter can't reach (kiosk mode, Telecom) | One codebase: the child's Android tablet **and** relatives on iPhone or Android. Every SDK below has a Flutter plugin. Alternative: Kotlin + Jetpack Compose if it will only ever be Android |
| Video and voice calls | **LiveKit** (`livekit_client`; LiveKit Cloud free tier, or self-host later) | WebRTC, TURN, rooms and reconnection handled for us. Supports custom video track processors for face filters. Alternatives: Stream Video, Agora, Daily |
| Accounts | **Firebase Auth** (relatives: Google / email link; child device: anonymous auth bound to the family) | No password for the child to remember |
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

- Run the prototype locally: `python3 -m http.server -d prototype 8000` and open `http://localhost:8000`.
- The prototype deploys automatically to GitHub Pages on push to `main` (`deploy.yml`).
- The Flutter app does not exist yet. Add its build/test commands here once it is scaffolded.
