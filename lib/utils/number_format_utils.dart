/// Shared formatting utilities for large numbers (subscribers, karma, etc.).
class NumberFormatUtils {
  /// Formats a large number into a compact human-readable string.
  ///
  /// Examples: `1234567` → `"1.2M members"`, `5600` → `"5.6K karma"`.
  static String formatCompact(int count, {String suffix = ''}) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M$suffix';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K$suffix';
    }
    return '$count$suffix';
  }
}
