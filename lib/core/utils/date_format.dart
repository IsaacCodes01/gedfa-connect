const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDateTime(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'am' : 'pm';
  return '${local.day} ${_months[local.month - 1]} ${local.year}, '
      '$hour:$minute $period';
}

const _weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  'Sunday',
];
const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December',
];

/// "Saturday, 7 November 2026" (the FA dashboard header)
String formatLongDate(DateTime date) {
  final local = date.toLocal();
  return '${_weekdayNames[local.weekday - 1]}, ${local.day} '
      '${_monthNames[local.month - 1]} ${local.year}';
}

String formatDate(DateTime date) =>
  '${date.day} ${_months[date.month - 1]} ${date.year}';

/// "5 Nov" (this year's dates in lists and notes)
String formatDayMonth(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_months[local.month - 1]}';
}

/// "5 Nov, 4:12 pm"
String formatDayMonthTime(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'am' : 'pm';
  return '${formatDayMonth(local)}, $hour:$minute $period';
}
