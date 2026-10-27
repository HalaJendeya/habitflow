// One achievement the user can unlock (the list is in AchievementController).
class AchievementModel {
  final String id;
  final String emoji;
  final String title;
  final String description;

  const AchievementModel({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
  });
}
