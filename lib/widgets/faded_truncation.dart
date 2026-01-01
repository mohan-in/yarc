import 'package:flutter/material.dart';

/// A widget that constrains its child's height and applies a fade-out gradient
/// at the bottom to indicate truncation.
class FadedTruncation extends StatelessWidget {
  final Widget child;
  final double maxHeight;

  const FadedTruncation({
    super.key,
    required this.child,
    this.maxHeight = 120.0,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: const [0.0, 0.8, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: child,
        ),
      ),
    );
  }
}
