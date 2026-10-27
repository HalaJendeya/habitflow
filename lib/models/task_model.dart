// A task is a one-time to-do for a day (a habit repeats, a task does not).
class TaskModel {
  String id;
  String title;
  String date; // the day of the task, like '2026-10-07'
  bool isDone;
  int createdAt;
  String? reminderTime; // like '15:30', null means no reminder

  TaskModel({
    required this.id,
    required this.title,
    required this.date,
    this.isDone = false,
    this.createdAt = 0,
    this.reminderTime,
  });

  factory TaskModel.fromMap(String id, Map<String, dynamic> map) {
    return TaskModel(
      id: id,
      title: map['title'] ?? '',
      date: map['date'] ?? '',
      isDone: map['isDone'] ?? false,
      createdAt: map['createdAt'] ?? 0,
      reminderTime: map['reminderTime'],
    );
  }
}
