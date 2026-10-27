import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/achievement_controller.dart';
import '../controllers/habit_controller.dart';
import '../controllers/notification_controller.dart';
import '../controllers/task_controller.dart';
import '../controllers/tip_controller.dart';
import '../helpers/date_helper.dart';
import '../models/habit_model.dart';
import '../models/task_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final habitController = Get.find<HabitController>();
  final taskController = Get.find<TaskController>();
  final achievementController = Get.find<AchievementController>();
  final notificationController = Get.find<NotificationController>();
  final tipController = Get.find<TipController>();

  final focusTextController = TextEditingController();
  final taskTextController = TextEditingController();

  // the reminder time chosen in the "Add task" sheet (null = no reminder)
  final taskReminder = RxnString();

  @override
  void initState() {
    super.initState();

    // initState runs only once, when the screen is first created
    habitController.getHabits();
    habitController.getFocus();
    taskController.getTasks();
    achievementController.getAchievements();

    // asks for the notification permission and connects the push messages
    notificationController.startPush();
  }

  @override
  void dispose() {
    focusTextController.dispose();
    taskTextController.dispose();
    super.dispose();
  }

  void saveFocus() {
    final text = focusTextController.text.trim();

    if (text.isEmpty) {
      Get.snackbar('Error', 'Please enter a focus');
      return;
    }

    habitController.saveFocus(text);
  }

  // used for both "Add today's focus" and "Edit"
  void showFocusSheet() {
    // empty when there is no focus yet, the current focus when editing
    focusTextController.text = habitController.focusText.value;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          // the bottom padding keeps the sheet above the keyboard
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Today's Focus",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: focusTextController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'What do you want to focus on?',
                ),
              ),

              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: saveFocus,
                child: const Text('Save Focus'),
              ),
            ],
          ),
        );
      },
    );
  }

  String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good morning 👋';
    } else if (hour < 18) {
      return 'Good afternoon 👋';
    } else {
      return 'Good evening 👋';
    }
  }

  Future<void> refreshHome() async {
    await habitController.getHabits(refresh: true);
    await habitController.getFocus(refresh: true);
    await taskController.getTasks(refresh: true);
  }

  // ---------- tasks ----------

  void saveTask() {
    final title = taskTextController.text.trim();

    if (title.isEmpty) {
      Get.snackbar('Error', 'Please enter a task');
      return;
    }

    taskController.addTask(title, taskReminder.value);
  }

  // opens the clock to choose the time of the task reminder
  Future<void> pickTaskReminder() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked == null) {
      return;
    }

    // the reminder is for today, so the time must not be in the past
    final now = DateTime.now();
    final time = DateTime(
      now.year,
      now.month,
      now.day,
      picked.hour,
      picked.minute,
    );

    if (time.isBefore(now)) {
      Get.snackbar('Error', 'Choose a time in the future');
      return;
    }

    // Android 13 and newer asks the user: "Allow notifications?"
    await notificationController.requestPermission();

    final hour = picked.hour.toString().padLeft(2, '0');
    final minute = picked.minute.toString().padLeft(2, '0');

    taskReminder.value = '$hour:$minute';
  }

  void showTaskSheet() {
    taskTextController.clear();
    taskReminder.value = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Task',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: taskTextController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'What do you need to do today?',
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Obx(
                    () => OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryDark,
                      ),
                      onPressed: pickTaskReminder,
                      icon: const Icon(Icons.alarm),
                      label: Text(
                        taskReminder.value == null
                            ? 'Remind me today'
                            : 'Today at ${taskReminder.value}',
                      ),
                    ),
                  ),

                  // remove the reminder
                  Obx(
                    () => taskReminder.value == null
                        ? const SizedBox()
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              taskReminder.value = null;
                            },
                          ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: saveTask,
                child: const Text('Add Task'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildTaskRow(TaskModel task) {
    // a task of an earlier day that is still not done
    final isOverdue = task.date != todayDate() && !task.isDone;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 12, right: 4),
        leading: Checkbox(
          value: task.isDone,
          activeColor: AppColors.success,
          onChanged: (value) {
            taskController.toggleTask(task);
          },
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: task.isDone
                ? AppColors.textSecondary
                : AppColors.textPrimary,
            decoration: task.isDone
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
        ),
        subtitle: isOverdue
            ? const Text(
                'From an earlier day',
                style: TextStyle(color: AppColors.error),
              )
            : task.reminderTime == null
            ? null
            : Text('⏰ ${task.reminderTime}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () {
            taskController.deleteTask(task);
          },
        ),
      ),
    );
  }

  // the title of each part of the day
  final timeTitles = {
    'Morning': '🌅 MORNING',
    'Afternoon': '☀️ AFTERNOON',
    'Evening': '🌙 EVENING',
    'Anytime': '✨ ANYTIME',
  };

  // builds the Daily Flow: the habits grouped by the part of the day
  List<Widget> buildFlow() {
    final widgets = <Widget>[];

    // titles are only useful if at least one habit has a time
    final showTitles = habitController.habits.any(
      (habit) => habit.timeOfDay != 'Anytime',
    );

    // only the first unfinished habit of the day is "Up next"
    var upNextFound = false;

    for (final time in habitController.timesOfDay) {
      final habitsInTime = habitController.habits
          .where((habit) => habit.timeOfDay == time)
          .toList();

      if (habitsInTime.isEmpty) {
        continue;
      }

      if (showTitles) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 0, 4),
            child: Text(
              timeTitles[time] ?? time,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        );
      }

      for (final habit in habitsInTime) {
        // small text under the habit name
        var status = 'Keep going';
        if (habit.isCompleted) {
          status = 'Completed';
        } else if (!upNextFound) {
          status = 'Up next';
          upNextFound = true;
        }

        widgets.add(buildHabitCard(habit, status));
      }
    }

    return widgets;
  }

  Widget buildHabitCard(HabitModel habit, String status) {
    // streak text under the status
    var streakText = 'Start your streak';
    if (habit.currentStreak > 0) {
      streakText = '🔥 ${habit.currentStreak} day streak';
    }

    // the color of the status text
    var statusColor = AppColors.textSecondary;
    if (habit.isCompleted) {
      statusColor = AppColors.success;
    } else if (status == 'Up next') {
      statusColor = AppColors.primaryDark;
    }

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

        leading: Checkbox(
          value: habit.isCompleted,
          activeColor: AppColors.success,
          onChanged: (value) {
            habitController.toggleHabit(habit);
          },
        ),

        title: Text(
          habit.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: habit.isCompleted
                ? AppColors.textSecondary
                : AppColors.textPrimary,
            decoration: habit.isCompleted
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: status == 'Up next'
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            Text(
              streakText,
              style: TextStyle(
                color: habit.currentStreak > 0
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),

        trailing: const Icon(Icons.chevron_right),

        onTap: () {
          Get.toNamed(AppRoutes.habitDetails, arguments: habit);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HabitFlow'),
        actions: [
          // the Profile screen: achievements, notifications and logout
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Get.toNamed(AppRoutes.profile);
            },
          ),
        ],
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // everything scrolls together, only the Add Habit button stays
              // at the bottom. Pull down to reload the habits and the focus.
              Expanded(
                child: RefreshIndicator(
                  onRefresh: refreshHome,
                  child: ListView(
                    // so pulling down also works when the list is short
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Text(
                        getGreeting(),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // a tip or a motivational note, it changes by itself
                      // (tap it to see the next one)
                      Obx(
                        () => Card(
                          color: Colors.orange.shade50,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: tipController.nextTip,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                tipController.tip.value,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Daily Focus card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "🎯 TODAY'S FOCUS",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: AppColors.primaryDark,
                                ),
                              ),

                              const SizedBox(height: 12),

                              Obx(() {
                                // no focus for today yet
                                if (habitController.focusText.value.isEmpty) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'What do you want to focus on today?',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                AppColors.primaryDark,
                                          ),
                                          onPressed: showFocusSheet,
                                          icon: const Icon(Icons.add),
                                          label: const Text(
                                            "Add today's focus",
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                // today's focus exists
                                final done = habitController.focusDone.value;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: done,
                                          activeColor: AppColors.success,
                                          onChanged: (value) {
                                            habitController.toggleFocusDone();
                                          },
                                        ),
                                        Expanded(
                                          child: Text(
                                            habitController.focusText.value,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: done
                                                  ? AppColors.textSecondary
                                                  : AppColors.textPrimary,
                                              decoration: done
                                                  ? TextDecoration.lineThrough
                                                  : TextDecoration.none,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              AppColors.primaryDark,
                                        ),
                                        onPressed: showFocusSheet,
                                        icon: const Icon(Icons.edit, size: 18),
                                        label: const Text('Edit'),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // progress card: "1 / 3 completed" + progress bar
                      Obx(() {
                        final total = habitController.habits.length;
                        final completed = habitController.completedCount;
                        final progress = total == 0 ? 0.0 : completed / total;

                        // every habit of the day is done
                        final allDone = total > 0 && completed == total;

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  allDone
                                      ? '🎉 Daily Flow complete! ($completed / $total)'
                                      : '$completed / $total completed',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 10,
                                  borderRadius: BorderRadius.circular(8),
                                  color: AppColors.primary,
                                  backgroundColor: Colors.orange.shade100,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 24),

                      const Text(
                        'YOUR DAILY FLOW',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // the habits of the day
                      Obx(() {
                        if (habitController.isLoading.value) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 48),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (habitController.habits.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.wb_sunny_outlined,
                                    size: 48,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No habits yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Add your first habit to start your day',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: buildFlow(),
                        );
                      }),

                      // the tasks (one-time to-dos, not habits)
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '📝 TASKS',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryDark,
                            ),
                            onPressed: showTaskSheet,
                            icon: const Icon(Icons.add),
                            label: const Text('Add task'),
                          ),
                        ],
                      ),

                      Obx(() {
                        final list = taskController.visibleTasks;

                        if (list.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No tasks for today',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: list
                              .map((task) => buildTaskRow(task))
                              .toList(),
                        );
                      }),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              ElevatedButton.icon(
                onPressed: () {
                  Get.toNamed(AppRoutes.addHabit);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Habit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
