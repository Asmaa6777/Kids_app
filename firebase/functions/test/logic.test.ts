import assert from 'node:assert/strict';
import { test } from 'node:test';

import { generateInviteCode, INVITE_ALPHABET, isId, isQuietAt, normaliseCode, roomName } from '../src/logic.js';

test('invite codes: 6 characters from the friendly alphabet, and they normalise back', () => {
  for (let i = 0; i < 500; i++) {
    const code = generateInviteCode();
    assert.equal(code.length, 6);
    assert.ok([...code].every((c) => INVITE_ALPHABET.includes(c)));
    assert.equal(normaliseCode(` ${code.toLowerCase()} `), code);
  }
});

test('normaliseCode rejects look-alikes, wrong lengths and non-strings', () => {
  for (const bad of ['ABCDE', 'ABCDEFG', 'ABCDE0', 'ABCDEO', 'ABCDE1', 'ABC/EF', 42, null]) {
    assert.equal(normaliseCode(bad), null, String(bad));
  }
});

test('isId only accepts short slash-free ids', () => {
  assert.ok(isId('fam_1-a'));
  assert.ok(!isId('a/b'));
  assert.ok(!isId(''));
  assert.ok(!isId('x'.repeat(65)));
  assert.ok(!isId(7));
});

test('quiet hours use the child\'s time zone', () => {
  const s = { quietOn: true, quietFrom: 20 * 60, quietTo: 7 * 60, utcOffsetMinutes: 120 }; // child is at UTC+2
  assert.equal(isQuietAt(s, new Date('2026-01-01T18:30:00Z')), true); //  20:30 for the child
  assert.equal(isQuietAt(s, new Date('2026-01-01T17:30:00Z')), false); // 19:30
  assert.equal(isQuietAt(s, new Date('2026-01-01T04:59:00Z')), true); //  06:59
  assert.equal(isQuietAt(s, new Date('2026-01-01T05:00:00Z')), false); // 07:00
  assert.equal(isQuietAt({ ...s, utcOffsetMinutes: -300 }, new Date('2026-01-02T02:00:00Z')), true); // 21:00 at UTC-5
  assert.equal(isQuietAt({ ...s, quietOn: false }, new Date('2026-01-01T18:30:00Z')), false);
});

test('one room per child↔relative pair', () => {
  assert.equal(roomName('fam1', 'g'), 'fam1_g');
});
