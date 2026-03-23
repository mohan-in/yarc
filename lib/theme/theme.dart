import 'package:flutter/material.dart';

/// Light theme using standard Material 3.
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  textTheme: const TextTheme(
    titleMedium: TextStyle(fontSize: 17), // Default 16 + 1
    bodyMedium: TextStyle(fontSize: 15), // Default 14 + 1
  ),
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    scrolledUnderElevation: 4,
    backgroundColor: Color(0xFF1565C0),
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
  ),
  extensions: const [
    CommentTheme(
      depthColors: [
        Colors.red,
        Colors.orange,
        Colors.amber,
        Colors.green,
        Colors.blue,
        Colors.indigo,
        Colors.purple,
      ],
    ),
    MediaViewerTheme(
      overlayColor: Colors.black54, // Approx .withValues(alpha: 0.5/0.7)
      labelColor: Colors.white,
    ),
  ],
);

/// Dark theme using standard Material 3.
final ThemeData darkAppTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.dark,
  ),
  textTheme: const TextTheme(
    titleMedium: TextStyle(fontSize: 17), // Default 16 + 1
    bodyMedium: TextStyle(fontSize: 15), // Default 14 + 1
  ),
  appBarTheme: AppBarTheme(
    centerTitle: true,
    scrolledUnderElevation: 4,
    backgroundColor: Colors.grey[900], // Darker AppBar to distinguish from bg
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
  ),
  extensions: const [
    CommentTheme(
      depthColors: [
        Colors.redAccent,
        Colors.orangeAccent,
        Colors.amberAccent,
        Colors.greenAccent,
        Colors.blueAccent,
        Colors.indigoAccent,
        Colors.purpleAccent,
      ],
    ),
    MediaViewerTheme(
      overlayColor: Colors.black87,
      labelColor: Colors.white,
    ),
  ],
);

@immutable
class CommentTheme extends ThemeExtension<CommentTheme> {
  const CommentTheme({required this.depthColors});

  final List<Color> depthColors;

  @override
  CommentTheme copyWith({List<Color>? depthColors}) {
    return CommentTheme(
      depthColors: depthColors ?? this.depthColors,
    );
  }

  @override
  CommentTheme lerp(ThemeExtension<CommentTheme>? other, double t) {
    if (other is! CommentTheme) {
      return this;
    }
    if (other.depthColors.length != depthColors.length) {
      return this;
    }
    return CommentTheme(
      depthColors: List.generate(
        depthColors.length,
        (index) => Color.lerp(depthColors[index], other.depthColors[index], t)!,
      ),
    );
  }

  // Helper for lerpList since it works on raw lists but we need Color lerping
  static Color lerpColor(Color a, Color b, double t) => Color.lerp(a, b, t)!;
}

@immutable
class MediaViewerTheme extends ThemeExtension<MediaViewerTheme> {
  const MediaViewerTheme({
    required this.overlayColor,
    required this.labelColor,
  });

  final Color overlayColor;
  final Color labelColor;

  @override
  MediaViewerTheme copyWith({Color? overlayColor, Color? labelColor}) {
    return MediaViewerTheme(
      overlayColor: overlayColor ?? this.overlayColor,
      labelColor: labelColor ?? this.labelColor,
    );
  }

  @override
  MediaViewerTheme lerp(ThemeExtension<MediaViewerTheme>? other, double t) {
    if (other is! MediaViewerTheme) {
      return this;
    }
    return MediaViewerTheme(
      overlayColor: Color.lerp(overlayColor, other.overlayColor, t)!,
      labelColor: Color.lerp(labelColor, other.labelColor, t)!,
    );
  }
}
