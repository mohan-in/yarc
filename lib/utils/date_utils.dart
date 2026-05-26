class DateUtilsHelper {
  static String formatTimeAgo(double createdUtc) {
    final now = DateTime.now().toUtc();
    final created = DateTime.fromMillisecondsSinceEpoch(
      (createdUtc * 1000).toInt(),
      isUtc: true,
    );
    final difference = now.difference(created);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }

  /// Formats [date] as `YYYY-MM-DD` (ISO 8601 date).
  ///
  /// Used for displaying a user's cake day.
  static String formatDate(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Returns a short human-readable age string (e.g. `2y old`, `4mo old`).
  ///
  /// Used for displaying how long a Reddit account has existed.
  static String formatAccountAge(DateTime created) {
    final age = DateTime.now().difference(created);
    if (age.inDays >= 365) {
      return '${age.inDays ~/ 365}y old';
    } else if (age.inDays >= 30) {
      return '${age.inDays ~/ 30}mo old';
    }
    return '${age.inDays}d old';
  }
}
