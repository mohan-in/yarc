import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yarc/theme/theme.dart';
import 'package:yarc/utils/constants.dart';
import 'package:yarc/utils/image_utils.dart';
import 'package:yarc/widgets/full_screen_image_view.dart';

/// A horizontal carousel for displaying multiple images with swipe navigation.
class ImageCarousel extends StatefulWidget {
  const ImageCarousel({required this.imageUrls, super.key, this.aspectRatio});

  final List<String> imageUrls;
  final double? aspectRatio;

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.imageUrls.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                unawaited(
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => FullScreenImageView(
                        imageUrls: widget.imageUrls,
                        initialIndex: index,
                      ),
                    ),
                  ),
                );
              },
              child: CachedNetworkImage(
                imageUrl: ImageUtils.getCorsUrl(widget.imageUrls[index]),
                httpHeaders: ImageUtils.authHeaders,
                fit: BoxFit.contain, // Maintain aspect ratio within the box
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) =>
                    const Center(child: Icon(Icons.error)),
              ),
            );
          },
        ),
        if (widget.imageUrls.length > 1)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    Theme.of(
                      context,
                    ).extension<MediaViewerTheme>()?.overlayColor ??
                    Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentIndex + 1}/${widget.imageUrls.length}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color:
                      Theme.of(
                        context,
                      ).extension<MediaViewerTheme>()?.labelColor ??
                      Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        if (kIsWeb && widget.imageUrls.length > 1) ...[
          if (_currentIndex > 0)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: () {
                    unawaited(
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          if (_currentIndex < widget.imageUrls.length - 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: () {
                    unawaited(
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
        ],
      ],
    );

    if (widget.aspectRatio != null) {
      return AspectRatio(aspectRatio: widget.aspectRatio!, child: content);
    } else {
      return SizedBox(height: kCarouselFallbackHeight, child: content);
    }
  }
}
