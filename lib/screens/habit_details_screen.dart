import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/habit_controller.dart';
import '../helpers/date_helper.dart';
import '../models/habit_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

class HabitDetailsScreen extends StatelessWidget {
  const HabitDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final habitController = Get.find<HabitController>();

    // the Home screen sends the habit when it opens this screen
    final habit = Get.arguments as HabitModel;

    // the last 7 days: the oldest day first, today is the last one
    final now = DateTime.now();
    final weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final dayWidgets = <Widget>[];
    var doneCount = 0;

    for (var i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final done = habit.completedDates.contains(formatDate(day));

      if (done) {
        doneCount++;
      }

      dayWidgets.add(
        Column(
          children: [
            Text(
              weekdayLetters[day.weekday - 1],
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            CircleAvatar(
              radius: 16,
              backgroundColor: done ? AppColors.primary : Colors.grey.shade300,
              child: done
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
          ],
        ),
      );
    }

    // best streak is never smaller than the current streak
    final bestStreak = habit.bestStreak > habit.currentStreak
        ? habit.bestStreak
        : habit.currentStreak;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // the Add screen edits this habit when we send it
              Get.toNamed(AppRoutes.addHabit, arguments: habit);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      habit.description.isEmpty
                          ? 'No description'
                          : habit.description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          habit.timeOfDay,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),

                    if (habit.reminderTime != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_outlined,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Reminder at ${habit.reminderTime}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Icon(
                          habit.isCompleted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: habit.isCompleted
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          habit.isCompleted ? 'Completed' : 'Not completed',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Text(
                      habit.currentStreak > 0
                          ? '🔥 ${habit.currentStreak} day streak'
                          : 'No active streak',
                      style: const TextStyle(fontSize: 16),
                    ),

                    if (bestStreak > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '🏆 Best streak: $bestStreak ${bestStreak == 1 ? 'day' : 'days'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // the last 7 days
                    SizedBox(
                      width: double.infinity,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'LAST 7 DAYS',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: dayWidgets,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Completed $doneCount / 7 days',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) {
                      return AlertDialog(
                        title: const Text('Delete habit?'),
                        content: Text('"${habit.name}" will be deleted.'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Get.back(); // close the dialog
                            },
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Get.back(); // close the dialog
                              habitController.deleteHabit(habit.id);
                            },
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text('Delete Habit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
