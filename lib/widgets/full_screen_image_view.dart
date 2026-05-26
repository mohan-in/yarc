import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:yarc/utils/image_utils.dart';
import 'package:yarc/widgets/image_save_dialog.dart';

/// A full-screen image viewer that supports zooming and panning.
class FullScreenImageView extends StatefulWidget {
  const FullScreenImageView({
    required this.imageUrls,
    super.key,
    this.initialIndex = 0,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<FullScreenImageView> createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<FullScreenImageView> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  void _handleZoomChanged(bool isZoomed) {
    if (_isZoomed != isZoomed) {
      setState(() {
        _isZoomed = isZoomed;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => showImageSaveDialog(
              context,
              widget.imageUrls[_currentIndex],
            ),
            tooltip: 'Save Image',
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: _isZoomed
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return _ZoomableImagePage(
            imageUrl: widget.imageUrls[index],
            onZoomChanged: _handleZoomChanged,
          );
        },
      ),
    );
  }
}

class _ZoomableImagePage extends StatefulWidget {
  const _ZoomableImagePage({
    required this.imageUrl,
    required this.onZoomChanged,
  });

  final String imageUrl;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableImagePage> createState() => _ZoomableImagePageState();
}

class _ZoomableImagePageState extends State<_ZoomableImagePage>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
        )..addListener(() {
          if (_animation != null) {
            _transformationController.value = _animation!.value;
          }
        });
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    widget.onZoomChanged(scale > 1.0);
  }

  void _handleDoubleTap() {
    Matrix4 endMatrix;
    if (_transformationController.value.getMaxScaleOnAxis() > 1.0) {
      endMatrix = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      const zoomScale = 3;
      final dx = -position.dx * (zoomScale - 1);
      final dy = -position.dy * (zoomScale - 1);
      endMatrix = Matrix4.diagonal3Values(
        zoomScale.toDouble(),
        zoomScale.toDouble(),
        1,
      )..setTranslationRaw(dx, dy, 0);
    }

    _animation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: endMatrix,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    unawaited(_animationController.forward(from: 0));
  }

  @override
  void dispose() {
    _transformationController
      ..removeListener(_onTransformationChanged)
      ..dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.5,
        maxScale: 4,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: ImageUtils.getCorsUrl(widget.imageUrl),
            httpHeaders: ImageUtils.authHeaders,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Icon(Icons.error, color: Colors.white, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
