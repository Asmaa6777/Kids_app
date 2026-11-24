# Family Call — Firebase backend

```
firebase/
  firestore.rules        who may read/write what (the server enforces it)
  storage.rules          who may upload/play voice notes
  functions/src/         Cloud Functions: invites, LiveKit tokens, push, delete-all-data
  functions/test/        unit tests + full-flow tests on the emulators
  rules-tests/           28 security-rules tests on the emulators
  emulate.sh             runs a command against the local emulators
```

## Run everything locally (no Firebase project needed)

```bash
npm install -g firebase-tools
cd firebase/rules-tests && npm ci && npm run emulate     # security rules tests
cd ../functions && npm ci && npm test                     # functions tests
```

To try the app against the emulators:

```bash
cd firebase && firebase emulators:start                   # leave running
cd app && flutter run --dart-define=FIREBASE_EMULATOR=10.0.2.2   # Android emulator → your computer
```

## Connect a real project (one-time, ~20 minutes)

1. **Create the project:** [console.firebase.google.com](https://console.firebase.google.com) → Add project.
   Turn **Google Analytics off**: no analytics on a child's device.
2. **Upgrade to the Blaze plan** (pay-as-you-go). Cloud Functions, Secret Manager and new Storage buckets require it.
   One family's usage stays inside the free allowance. Set a **budget alert** (e.g. $1) under Billing.
3. **Authentication** → Sign-in method → enable **Anonymous**.
4. **Firestore Database** → Create database → production mode → location **europe-west1**
   (same region as the functions; change `REGION` in `functions/src/index.ts` and
   `functionsRegion` in `app/lib/backend/firebase_config.dart` together if you pick another).
5. **Storage** → Get started.
6. **Project settings → Your apps → Add app → Android**, package name `com.familycall.family_call`.
   You don't need to download `google-services.json`. Copy the values into `app/firebase.env.json`
   (start from `app/firebase.env.example.json`; the real file is git-ignored).
7. **LiveKit** (video calls): create a project at [cloud.livekit.io](https://cloud.livekit.io) →
   Settings → Keys → create an API key. Note the key, the secret and the `wss://…` URL.
8. **Deploy:**

   ```bash
   firebase login
   cd firebase
   firebase use --add                     # pick your project
   firebase functions:secrets:set LIVEKIT_API_KEY
   firebase functions:secrets:set LIVEKIT_API_SECRET
   echo "LIVEKIT_URL=wss://YOUR-PROJECT.livekit.cloud" > functions/.env.YOUR-PROJECT-ID
   firebase deploy --only firestore,storage,functions
   ```

9. **Run the app:**

   ```bash
   cd app
   flutter run --dart-define-from-file=firebase.env.json
   ```

## How the pieces fit

| App action | What happens on the server |
|---|---|
| Parent finishes setup | App creates `families/{id}` + its owner `members/{uid}` in one batch (rules check both) |
| Parent taps 🔑 next to Grandma | `createInvite` function → single-use code, 48 h |
| Grandma types the code | `redeemInvite` function (transaction) → she becomes a member bound to the "Grandma" tile |
| Anyone sends a message | Written to `threads/{contact}/messages`; rules check the sender and set the time; `onMessageCreated` pushes |
| Anyone starts a call | App writes `calls/{id}` (`onCallCreated` pushes "ringing", or declines during quiet hours) and asks `livekitToken` for a token to the pair's room |
| Parent taps "Delete all family data" | `deleteFamily` erases the family, all subcollections, invites and files |

## Not done yet (next steps)

- **Ringing when the app is closed.** Pushes are handled while the app is open. A full-screen ringing call
  on a locked phone needs `flutter_callkit_incoming` (Android Telecom / iOS CallKit) plus a background FCM handler.
- **App Check**, so only your real app can call your backend (Play Integrity on Android).
- **Relatives' accounts are anonymous.** Reinstalling the app loses the membership. Offer
  "Sign in with Google" for relatives and link it to the anonymous account (`linkWithCredential`).
- The parent's activity log is still kept on the device only.
