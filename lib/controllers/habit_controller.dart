import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../helpers/date_helper.dart';
import '../models/habit_model.dart';
import '../routes/app_routes.dart';
import 'notification_controller.dart';

class HabitController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final habits = <HabitModel>[].obs;
  final isLoading = false.obs;

  // today's focus text, empty means there is no focus for today
  final focusText = ''.obs;
  final focusDone = false.obs;

  // the parts of the day, in the order they appear on the Home screen
  final timesOfDay = ['Morning', 'Afternoon', 'Evening', 'Anytime'];

  // how many habits are completed (used by the Home screen)
  int get completedCount {
    return habits.where((habit) => habit.isCompleted).length;
  }

  void clearHabits() {
    habits.clear();
    focusText.value = '';
    focusDone.value = false;
  }

  // Daily Focus is saved in: users / {userId} / dailyFocus / current
  // (one fixed document called "current", because there is only one focus)
  Future<void> getFocus({bool refresh = false}) async {
    try {
      if (!refresh) {
        // remove old focus first so we never show another user's focus
        focusText.value = '';
        focusDone.value = false;
      }

      final user = _auth.currentUser;

      if (user == null) {
        return;
      }

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('dailyFocus')
          .doc('current')
          .get();

      final data = doc.data();

      // only show the focus if it was saved today
      if (data != null && data['date'] == todayDate()) {
        focusText.value = data['text'] ?? '';
        focusDone.value = data['done'] ?? false;
      } else {
        // no focus for today (this matters when the app was left open
        // past midnight and the user pulls to refresh)
        focusText.value = '';
        focusDone.value = false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Could not load focus');
    }
  }

  Future<void> saveFocus(String text) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        Get.snackbar('Error', 'No logged-in user');
        return;
      }

      // set() replaces the old focus, so there is always only one
      // (if there is no focus for today, focusDone is false)
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('dailyFocus')
          .doc('current')
          .set({'text': text, 'date': todayDate(), 'done': focusDone.value});

      focusText.value = text;

      // close the bottom sheet
      Get.back();
    } catch (e) {
      Get.snackbar('Error', 'Could not save focus');
    }
  }

  Future<void> toggleFocusDone() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return;
      }

      final done = !focusDone.value;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('dailyFocus')
          .doc('current')
          .update({'done': done});

      focusDone.value = done;
    } catch (e) {
      Get.snackbar('Error', 'Could not update focus');
    }
  }

  // refresh = true is used by pull-to-refresh: the list stays on the screen
  // while the new data is loading (no spinner)
  Future<void> getHabits({bool refresh = false}) async {
    try {
      if (!refresh) {
        isLoading.value = true;

        // remove old data first so we never show another user's habits
        habits.clear();
      }

      final user = _auth.currentUser;

      if (user == null) {
        return;
      }

      final snapshot = await _firestore
          .collection('habits')
          .where('userId', isEqualTo: user.uid)
          .get();

      final list = snapshot.docs.map((doc) {
        return HabitModel.fromMap(doc.id, doc.data());
      }).toList();

      // oldest habit first, so the Daily Flow keeps the same order
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // isCompleted must only mean "completed TODAY"
      final today = todayDate();
      final yesterday = yesterdayDate();

      for (final habit in list) {
        if (habit.lastCompletedDate != today) {
          // not completed today, so it is a new day for this habit
          habit.isCompleted = false;

          // if it was not completed yesterday either, the streak is broken
          // (if it was completed yesterday we keep the streak, so the user
          // can continue it today)
          if (habit.lastCompletedDate != yesterday) {
            habit.currentStreak = 0;
          }
        }
      }

      habits.value = list;

      // make sure every reminder is scheduled (for example after a reinstall)
      for (final habit in list) {
        await _scheduleReminder(habit);
      }
    } catch (e) {
      Get.snackbar('Error', 'Could not load habits');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addHabit(
    String name,
    String description,
    String timeOfDay,
    String? reminderTime,
  ) async {
    try {
      isLoading.value = true;

      final user = _auth.currentUser;

      if (user == null) {
        Get.snackbar('Error', 'No logged-in user');
        return;
      }

      // current time as a number (milliseconds), bigger number = newer habit
      final createdAt = DateTime.now().millisecondsSinceEpoch;

      final doc = await _firestore.collection('habits').add({
        'userId': user.uid,
        'name': name,
        'description': description,
        'isCompleted': false,
        'createdAt': createdAt,
        'currentStreak': 0,
        'lastCompletedDate': null,
        'bestStreak': 0,
        'completedDates': [],
        'timeOfDay': timeOfDay,
        'reminderTime': reminderTime,
      });

      final habit = HabitModel(
        id: doc.id,
        name: name,
        description: description,
        createdAt: createdAt,
        timeOfDay: timeOfDay,
        reminderTime: reminderTime,
      );

      habits.add(habit);

      await _scheduleReminder(habit);

      Get.back();

      Get.snackbar('Success', 'Habit added successfully');
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleHabit(HabitModel habit) async {
    try {
      final isCompleted = !habit.isCompleted;

      // what we will save in Firestore
      final data = <String, dynamic>{'isCompleted': isCompleted};

      var streak = habit.currentStreak;
      var bestStreak = habit.bestStreak;
      final today = todayDate();

      // only when completing: work out the new streak
      // (unchecking keeps the streak as it is)
      if (isCompleted) {
        // completed earlier today and unchecked? the streak was already counted
        if (habit.lastCompletedDate != today) {
          if (habit.lastCompletedDate == yesterdayDate()) {
            streak = streak + 1;
          } else {
            streak = 1; // first time, or we missed a day
          }
        }

        // remember the longest streak
        if (streak > bestStreak) {
          bestStreak = streak;
        }

        data['currentStreak'] = streak;
        data['bestStreak'] = bestStreak;
        data['lastCompletedDate'] = today;

        // arrayUnion adds today to the list (never twice)
        data['completedDates'] = FieldValue.arrayUnion([today]);
      } else {
        // unchecked: today does not count as completed any more
        data['completedDates'] = FieldValue.arrayRemove([today]);
      }

      await _firestore.collection('habits').doc(habit.id).update(data);

      // Firestore saved it, now update the habit shown on the screen
      habit.isCompleted = isCompleted;
      if (isCompleted) {
        habit.currentStreak = streak;
        habit.bestStreak = bestStreak;
        habit.lastCompletedDate = today;

        if (!habit.completedDates.contains(today)) {
          habit.completedDates.add(today);
        }
      } else {
        habit.completedDates.remove(today);
      }

      habits.refresh();

      // done today? then the reminder starts again tomorrow
      await _scheduleReminder(habit);
    } catch (e) {
      Get.snackbar('Error', 'Could not update habit');
    }
  }

  Future<void> updateHabit(
    HabitModel habit,
    String name,
    String description,
    String timeOfDay,
    String? reminderTime,
  ) async {
    try {
      await _firestore.collection('habits').doc(habit.id).update({
        'name': name,
        'description': description,
        'timeOfDay': timeOfDay,
        'reminderTime': reminderTime,
      });

      habit.name = name;
      habit.description = description;
      habit.timeOfDay = timeOfDay;
      habit.reminderTime = reminderTime;

      habits.refresh();

      await _scheduleReminder(habit);

      // go back to Home (the Details screen would still show the old text)
      Get.until((route) => route.settings.name == AppRoutes.home);

      Get.snackbar('Saved', 'Habit updated');
    } catch (e) {
      Get.snackbar('Error', 'Could not update habit');
    }
  }

  // (re)schedules the daily reminder of a habit
  // a failed reminder must never break adding or loading a habit
  Future<void> _scheduleReminder(HabitModel habit) async {
    try {
      await Get.find<NotificationController>().scheduleHabitReminder(habit);
    } catch (e) {
      // ignore
    }
  }

  Future<void> deleteHabit(String id) async {
    try {
      await _firestore.collection('habits').doc(id).delete();

      habits.removeWhere((habit) => habit.id == id);

      await Get.find<NotificationController>().cancelHabitReminder(id);

      // leave the Habit Details screen and go back to Home
      Get.back();

      Get.snackbar('Deleted', 'Habit deleted');
    } catch (e) {
      Get.snackbar('Error', 'Could not delete habit');
    }
  }
}
