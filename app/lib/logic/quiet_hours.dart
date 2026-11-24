import '../data/models.dart';

/// Is it "sleepy time" right now?
///
/// Two cases, because the window can cross midnight:
///   20:00 → 07:00   from > to : quiet if now ≥ from  OR  now < to
///   13:00 → 15:00   from ≤ to : quiet if from ≤ now < to
bool isQuietTime(AppSettings s, DateTime now) {
  if (!s.quietOn) return false;
  final n = now.hour * 60 + now.minute;
  final from = s.quietFromMinutes, to = s.quietToMinutes;
  return from <= to ? (n >= from && n < to) : (n >= from || n < to);
}

String formatMinutes(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
