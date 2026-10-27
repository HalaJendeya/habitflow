class HabitModel {
  String id;
  String name;
  String description;
  bool isCompleted;
  int createdAt;
  int currentStreak;
  String? lastCompletedDate; // saved like '2026-10-07'
  int bestStreak;
  List<String> completedDates; // every day the habit was completed
  String timeOfDay; // Morning, Afternoon, Evening or Anytime
  String? reminderTime; // like '08:30', null means no reminder

  HabitModel({
    required this.id,
    required this.name,
    required this.description,
    this.isCompleted = false,
    this.createdAt = 0,
    this.currentStreak = 0,
    this.lastCompletedDate,
    this.bestStreak = 0,
    List<String>? completedDates,
    this.timeOfDay = 'Anytime',
    this.reminderTime,
  }) : completedDates = completedDates ?? [];

  factory HabitModel.fromMap(String id, Map<String, dynamic> map) {
    return HabitModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      createdAt: map['createdAt'] ?? 0,
      currentStreak: map['currentStreak'] ?? 0,
      lastCompletedDate: map['lastCompletedDate'],
      bestStreak: map['bestStreak'] ?? 0,
      completedDates: List<String>.from(map['completedDates'] ?? []),
      timeOfDay: map['timeOfDay'] ?? 'Anytime',
      reminderTime: map['reminderTime'],
    );
  }
}
