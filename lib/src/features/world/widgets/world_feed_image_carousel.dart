import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Swipeable image gallery for a single world-feed post (TikTok-style photo carousel).
class WorldFeedImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final String? placeholderUrl;

  const WorldFeedImageCarousel({
    super.key,
    required this.imageUrls,
    this.placeholderUrl,
  });

  @override
  State<WorldFeedImageCarousel> createState() => _WorldFeedImageCarouselState();
}

class _WorldFeedImageCarouselState extends State<WorldFeedImageCarousel> {
  late final PageController _pageController;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    if (urls.isEmpty) {
      return Container(color: Colors.black);
    }
    if (urls.length == 1) {
      return _buildPage(urls.first);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: urls.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => _buildPage(urls[i]),
        ),
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(urls.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 8 : 6,
                height: active ? 8 : 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? Colors.white : Colors.white38,
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 2),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildPage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      placeholder: (context, u) => widget.placeholderUrl != null
          ? CachedNetworkImage(imageUrl: widget.placeholderUrl!, fit: BoxFit.contain)
          : Container(color: Colors.black),
      errorWidget: (context, u, e) => Container(
        color: Colors.black,
        child: const Icon(Icons.error_outline, color: Colors.white38, size: 48),
      ),
    );
  }
}
