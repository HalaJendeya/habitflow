import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/achievement_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/habit_controller.dart';
import '../controllers/notification_controller.dart';
import '../controllers/task_controller.dart';
import '../helpers/date_helper.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // a small card with a number and a name, like "5 Habits"
  Widget statCard(String value, String label) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final habitController = Get.find<HabitController>();
    final taskController = Get.find<TaskController>();
    final achievementController = Get.find<AchievementController>();
    final notificationController = Get.find<NotificationController>();

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final created = user?.metadata.creationTime;

    // the logout button: clear everything of this user, then sign out
    Future<void> logout() async {
      await notificationController.clearAll();

      habitController.clearHabits();
      taskController.clearTasks();
      achievementController.clearAchievements();

      authController.logout();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // the user
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      email.isEmpty ? '?' : email[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (created != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Member since ${formatDate(created)}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),

          sectionTitle('YOUR NUMBERS'),

          Obx(
            () => Column(
              children: [
                Row(
                  children: [
                    statCard('${habitController.habits.length}', 'Habits'),
                    statCard(
                      '🔥 ${achievementController.bestStreak}',
                      'Best streak',
                    ),
                  ],
                ),
                Row(
                  children: [
                    statCard(
                      '${achievementController.totalCompletions}',
                      'Completions',
                    ),
                    statCard('${taskController.doneCount}', 'Tasks done'),
                  ],
                ),
              ],
            ),
          ),

          // the achievements
          Obx(
            () => sectionTitle(
              'ACHIEVEMENTS  ${achievementController.unlocked.length} / ${achievementController.achievements.length}',
            ),
          ),

          Obx(
            () => Column(
              children: achievementController.achievements.map((achievement) {
                final unlockedDay =
                    achievementController.unlocked[achievement.id];
                final isUnlocked = unlockedDay != null;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isUnlocked
                          ? Colors.orange.shade100
                          : Colors.grey.shade200,
                      // a locked achievement is shown with a lock
                      child: Text(
                        isUnlocked ? achievement.emoji : '🔒',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    title: Text(
                      achievement.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isUnlocked
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    subtitle: Text(
                      isUnlocked
                          ? '${achievement.description}\nUnlocked $unlockedDay'
                          : achievement.description,
                    ),
                    isThreeLine: isUnlocked,
                    trailing: isUnlocked
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),

          // the notifications
          sectionTitle('NOTIFICATIONS'),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Obx(
                () => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          notificationController.notificationsAllowed.value
                              ? Icons.notifications_active
                              : Icons.notifications_off,
                          color:
                              notificationController.notificationsAllowed.value
                              ? AppColors.success
                              : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notificationController.notificationsAllowed.value
                                ? 'Notifications are on'
                                : 'Notifications are off',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (!notificationController.notificationsAllowed.value)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            notificationController.requestPermission();
                          },
                          child: const Text('Turn on notifications'),
                        ),
                      ),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          notificationController.showTestNotification();
                        },
                        child: const Text('Send a test notification'),
                      ),
                    ),

                    // the token is the address of this phone for push messages,
                    // it is used to send a test message from the Firebase console
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed:
                            notificationController.pushToken.value.isEmpty
                            ? null
                            : () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text:
                                        notificationController.pushToken.value,
                                  ),
                                );
                                Get.snackbar('Copied', 'Push token copied');
                              },
                        child: const Text('Copy push token'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              onPressed: logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }
}
