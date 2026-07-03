import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// TikTok-style video progress bar with drag control.
class VideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  final Color activeColor;
  final Color inactiveColor;
  final double height;

  const VideoProgressBar({
    super.key,
    required this.controller,
    this.activeColor = Colors.white,
    this.inactiveColor = Colors.white24,
    this.height = 3.0,
  });

  @override
  State<VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<VideoProgressBar> {
  bool _isDragging = false;
  double? _dragValue;
  bool _wasPlaying = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        if (!value.isInitialized || value.duration == Duration.zero) {
          return const SizedBox.shrink();
        }

        final duration = value.duration.inMilliseconds.toDouble();
        if (duration <= 0) {
          return const SizedBox.shrink();
        }

        final position = _isDragging && _dragValue != null
            ? _dragValue!
            : value.position.inMilliseconds.toDouble();

        return GestureDetector(
          onHorizontalDragStart: (details) {
            _wasPlaying = value.isPlaying;
            if (_wasPlaying) {
              widget.controller.pause();
            }
            setState(() {
              _isDragging = true;
              _dragValue = position;
            });
          },
          onHorizontalDragUpdate: (details) {
            if (!_isDragging) return;

            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;

            final localPosition = box.globalToLocal(details.globalPosition);
            final progress =
                (localPosition.dx / box.size.width).clamp(0.0, 1.0);
            final newPosition = duration * progress;

            setState(() {
              _dragValue = newPosition;
            });

            widget.controller.seekTo(
              Duration(milliseconds: newPosition.toInt()),
            );
          },
          onHorizontalDragEnd: (details) {
            if (_dragValue != null) {
              widget.controller
                  .seekTo(Duration(milliseconds: _dragValue!.toInt()))
                  .then((_) {
                if (_wasPlaying && mounted) {
                  widget.controller.play();
                }
              });
            }
            setState(() {
              _isDragging = false;
              _dragValue = null;
            });
          },
          onHorizontalDragCancel: () {
            if (_wasPlaying && mounted) {
              widget.controller.play();
            }
            setState(() {
              _isDragging = false;
              _dragValue = null;
            });
          },
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;

            final localPosition = box.globalToLocal(details.globalPosition);
            final progress =
                (localPosition.dx / box.size.width).clamp(0.0, 1.0);
            final newPosition = duration * progress;

            widget.controller.seekTo(
              Duration(milliseconds: newPosition.toInt()),
            );
          },
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.inactiveColor,
              borderRadius: BorderRadius.circular(widget.height / 2),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: duration > 0
                      ? (position / duration).clamp(0.0, 1.0)
                      : 0.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.activeColor,
                      borderRadius: BorderRadius.circular(widget.height / 2),
                    ),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final box = context.findRenderObject() as RenderBox?;
                    final width =
                        box?.size.width ?? MediaQuery.of(context).size.width;
                    final progress = duration > 0
                        ? (position / duration).clamp(0.0, 1.0)
                        : 0.0;
                    return Positioned(
                      left: (progress * width) - 10,
                      top: -7,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: widget.activeColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
