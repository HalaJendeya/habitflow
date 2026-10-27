import 'dart:async';

import 'package:get/get.dart';

// Shows a tip or a motivational note on the Home screen.
// The note changes by itself every 30 seconds (and when the user taps it).
class TipController extends GetxController {
  final tips = [
    '💡 Small steps every day beat big steps once a month.',
    '🌱 Start with a habit so small that you cannot say no.',
    '🔥 Never miss twice. One missed day is an accident, two is the start of a new habit.',
    '⏰ Link a new habit to something you already do every day.',
    '🎯 Choose one focus for today. One thing done is better than five half done.',
    '🏆 You do not need to be perfect, you only need to come back.',
    '🌅 Morning habits are easier because your day has not started to fight you yet.',
    '📝 Write it down: a task with a time is more likely to get done.',
    '💪 Motivation gets you started, habit keeps you going.',
    '🧠 It takes time to build a habit. Be patient with yourself.',
    '✅ Checking a box feels good. Let it be your reward.',
    '🚶 Can\'t do the whole habit today? Do the smallest version of it.',
    '🌙 Prepare tomorrow tonight: choose your focus before you sleep.',
    '📈 Your streak is proof of who you are becoming.',
    '🤝 Tell a friend about your habit. It is harder to quit when someone knows.',
    '☀️ Today is a good day to start again.',
    '🎉 Celebrate every small win, they add up.',
    '🧘 Rest is part of the plan. A tired mind cannot build good habits.',
    '🔔 Set a reminder for the habit you forget most.',
    '⭐ Progress, not perfection.',
  ];

  // the note that is shown now
  final tip = ''.obs;

  int _index = 0;
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();

    // every day starts with a different note
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;

    _index = dayOfYear % tips.length;
    tip.value = tips[_index];

    // change the note every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      nextTip();
    });
  }

  void nextTip() {
    _index = (_index + 1) % tips.length;
    tip.value = tips[_index];
  }

  // the timer must stop when the controller is removed
  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
