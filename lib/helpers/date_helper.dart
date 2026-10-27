// Small date functions used by the habits, the tasks and the reminders.
// Dates are saved as text like '2026-10-07' (yyyy-MM-dd).

String formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');

  return '${date.year}-$month-$day';
}

String todayDate() {
  return formatDate(DateTime.now());
}

String yesterdayDate() {
  final now = DateTime.now();

  return formatDate(DateTime(now.year, now.month, now.day - 1));
}
