// Pure helpers with no Firebase calls, so they can be unit-tested directly.
import { randomInt } from 'node:crypto';

/** Same alphabet as the app: no look-alikes (0/O, 1/I/L). */
export const INVITE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ2346789';
export const INVITE_TTL_MS = 48 * 60 * 60 * 1000;

/** crypto.randomInt is a secure random source (Math.random is not). */
export function generateInviteCode(): string {
  let code = '';
  for (let i = 0; i < 6; i++) code += INVITE_ALPHABET[randomInt(INVITE_ALPHABET.length)];
  return code;
}

export function normaliseCode(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const code = raw.trim().toUpperCase();
  return /^[A-HJ-NP-Z2-46-9]{6}$/.test(code) ? code : null;
}

/** Firestore document ids we accept from the app: short, no slashes. */
export function isId(v: unknown): v is string {
  return typeof v === 'string' && /^[A-Za-z0-9_-]{1,64}$/.test(v);
}

export interface QuietSettings {
  quietOn: boolean;
  quietFrom: number; // minutes after local midnight
  quietTo: number;
  utcOffsetMinutes: number; // the child's time zone, e.g. +120 for UTC+2
}

/**
 * Same rule as the app's isQuietTime, but on the server, so a modified app
 * can't call during sleepy time. "Local" time = the child's clock.
 */
export function isQuietAt(s: QuietSettings, now: Date): boolean {
  if (!s.quietOn) return false;
  const utcMinutes = now.getUTCHours() * 60 + now.getUTCMinutes();
  const n = (((utcMinutes + s.utcOffsetMinutes) % 1440) + 1440) % 1440;
  return s.quietFrom <= s.quietTo ? n >= s.quietFrom && n < s.quietTo : n >= s.quietFrom || n < s.quietTo;
}

/** One LiveKit room per child↔relative pair, so both phones meet in the same place. */
export function roomName(familyId: string, contactId: string): string {
  return `${familyId}_${contactId}`;
}
