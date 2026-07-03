import 'package:flutter/material.dart';

/// Linear progress indicator with percentage (for file uploads/downloads)
class FileProgressIndicator extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String? fileName;
  final String? actionText; // "Uploading..." or "Downloading..."
  final VoidCallback? onCancel;
  final Color? color;

  const FileProgressIndicator({
    super.key,
    required this.progress,
    this.fileName,
    this.actionText,
    this.onCancel,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progressColor = color ?? const Color(0xFF008069);
    final percentage = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202C33) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (fileName != null)
                      Text(
                        fileName!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (actionText != null) ...[
                      if (fileName != null) const SizedBox(height: 4),
                      Text(
                        actionText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onCancel != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onCancel,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: isDark 
                        ? Colors.grey[800] 
                        : Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: progressColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact circular progress with percentage (for send button, etc.)
class CompactProgressIndicator extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final Color? color;
  final bool showPercentage;

  const CompactProgressIndicator({
    super.key,
    required this.progress,
    this.size = 36,
    this.color,
    this.showPercentage = true,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? const Color(0xFF008069);
    final percentage = (progress * 100).toInt();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              backgroundColor: progressColor.withOpacity(0.2),
            ),
          ),
          if (showPercentage)
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: size * 0.25,
                fontWeight: FontWeight.bold,
                color: progressColor,
              ),
            ),
        ],
      ),
    );
  }
}

/// Multi-file upload progress widget
class MultiFileProgressWidget extends StatelessWidget {
  final List<FileUploadProgress> files;
  final VoidCallback? onCancelAll;

  const MultiFileProgressWidget({
    super.key,
    required this.files,
    this.onCancelAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalProgress = files.isEmpty 
        ? 0.0 
        : files.map((f) => f.progress).reduce((a, b) => a + b) / files.length;
    final completedCount = files.where((f) => f.progress >= 1.0).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202C33) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uploading ${files.length} file${files.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completedCount of ${files.length} complete',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (onCancelAll != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onCancelAll,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalProgress,
              minHeight: 8,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF008069)),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        _getFileIcon(file.fileName),
                        size: 20,
                        color: file.progress >= 1.0 
                            ? Colors.green 
                            : (isDark ? Colors.white70 : Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.fileName,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: file.progress,
                                minHeight: 3,
                                backgroundColor: isDark 
                                    ? Colors.grey[800] 
                                    : Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  file.progress >= 1.0 
                                      ? Colors.green 
                                      : const Color(0xFF008069),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(file.progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: file.progress >= 1.0 
                              ? Colors.green 
                              : const Color(0xFF008069),
                        ),
                      ),
                      if (file.onCancel != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: file.onCancel,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: Colors.grey,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return Icons.image;
    } else if (['mp4', 'avi', 'mov', 'mkv'].contains(ext)) {
      return Icons.videocam;
    } else if (['mp3', 'wav', 'm4a', 'aac'].contains(ext)) {
      return Icons.audiotrack;
    } else if (['pdf'].contains(ext)) {
      return Icons.picture_as_pdf;
    } else if (['doc', 'docx'].contains(ext)) {
      return Icons.description;
    } else if (['xls', 'xlsx'].contains(ext)) {
      return Icons.table_chart;
    } else if (['zip', 'rar', '7z'].contains(ext)) {
      return Icons.folder_zip;
    }
    
    return Icons.insert_drive_file;
  }
}

/// Model for file upload progress
class FileUploadProgress {
  final String fileName;
  final double progress; // 0.0 to 1.0
  final VoidCallback? onCancel;

  FileUploadProgress({
    required this.fileName,
    required this.progress,
    this.onCancel,
  });
}

/// Indeterminate progress overlay (for operations without known duration)
class IndeterminateProgressOverlay extends StatelessWidget {
  final String message;
  final VoidCallback? onCancel;

  const IndeterminateProgressOverlay({
    super.key,
    required this.message,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF202C33) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008069)),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              if (onCancel != null) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onCancel,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Determinate progress overlay (for operations with known progress)
class DeterminateProgressOverlay extends StatelessWidget {
  final String message;
  final double progress; // 0.0 to 1.0
  final VoidCallback? onCancel;

  const DeterminateProgressOverlay({
    super.key,
    required this.message,
    required this.progress,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percentage = (progress * 100).toInt();

    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF202C33) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF008069)),
                      backgroundColor: Colors.grey[300],
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF008069)),
              ),
              if (onCancel != null) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onCancel,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline loading indicator with text (for list items)
class InlineLoadingIndicator extends StatelessWidget {
  final String message;
  final double size;

  const InlineLoadingIndicator({
    super.key,
    required this.message,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008069)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

/// Progress button - button that shows progress during async operation
class ProgressButton extends StatefulWidget {
  final String text;
  final Future<void> Function() onPressed;
  final IconData? icon;
  final Color? color;
  final Color? textColor;

  const ProgressButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.color,
    this.textColor,
  });

  @override
  State<ProgressButton> createState() => _ProgressButtonState();
}

class _ProgressButtonState extends State<ProgressButton> {
  bool _isLoading = false;

  Future<void> _handlePress() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onPressed();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handlePress,
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.color ?? const Color(0xFF008069),
        foregroundColor: widget.textColor ?? Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.text,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}
