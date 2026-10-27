import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../helpers/date_helper.dart';
import '../models/achievement_model.dart';
import 'habit_controller.dart';
import 'task_controller.dart';

// Unlocks achievements when the user does something good.
// Unlocked achievements are saved in: users / {userId} / achievements / {id}
class AchievementController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final habitController = Get.find<HabitController>();
  final taskController = Get.find<TaskController>();

  // all the achievements of the app
  final achievements = const [
    AchievementModel(
      id: 'first_habit',
      emoji: '🌱',
      title: 'First Step',
      description: 'Create your first habit',
    ),
    AchievementModel(
      id: 'first_check',
      emoji: '✅',
      title: 'Off to a Start',
      description: 'Complete a habit',
    ),
    AchievementModel(
      id: 'streak_3',
      emoji: '🔥',
      title: 'On a Roll',
      description: 'Reach a 3 day streak',
    ),
    AchievementModel(
      id: 'streak_7',
      emoji: '⚡',
      title: 'Week Warrior',
      description: 'Reach a 7 day streak',
    ),
    AchievementModel(
      id: 'streak_30',
      emoji: '👑',
      title: 'Habit Master',
      description: 'Reach a 30 day streak',
    ),
    AchievementModel(
      id: 'perfect_day',
      emoji: '🌟',
      title: 'Perfect Day',
      description: 'Complete all your habits in one day (2 habits or more)',
    ),
    AchievementModel(
      id: 'five_habits',
      emoji: '🗂️',
      title: 'Collector',
      description: 'Have 5 habits',
    ),
    AchievementModel(
      id: 'focus_done',
      emoji: '🎯',
      title: 'Laser Focus',
      description: "Complete today's focus",
    ),
    AchievementModel(
      id: 'first_task',
      emoji: '📝',
      title: 'Getting Things Done',
      description: 'Complete a task',
    ),
    AchievementModel(
      id: 'ten_tasks',
      emoji: '🏆',
      title: 'Task Slayer',
      description: 'Complete 10 tasks',
    ),
  ];

  // the unlocked achievements: id -> the day it was unlocked
  final unlocked = <String, String>{}.obs;

  // we only check the achievements after the saved ones are loaded,
  // otherwise we would unlock the same achievement twice
  bool _loaded = false;

  // the achievements that are being saved right now
  final _saving = <String>{};

  @override
  void onInit() {
    super.onInit();

    // ever() runs a function every time the value changes,
    // so the achievements are checked automatically
    ever(habitController.habits, (_) => check());
    ever(habitController.focusDone, (_) => check());
    ever(taskController.tasks, (_) => check());
  }

  void clearAchievements() {
    unlocked.clear();
    _loaded = false;
  }

  // the biggest streak of all the habits (used by the Profile screen too)
  int get bestStreak {
    var best = 0;

    for (final habit in habitController.habits) {
      if (habit.bestStreak > best) {
        best = habit.bestStreak;
      }
      if (habit.currentStreak > best) {
        best = habit.currentStreak;
      }
    }

    return best;
  }

  // how many times a habit was completed (all days, all habits)
  int get totalCompletions {
    var total = 0;

    for (final habit in habitController.habits) {
      total = total + habit.completedDates.length;
    }

    return total;
  }

  Future<void> getAchievements() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return;
      }

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('achievements')
          .get();

      final saved = <String, String>{};

      for (final doc in snapshot.docs) {
        saved[doc.id] = doc.data()['unlockedAt'] ?? '';
      }

      unlocked.value = saved;
      _loaded = true;

      check();
    } catch (e) {
      Get.snackbar('Error', 'Could not load achievements');
    }
  }

  // looks at the habits, the tasks and the focus and unlocks what is earned
  Future<void> check() async {
    if (!_loaded) {
      return;
    }

    final habits = habitController.habits;

    final earned = <String, bool>{
      'first_habit': habits.isNotEmpty,
      'first_check': totalCompletions > 0,
      'streak_3': bestStreak >= 3,
      'streak_7': bestStreak >= 7,
      'streak_30': bestStreak >= 30,
      'perfect_day':
          habits.length >= 2 && habitController.completedCount == habits.length,
      'five_habits': habits.length >= 5,
      'focus_done':
          habitController.focusText.value.isNotEmpty &&
          habitController.focusDone.value,
      'first_task': taskController.doneCount >= 1,
      'ten_tasks': taskController.doneCount >= 10,
    };

    final newOnes = <AchievementModel>[];

    for (final achievement in achievements) {
      final isEarned = earned[achievement.id] == true;

      // skip the achievements that are unlocked or being saved right now
      if (!isEarned ||
          unlocked.containsKey(achievement.id) ||
          _saving.contains(achievement.id)) {
        continue;
      }

      _saving.add(achievement.id);
      final saved = await _unlock(achievement.id);
      _saving.remove(achievement.id);

      if (saved) {
        newOnes.add(achievement);
      }
    }

    // tell the user (one message, even if two were unlocked together)
    if (newOnes.isNotEmpty) {
      final names = newOnes.map((a) => '${a.emoji} ${a.title}').join(', ');

      Get.snackbar('🏆 Achievement unlocked!', names);
    }
  }

  // saves the achievement, returns true if it worked
  Future<bool> _unlock(String id) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return false;
      }

      final today = todayDate();

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('achievements')
          .doc(id)
          .set({'unlockedAt': today});

      unlocked[id] = today;

      return true;
    } catch (e) {
      return false;
    }
  }
}
