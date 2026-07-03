import 'package:flutter/material.dart';

/// Batch selection mode UI (like WhatsApp multi-select)
/// Shows count of selected items and action buttons
class BatchSelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedCount;
  final VoidCallback onClose;
  final List<BatchAction> actions;

  const BatchSelectionAppBar({
    super.key,
    required this.selectedCount,
    required this.onClose,
    this.actions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      backgroundColor: isDark ? const Color(0xFF2A3942) : const Color(0xFF008069),
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: onClose,
      ),
      title: Text(
        '$selectedCount selected',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: actions.map((action) {
        return IconButton(
          icon: Icon(action.icon, color: Colors.white),
          tooltip: action.label,
          onPressed: action.onPressed,
        );
      }).toList(),
    );
  }
}

class BatchAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  BatchAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}

/// Batch selection manager - tracks selected items
class BatchSelectionManager<T> extends ChangeNotifier {
  final Set<T> _selectedItems = {};
  bool _isSelectionMode = false;

  bool get isSelectionMode => _isSelectionMode;
  int get selectedCount => _selectedItems.length;
  List<T> get selectedItems => _selectedItems.toList();
  
  bool isSelected(T item) => _selectedItems.contains(item);

  void toggleSelection(T item) {
    if (_selectedItems.contains(item)) {
      _selectedItems.remove(item);
      if (_selectedItems.isEmpty) {
        exitSelectionMode();
      }
    } else {
      _selectedItems.add(item);
      if (!_isSelectionMode) {
        _isSelectionMode = true;
      }
    }
    notifyListeners();
  }

  void selectAll(List<T> items) {
    _selectedItems.addAll(items);
    _isSelectionMode = true;
    notifyListeners();
  }

  void clearSelection() {
    _selectedItems.clear();
    notifyListeners();
  }

  void exitSelectionMode() {
    _isSelectionMode = false;
    _selectedItems.clear();
    notifyListeners();
  }

  void enterSelectionMode() {
    _isSelectionMode = true;
    notifyListeners();
  }
}

/// Selectable list item with checkbox (for batch operations)
class SelectableListItem extends StatelessWidget {
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget child;

  const SelectableListItem({
    super.key,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF008069).withOpacity(0.1)
              : Colors.transparent,
          border: isSelected
              ? Border(
                  left: BorderSide(
                    color: const Color(0xFF008069),
                    width: 3,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            if (isSelectionMode) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                  activeColor: const Color(0xFF008069),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ] else
              const SizedBox(width: 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Batch action bottom sheet (shows action options)
class BatchActionSheet extends StatelessWidget {
  final int selectedCount;
  final List<BatchSheetAction> actions;

  const BatchActionSheet({
    super.key,
    required this.selectedCount,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202C33) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '$selectedCount item${selectedCount > 1 ? 's' : ''} selected',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...actions.map((action) => ListTile(
            leading: Icon(
              action.icon,
              color: action.isDestructive 
                  ? Colors.red 
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            title: Text(
              action.label,
              style: TextStyle(
                color: action.isDestructive 
                    ? Colors.red 
                    : (isDark ? Colors.white : Colors.black87),
                fontWeight: action.isDestructive ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            subtitle: action.description != null
                ? Text(
                    action.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  )
                : null,
            onTap: () {
              Navigator.pop(context);
              action.onPressed();
            },
          )),
        ],
      ),
    );
  }
}

class BatchSheetAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDestructive;
  final String? description;

  BatchSheetAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
    this.description,
  });
}
