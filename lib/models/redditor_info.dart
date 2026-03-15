import 'package:flutter/foundation.dart';

/// Lightweight model for user search results.
@immutable
class RedditorInfo {
  const RedditorInfo({
    required this.name,
    required this.commentKarma,
    required this.linkKarma,
    this.createdUtc,
  });

  final String name;
  final int commentKarma;
  final int linkKarma;
  final DateTime? createdUtc;

  /// Total karma (comment + link).
  int get totalKarma => commentKarma + linkKarma;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RedditorInfo && other.name == name);

  @override
  int get hashCode => name.hashCode;
}
