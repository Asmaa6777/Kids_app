import 'dart:math';

/// 6-character invite codes like "K7MZQ2".
///
/// The alphabet leaves out look-alikes (0/O, 1/I/L) so grandparents can type
/// the code without mistakes. 30^6 ≈ 729 million combinations, and codes are
/// single-use and expire, so guessing is impractical. In production the code
/// is created by a Cloud Function, not on the phone.
const inviteAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ2346789';

String generateInviteCode([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(6, (_) => inviteAlphabet[r.nextInt(inviteAlphabet.length)]).join();
}
