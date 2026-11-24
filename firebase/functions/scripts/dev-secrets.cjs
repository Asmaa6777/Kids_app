// Writes fake LiveKit secrets for the *emulator only* (.secret.local is git-ignored).
// Real secrets are set once with: firebase functions:secrets:set LIVEKIT_API_KEY
const fs = require('node:fs');
const path = require('node:path');
const file = path.join(__dirname, '..', '.secret.local');
if (!fs.existsSync(file)) {
  fs.writeFileSync(file, 'LIVEKIT_API_KEY=devkey\nLIVEKIT_API_SECRET=devsecret-for-emulator-only-0123456789\n');
}
