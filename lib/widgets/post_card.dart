import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../utils/image_utils.dart';
import '../utils/html_utils.dart';
import '../utils/date_utils.dart';
import 'full_screen_image_view.dart';
import 'markdown_content.dart';

/// A card widget that displays a summary of a [Post].
///
/// Shows title, author, subreddit, content preview, and images/thumbnails.
/// Supports tapping to view details via [onTap].
class PostCard extends StatefulWidget {
  /// The post data to display.
  final Post post;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  final bool expanded;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.expanded = false,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'r/${widget.post.subreddit}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    ' • u/${widget.post.author}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                HtmlUtils.unescape(widget.post.title),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (widget.post.content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: MarkdownContent(
                    text: HtmlUtils.unescape(widget.post.content),
                    maxLines: widget.expanded ? null : 3,
                    overflow: widget.expanded ? null : TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              const SizedBox(height: 8),
              if (widget.post.images.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: widget.post.images.length == 1
                      ? GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullScreenImageView(
                                  imageUrls: widget.post.images,
                                ),
                              ),
                            );
                          },
                          child: Image.network(
                            ImageUtils.getCorsUrl(widget.post.images.first),
                            headers: kIsWeb
                                ? null
                                : const {
                                    'User-Agent':
                                        'flutter_reddit_demo/1.0.0 (by /u/antigravity)',
                                  },
                            width: double.infinity,
                            fit: BoxFit.fitWidth,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return SizedBox(
                                height: 300, // Placeholder height while loading
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(
                                  height: 200,
                                  child: Center(child: Icon(Icons.error)),
                                ),
                          ),
                        )
                      : SizedBox(
                          height: 400, // Fixed height for carousel
                          child: Stack(
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                itemCount: widget.post.images.length,
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentIndex = index;
                                  });
                                },
                                itemBuilder: (context, index) {
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              FullScreenImageView(
                                                imageUrls: widget.post.images,
                                                initialIndex: index,
                                              ),
                                        ),
                                      );
                                    },
                                    child: Image.network(
                                      ImageUtils.getCorsUrl(
                                        widget.post.images[index],
                                      ),
                                      headers: kIsWeb
                                          ? null
                                          : const {
                                              'User-Agent':
                                                  'flutter_reddit_demo/1.0.0 (by /u/antigravity)',
                                            },
                                      fit: BoxFit.contain,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                            if (loadingProgress == null) {
                                              return child;
                                            }
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value:
                                                    loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                              .cumulativeBytesLoaded /
                                                          loadingProgress
                                                              .expectedTotalBytes!
                                                    : null,
                                              ),
                                            );
                                          },
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Center(
                                                child: Icon(Icons.error),
                                              ),
                                    ),
                                  );
                                },
                              ),
                              if (widget.post.images.length > 1)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.7,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_currentIndex + 1}/${widget.post.images.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              if (kIsWeb && widget.post.images.length > 1) ...[
                                if (_currentIndex > 0)
                                  Positioned(
                                    left: 8,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: IconButton(
                                        onPressed: () {
                                          _pageController.previousPage(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            curve: Curves.easeInOut,
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.arrow_back_ios,
                                          color: Colors.white,
                                        ),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.black
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_currentIndex <
                                    widget.post.images.length - 1)
                                  Positioned(
                                    right: 8,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: IconButton(
                                        onPressed: () {
                                          _pageController.nextPage(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            curve: Curves.easeInOut,
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.arrow_forward_ios,
                                          color: Colors.white,
                                        ),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.black
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                )
              else if (widget.post.thumbnail != null)
                // Fallback for thumbnail if no main images
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImageView(
                            imageUrls: [widget.post.thumbnail!],
                          ),
                        ),
                      );
                    },
                    child: Image.network(
                      ImageUtils.getCorsUrl(widget.post.thumbnail!),
                      headers: kIsWeb
                          ? null
                          : const {
                              'User-Agent':
                                  'flutter_reddit_demo/1.0.0 (by /u/antigravity)',
                            },
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateUtilsHelper.formatTimeAgo(widget.post.createdUtc),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 20),
                        onPressed: () => _launchURL(widget.post.permalink),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Open on Reddit',
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.mode_comment_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text('${widget.post.numComments}'),
                      const SizedBox(width: 16),
                      const Icon(Icons.arrow_upward, size: 16),
                      const SizedBox(width: 4),
                      Text('${widget.post.ups}'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchURL(String permalink) async {
    final Uri url = Uri.parse('https://www.reddit.com$permalink');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }
}
