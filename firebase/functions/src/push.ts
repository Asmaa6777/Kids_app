// Sending push notifications through Firebase Cloud Messaging (FCM).
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';

export interface PushPayload {
  [key: string]: string; // FCM data payloads are string → string
}

/**
 * Sends a high-priority *data* message to every device of [uid].
 *
 * Data (not notification) messages let the app decide what to show: a
 * full-screen ringing screen for calls, a quiet badge for messages.
 *
 * The emulator suite has no FCM, so when running under the emulator the
 * message is written to `_pushOutbox` instead. Tests read it from there.
 */
export async function pushToUser(uid: string, data: PushPayload): Promise<number> {
  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  const tokens: string[] = (await userRef.get()).get('fcmTokens') ?? [];
  if (tokens.length === 0) return 0;

  if (process.env.FUNCTIONS_EMULATOR === 'true') {
    await db.collection('_pushOutbox').add({ uid, tokens, data, at: FieldValue.serverTimestamp() });
    return tokens.length;
  }

  const res = await getMessaging().sendEachForMulticast({
    tokens,
    data,
    android: { priority: 'high', ttl: data.type === 'call' ? 30_000 : 24 * 3600_000 },
    apns: { headers: { 'apns-priority': '10' } },
  });

  // Forget tokens of uninstalled apps so the list doesn't grow forever.
  const dead = res.responses
    .map((r, i) => (!r.success && r.error?.code === 'messaging/registration-token-not-registered' ? tokens[i] : null))
    .filter((t): t is string => t !== null);
  if (dead.length) await userRef.update({ fcmTokens: FieldValue.arrayRemove(...dead) });
  if (res.failureCount) logger.warn('push failures', { uid, failures: res.failureCount });
  return res.successCount;
}
