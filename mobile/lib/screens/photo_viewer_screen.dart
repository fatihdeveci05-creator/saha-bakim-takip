import 'package:flutter/material.dart';

/// Tam ekran fotoğraf görüntüleyici — pinch/scroll ile yakınlaştırma,
/// sürükleyerek gezinme (InteractiveViewer) ve birden fazla fotoğraf
/// arasında kaydırarak geçiş (PageView) destekler.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({super.key, required this.imageUrls, this.initialIndex = 0});

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
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
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.imageUrls.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, i) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 6,
            child: Center(
              child: Image.network(
                widget.imageUrls[i],
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          );
        },
      ),
    );
  }
}
