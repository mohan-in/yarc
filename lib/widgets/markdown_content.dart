import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/utils/image_utils.dart';
import 'package:yarc/widgets/faded_truncation.dart';
import 'package:yarc/widgets/full_screen_image_view.dart';

/// A widget that parses text (Markdown) and renders it with clickable links
/// and inline images.
///
/// Uses a [StatefulWidget] to memoise the pre-processed text so that
/// [ImageUtils.convertBareUrlsToMarkdownImages] and the full Markdown parse
/// are not re-run on every parent rebuild — only when [text] actually changes.
class MarkdownContent extends StatefulWidget {
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
  State<MarkdownContent> createState() => _MarkdownContentState();
}

class _MarkdownContentState extends State<MarkdownContent> {
  late String _processedText;

  @override
  void initState() {
    super.initState();
    _processedText = ImageUtils.convertBareUrlsToMarkdownImages(widget.text);
  }

  @override
  void didUpdateWidget(MarkdownContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _processedText = ImageUtils.convertBareUrlsToMarkdownImages(widget.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final markdownBody = MarkdownBody(
      data: _processedText,
      extensionSet: md.ExtensionSet.gitHubFlavored, // Better link/table parsing
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: widget.style ?? theme.textTheme.bodyMedium,
        a:
            widget.linkStyle ??
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
          final useSystemBrowser = context
              .read<SettingsNotifier>()
              .useSystemBrowser;
          if (await canLaunchUrl(uri)) {
            await launchUrl(
              uri,
              mode: useSystemBrowser
                  ? LaunchMode.externalApplication
                  : LaunchMode.platformDefault,
            );
          }
        }
      },
      builders: {
        'img': _TapToOpenImageBuilder(context, widget.linkStyle, theme),
      },
    );

    if (widget.maxLines != null) {
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
          child: CachedNetworkImage(
            imageUrl: ImageUtils.getCorsUrl(url),
            httpHeaders: ImageUtils.authHeaders,
            height: 200,
            fit: BoxFit.contain,
            errorWidget: (context, url, error) {
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
