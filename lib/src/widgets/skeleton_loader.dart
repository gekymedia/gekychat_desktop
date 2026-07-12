import 'package:flutter/material.dart';

/// Skeleton loader with shimmer effect for loading states
/// Provides a better UX than plain CircularProgressIndicator
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.baseColor ??
        (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0));
    final highlightColor = widget.highlightColor ??
        (isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5));

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                _animation.value - 0.5,
                _animation.value,
                _animation.value + 0.5,
              ].map((e) => e.clamp(0.0, 1.0)).toList(),
            ),
          ),
        );
      },
    );
  }
}

/// Circular skeleton loader (for avatars)
class SkeletonCircle extends StatelessWidget {
  final double size;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonCircle({
    super.key,
    required this.size,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
      baseColor: baseColor,
      highlightColor: highlightColor,
    );
  }
}

/// Skeleton for a conversation list item (WhatsApp/Telegram style)
class SkeletonConversationItem extends StatelessWidget {
  const SkeletonConversationItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          // Avatar
          const SkeletonCircle(size: 50),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                SkeletonLoader(
                  width: double.infinity,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                // Last message
                SkeletonLoader(
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Timestamp
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonLoader(
                width: 40,
                height: 12,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              // Unread badge
              const SkeletonCircle(size: 20),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a message bubble
class SkeletonMessageBubble extends StatelessWidget {
  final bool isMe;

  const SkeletonMessageBubble({
    super.key,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * (isMe ? 0.5 : 0.6);
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Show sender info for received messages
            if (!isMe)
              Row(
                children: [
                  const SkeletonCircle(size: 24),
                  const SizedBox(width: 6),
                  SkeletonLoader(
                    width: 80,
                    height: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            if (!isMe) const SizedBox(height: 4),
            // Message bubble
            SkeletonLoader(
              width: width,
              height: 60,
              borderRadius: BorderRadius.circular(12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for contact list item
class SkeletonContactItem extends StatelessWidget {
  const SkeletonContactItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Avatar
          const SkeletonCircle(size: 48),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                SkeletonLoader(
                  width: double.infinity,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                // Phone/Email
                SkeletonLoader(
                  width: MediaQuery.of(context).size.width * 0.4,
                  height: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for status/story item
class SkeletonStatusItem extends StatelessWidget {
  const SkeletonStatusItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          // Story ring
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 2,
                  ),
                ),
              ),
              const SkeletonCircle(size: 56),
            ],
          ),
          const SizedBox(height: 6),
          // Name
          SkeletonLoader(
            width: 60,
            height: 12,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

/// Skeleton list - shows multiple skeleton items
class SkeletonList extends StatelessWidget {
  final Widget skeletonItem;
  final int itemCount;
  final EdgeInsets? padding;

  const SkeletonList({
    super.key,
    required this.skeletonItem,
    this.itemCount = 5,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) => skeletonItem,
    );
  }
}

/// Grid skeleton for status/stories
class SkeletonGrid extends StatelessWidget {
  final Widget skeletonItem;
  final int itemCount;
  final int crossAxisCount;

  const SkeletonGrid({
    super.key,
    required this.skeletonItem,
    this.itemCount = 8,
    this.crossAxisCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.8,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => skeletonItem,
    );
  }
}
