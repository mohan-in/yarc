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

  RedditorInfo copyWith({
    String? name,
    int? commentKarma,
    int? linkKarma,
    DateTime? createdUtc,
  }) {
    return RedditorInfo(
      name: name ?? this.name,
      commentKarma: commentKarma ?? this.commentKarma,
      linkKarma: linkKarma ?? this.linkKarma,
      createdUtc: createdUtc ?? this.createdUtc,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is RedditorInfo && other.name == name);

  @override
  int get hashCode => name.hashCode;
}
