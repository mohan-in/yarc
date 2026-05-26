import 'package:flutter/material.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/widgets/cached_image.dart';

/// A generic richtext/plain-text flair badge.
///
/// Renders either a [richtext] list of [FlairItem]s (emoji + text spans) or
/// a plain [text] string inside a rounded container.  Returns
/// [SizedBox.shrink] when both inputs are empty.
///
/// Extracted from `post_card.dart` so it can be reused and unit-tested
/// independently of `PostCard`.
class FlairLabel extends StatelessWidget {
  const FlairLabel({
    required this.text,
    required this.richtext,
    required this.backgroundColor,
    required this.textColor,
    required this.borderRadius,
    super.key,
  });

  final String? text;
  final List<FlairItem>? richtext;
  final Color backgroundColor;
  final Color textColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if ((text == null || text!.isEmpty) &&
        (richtext == null || richtext!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final textStyle = theme.textTheme.labelSmall?.copyWith(
      color: textColor,
      fontSize: 10,
    );

    final Widget content;
    if (richtext != null && richtext!.isNotEmpty) {
      content = RichText(
        text: TextSpan(
          children: richtext!.map((item) {
            if (item.isEmoji && item.emojiUrl != null) {
              return WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: CachedImage(
                    imageUrl: item.emojiUrl!,
                    height: 14,
                    width: 14,
                  ),
                ),
              );
            }
            return TextSpan(
              text: item.text ?? '',
              style: textStyle,
            );
          }).toList(),
        ),
      );
    } else {
      content = Text(text!, style: textStyle);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: content,
    );
  }
}
