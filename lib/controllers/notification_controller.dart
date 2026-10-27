import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/habit_model.dart';
import '../models/task_model.dart';

// Everything about notifications is here:
// 1. reminders for habits and tasks (local notifications, no internet needed)
// 2. push notifications from Firebase (FCM)
class NotificationController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // can the app show notifications? (the user can refuse in the Android dialog)
  final notificationsAllowed = false.obs;

  // the address of this phone for push notifications
  final pushToken = ''.obs;

  bool _pushStarted = false;

  // how the notifications look (the channel is the group name in Android settings)
  final NotificationDetails _details = const NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Reminders for your habits and tasks',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  // called once in main() before the app starts
  Future<void> init() async {
    // reminders need the time zone of the phone to fire at the right hour
    tz_data.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_habitflow'),
      ),
    );

    await checkPermission();
  }

  AndroidFlutterLocalNotificationsPlugin? get _android {
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  Future<void> checkPermission() async {
    notificationsAllowed.value =
        await _android?.areNotificationsEnabled() ?? false;
  }

  // shows the Android "Allow notifications?" dialog
  Future<bool> requestPermission() async {
    final allowed = await _android?.requestNotificationsPermission() ?? false;
    notificationsAllowed.value = allowed;

    return allowed;
  }

  // every notification needs a number, we make it from the text of the id
  // (the same text always gives the same number, so we can cancel it later)
  int _notificationId(String text) {
    var number = 0;

    for (final letter in text.codeUnits) {
      number = (number * 31 + letter) & 0x7fffffff;
    }

    return number;
  }

  // 'HH:mm' -> the hour and the minute
  List<int> _splitTime(String time) {
    final parts = time.split(':');

    return [int.parse(parts[0]), int.parse(parts[1])];
  }

  // ---------- habit reminders (every day) ----------

  Future<void> scheduleHabitReminder(HabitModel habit) async {
    final id = _notificationId(habit.id);

    // remove the old reminder first (the time may have changed)
    await _plugin.cancel(id: id);

    if (habit.reminderTime == null) {
      return;
    }

    final time = _splitTime(habit.reminderTime!);
    final now = tz.TZDateTime.now(tz.local);

    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time[0],
      time[1],
    );

    // start tomorrow if the time already passed or the habit is already done
    if (when.isBefore(now) || habit.isCompleted) {
      when = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        time[0],
        time[1],
      );
    }

    await _plugin.zonedSchedule(
      id: id,
      title: '⏰ ${habit.name}',
      body: 'Time for your habit. Keep your streak going!',
      scheduledDate: when,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // repeat every day at the same time
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelHabitReminder(String habitId) async {
    await _plugin.cancel(id: _notificationId(habitId));
  }

  // used when the habits are loaded: makes sure every reminder is scheduled
  Future<void> scheduleAllHabitReminders(List<HabitModel> habits) async {
    for (final habit in habits) {
      await scheduleHabitReminder(habit);
    }
  }

  // ---------- task reminders (one time) ----------

  Future<void> scheduleTaskReminder(TaskModel task) async {
    final id = _notificationId('task_${task.id}');

    await _plugin.cancel(id: id);

    // nothing to remind if there is no time or the task is already done
    if (task.reminderTime == null || task.isDone) {
      return;
    }

    final date = task.date.split('-');
    final time = _splitTime(task.reminderTime!);

    final when = tz.TZDateTime(
      tz.local,
      int.parse(date[0]),
      int.parse(date[1]),
      int.parse(date[2]),
      time[0],
      time[1],
    );

    // a reminder in the past makes no sense
    if (when.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    await _plugin.zonedSchedule(
      id: id,
      title: '📝 ${task.title}',
      body: 'You have a task to do.',
      scheduledDate: when,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelTaskReminder(String taskId) async {
    await _plugin.cancel(id: _notificationId('task_$taskId'));
  }

  // shows a notification right now (the Profile screen has a button for it)
  Future<void> showTestNotification() async {
    await _plugin.show(
      id: 1,
      title: '🔔 HabitFlow',
      body: 'Notifications are working!',
      notificationDetails: _details,
    );
  }

  // ---------- push notifications (Firebase Cloud Messaging) ----------

  // called when the Home screen opens (after login)
  Future<void> startPush() async {
    try {
      // this also shows the Android "Allow notifications?" dialog
      await _messaging.requestPermission();
      await checkPermission();

      final token = await _messaging.getToken();

      if (token != null) {
        pushToken.value = token;
        await _saveToken(token);
      }

      // the listeners are added only once
      if (_pushStarted) {
        return;
      }

      _pushStarted = true;

      // Firebase can change the token, so we save the new one
      _messaging.onTokenRefresh.listen((newToken) {
        pushToken.value = newToken;
        _saveToken(newToken);
      });

      // a push arrives while the app is open: show it inside the app
      // (when the app is closed, Android shows the notification by itself)
      FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;

        if (notification != null) {
          Get.snackbar(
            notification.title ?? 'HabitFlow',
            notification.body ?? '',
          );
        }
      });
    } catch (e) {
      Get.snackbar('Error', 'Could not start push notifications');
    }
  }

  // saved in: users / {userId}  (field fcmToken)
  Future<void> _saveToken(String token) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return;
      }

      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    } catch (e) {
      // the push messages still work in the app if the token is not saved
    }
  }

  // called when the user logs out: no more reminders or pushes for this phone
  Future<void> clearAll() async {
    try {
      await _plugin.cancelAll();

      final user = _auth.currentUser;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': FieldValue.delete(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      // logging out must work even if this fails
    }

    pushToken.value = '';
  }
}
