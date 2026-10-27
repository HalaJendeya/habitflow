import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/habit_controller.dart';
import '../controllers/notification_controller.dart';
import '../models/habit_model.dart';
import '../theme/app_colors.dart';

// This screen is used to add a new habit AND to edit an existing habit.
// If the Details screen sends a habit (Get.arguments), we are editing.
class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key});

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();

  final habitController = Get.find<HabitController>();

  // the habit we are editing, null means we are adding a new habit
  HabitModel? editingHabit;

  String timeOfDay = 'Anytime';

  // like '08:30', null means no reminder
  String? reminderTime;

  @override
  void initState() {
    super.initState();

    final arguments = Get.arguments;

    if (arguments is HabitModel) {
      editingHabit = arguments;

      // fill the fields with the current values
      nameController.text = arguments.name;
      descriptionController.text = arguments.description;
      timeOfDay = arguments.timeOfDay;
      reminderTime = arguments.reminderTime;
    }
  }

  // opens the clock to choose the time of the reminder
  Future<void> pickReminder() async {
    var startTime = const TimeOfDay(hour: 8, minute: 0);

    if (reminderTime != null) {
      final parts = reminderTime!.split(':');
      startTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: startTime,
    );

    if (picked == null) {
      return;
    }

    // Android 13 and newer asks the user: "Allow notifications?"
    await Get.find<NotificationController>().requestPermission();

    final hour = picked.hour.toString().padLeft(2, '0');
    final minute = picked.minute.toString().padLeft(2, '0');

    setState(() {
      reminderTime = '$hour:$minute';
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void saveHabit() {
    final name = nameController.text.trim();
    final description = descriptionController.text.trim();

    if (name.isEmpty) {
      Get.snackbar('Error', 'Please enter a habit name');
      return;
    }

    if (editingHabit == null) {
      habitController.addHabit(name, description, timeOfDay, reminderTime);
    } else {
      habitController.updateHabit(
        editingHabit!,
        name,
        description,
        timeOfDay,
        reminderTime,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = editingHabit != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Habit' : 'Add Habit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Habit Name',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'WHEN WILL YOU DO IT?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 8),

            // one chip for each part of the day
            Wrap(
              spacing: 8,
              children: habitController.timesOfDay.map((time) {
                return ChoiceChip(
                  label: Text(time),
                  selected: timeOfDay == time,
                  selectedColor: Colors.orange.shade200,
                  onSelected: (selected) {
                    setState(() {
                      timeOfDay = time;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            const Text(
              'REMINDER',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                  ),
                  onPressed: pickReminder,
                  icon: const Icon(Icons.alarm),
                  label: Text(
                    reminderTime == null
                        ? 'Remind me every day'
                        : 'Every day at $reminderTime',
                  ),
                ),

                // remove the reminder
                if (reminderTime != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        reminderTime = null;
                      });
                    },
                  ),
              ],
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: saveHabit,
                child: Text(isEditing ? 'Save Changes' : 'Add Habit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
