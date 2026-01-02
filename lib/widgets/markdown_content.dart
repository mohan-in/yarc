import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import '../utils/image_utils.dart';
import 'faded_truncation.dart';
import 'full_screen_image_view.dart';

/// A widget that parses text (Markdown) and renders it with clickable links
/// and inline images.
class MarkdownContent extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextStyle? linkStyle;

  const MarkdownContent({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.linkStyle,
    // [overflow] is intentionally removed as FadedTruncation handles it visually.
    TextOverflow? overflow,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Convert bare URLs to markdown image syntax so they render as images
    final processedText = ImageUtils.convertBareUrlsToMarkdownImages(text);
    final theme = Theme.of(context);

    // 2. Configure the Markdown renderer
    final markdownBody = MarkdownBody(
      data: processedText,
      selectable:
          false, // Keeping false for now to avoid Impeller glyph bounds bug
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
          final Uri uri = Uri.parse(href);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }
      },
      // 3. Custom Image Builder to handle tapped images (full screen) and CORS proxies
      builders: {'img': _TapToOpenImageBuilder(context, linkStyle, theme)},
    );

    // 4. If maxLines is set (e.g. in Feed), wrap in truncation widget
    if (maxLines != null) {
      return FadedTruncation(
        maxHeight: 120.0, // Fixed height for consistency in feed
        child: markdownBody,
      );
    }

    return markdownBody;
  }
}

/// A helper builder to render images that open full-screen on tap.
class _TapToOpenImageBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final TextStyle? linkStyle;
  final ThemeData theme;

  _TapToOpenImageBuilder(this.context, this.linkStyle, this.theme);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final url = element.attributes['src'];
    if (url == null) return null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenImageView(imageUrls: [url]),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.network(
            ImageUtils.getCorsUrl(url),
            headers: kIsWeb
                ? null
                : const {
                    'User-Agent': 'flutter_reddit/1.0.0', // Basic User-Agent
                  },
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
