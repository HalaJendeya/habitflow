import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../helpers/date_helper.dart';
import '../models/task_model.dart';
import 'notification_controller.dart';

// Tasks are one-time to-dos. They are separate from the habits.
// Saved in: users / {userId} / tasks / {taskId}
class TaskController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final tasks = <TaskModel>[].obs;

  // the tasks shown on the Home screen: today's tasks and the tasks of
  // earlier days that are not done yet
  List<TaskModel> get visibleTasks {
    final today = todayDate();

    return tasks.where((task) {
      // '2026-10-07' texts can be compared with < because the year comes first
      return task.date == today ||
          (!task.isDone && task.date.compareTo(today) < 0);
    }).toList();
  }

  // how many tasks are done (used by the achievements)
  int get doneCount {
    return tasks.where((task) => task.isDone).length;
  }

  void clearTasks() {
    tasks.clear();
  }

  CollectionReference<Map<String, dynamic>> _tasksOf(String userId) {
    return _firestore.collection('users').doc(userId).collection('tasks');
  }

  Future<void> getTasks({bool refresh = false}) async {
    try {
      if (!refresh) {
        // remove old data first so we never show another user's tasks
        tasks.clear();
      }

      final user = _auth.currentUser;

      if (user == null) {
        return;
      }

      final snapshot = await _tasksOf(user.uid).get();

      final list = snapshot.docs.map((doc) {
        return TaskModel.fromMap(doc.id, doc.data());
      }).toList();

      // oldest task first
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      tasks.value = list;

      // make sure the reminders of the tasks are scheduled
      final notifications = Get.find<NotificationController>();

      for (final task in list) {
        await notifications.scheduleTaskReminder(task);
      }
    } catch (e) {
      Get.snackbar('Error', 'Could not load tasks');
    }
  }

  Future<void> addTask(String title, String? reminderTime) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        Get.snackbar('Error', 'No logged-in user');
        return;
      }

      final createdAt = DateTime.now().millisecondsSinceEpoch;
      final date = todayDate();

      final doc = await _tasksOf(user.uid).add({
        'title': title,
        'date': date,
        'isDone': false,
        'createdAt': createdAt,
        'reminderTime': reminderTime,
      });

      final task = TaskModel(
        id: doc.id,
        title: title,
        date: date,
        createdAt: createdAt,
        reminderTime: reminderTime,
      );

      tasks.add(task);

      // close the bottom sheet
      Get.back();

      await Get.find<NotificationController>().scheduleTaskReminder(task);
    } catch (e) {
      Get.snackbar('Error', 'Could not add the task');
    }
  }

  Future<void> toggleTask(TaskModel task) async {
    try {
      final isDone = !task.isDone;

      await _tasksOf(
        _auth.currentUser!.uid,
      ).doc(task.id).update({'isDone': isDone});

      task.isDone = isDone;
      tasks.refresh();

      // a done task needs no reminder, an undone task needs it again
      await Get.find<NotificationController>().scheduleTaskReminder(task);
    } catch (e) {
      Get.snackbar('Error', 'Could not update the task');
    }
  }

  Future<void> deleteTask(TaskModel task) async {
    try {
      await _tasksOf(_auth.currentUser!.uid).doc(task.id).delete();

      tasks.removeWhere((item) => item.id == task.id);

      await Get.find<NotificationController>().cancelTaskReminder(task.id);
    } catch (e) {
      Get.snackbar('Error', 'Could not delete the task');
    }
  }
}
