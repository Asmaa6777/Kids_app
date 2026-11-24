import 'dart:math';

/// "Count with me": show N things, pick the right number out of three.
class CountingRound {
  CountingRound({required this.target, required this.choices});

  /// A new round with a target from [min] to [max] and two different wrong answers.
  factory CountingRound.random({int min = 1, int max = 10, Random? random}) {
    assert(max - min >= 2, 'need at least 3 numbers to choose from');
    final r = random ?? Random();
    final target = min + r.nextInt(max - min + 1);
    final choices = <int>{target};
    while (choices.length < 3) {
      final wrong = target + r.nextInt(5) - 2; // close numbers are the useful ones to tell apart
      if (wrong >= min && wrong <= max) choices.add(wrong);
    }
    return CountingRound(target: target, choices: choices.toList()..shuffle(r));
  }

  final int target;
  final List<int> choices;

  bool check(int answer) => answer == target;
}

/// Number words for the spoken feedback ("Seven! Well done!").
const numberWords = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten'];
