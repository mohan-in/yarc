import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import 'package:yarc/utils/constants.dart';
import 'package:yarc/utils/image_utils.dart';
import 'package:yarc/widgets/faded_truncation.dart';
import 'package:yarc/widgets/full_screen_image_view.dart';

/// A widget that parses text (Markdown) and renders it with clickable links
/// and inline images.
class MarkdownContent extends StatelessWidget {
  const MarkdownContent({
    required this.text,
    super.key,
    this.style,
    this.maxLines,
    this.linkStyle,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextStyle? linkStyle;

  @override
  Widget build(BuildContext context) {
    final processedText = ImageUtils.convertBareUrlsToMarkdownImages(text);
    final theme = Theme.of(context);

    final markdownBody = MarkdownBody(
      data: processedText,
      extensionSet: md.ExtensionSet.gitHubFlavored, // Better link/table parsing
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: style ?? theme.textTheme.bodyMedium,
        a:
            linkStyle ??
            TextStyle(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border(
            left: BorderSide(color: theme.colorScheme.outline, width: 4),
          ),
        ),
        code: TextStyle(
          fontFamily:
              'RobotoMono', // Explicit mono font to fix rendering issues
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          color: theme.colorScheme.onSurface,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      onTapLink: (text, href, title) async {
        if (href != null) {
          final uri = Uri.parse(href);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }
      },
      builders: {'img': _TapToOpenImageBuilder(context, linkStyle, theme)},
    );

    if (maxLines != null) {
      return FadedTruncation(child: markdownBody);
    }

    return markdownBody;
  }
}

/// A helper builder to render images that open full-screen on tap.
class _TapToOpenImageBuilder extends MarkdownElementBuilder {
  _TapToOpenImageBuilder(this.context, this.linkStyle, this.theme);

  final BuildContext context;
  final TextStyle? linkStyle;
  final ThemeData theme;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final url = element.attributes['src'];
    if (url == null) {
      return null;
    }

    return GestureDetector(
      onTap: () {
        unawaited(
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (context) => FullScreenImageView(
                imageUrls: [url],
              ),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            ImageUtils.getCorsUrl(url),
            headers: kIsWeb ? null : const {'User-Agent': kUserAgent},
            height: 200,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to text link if image fails
              return Text(
                url,
                style:
                    linkStyle ??
                    TextStyle(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
              );
            },
          ),
        ),
      ),
    );
  }
}
