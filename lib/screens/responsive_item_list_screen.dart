import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/neumorphic_themes.dart';
import '../core/models/due_status.dart';
import '../core/providers/settings_provider.dart';
import '../core/providers/tracked_item_provider.dart';
import '../core/utils/item_labels.dart';
import '../core/widgets/neumorphic_container.dart';
import '../models/tracked_item.dart';
import 'modals/add_item_modal.dart';
import 'modals/add_log_modal.dart';
import 'modals/update_reading_modal.dart';
import 'responsive_screen.dart';

/// The app's only route: every tracked item, most urgent first. Adding an
/// item or a log happens in modals, never by pushing a new route.
class ResponsiveItemListScreen extends StatelessWidget {
  const ResponsiveItemListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsProvider>().themeConfig;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: t.background,
        foregroundColor: t.textPrimary,
        title: const Text('WellKept'),
        actions: const [_ThemeMenu()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddItemModal(context),
        icon: const Icon(Icons.add),
        label: const Text('Thêm món đồ'),
      ),
      body: ResponsiveScreen(
        mobileBuilder: (_) => const _ItemList(),
        // Same list, just kept to a readable width on wide screens.
        desktopBuilder: (_) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: const _ItemList(),
          ),
        ),
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList();

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsProvider>().themeConfig;
    final provider = context.watch<TrackedItemProvider>();
    final items = provider.itemsByUrgency();

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Chưa có món đồ nào.\nBấm "Thêm món đồ" để bắt đầu theo dõi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      // Bottom padding keeps the last card clear of the FAB.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, i) =>
          _ItemCard(item: items[i], status: provider.statusFor(items[i])),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.status});

  final TrackedItem item;
  final DueStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsProvider>().themeConfig;
    final scheme = Theme.of(context).colorScheme;
    final dueColor = status.isOverdue
        ? scheme.error
        : status.isDueSoon
        ? t.accent
        : t.textSecondary;
    final staleWarning = staleReadingWarning(status);

    return GestureDetector(
      onTap: () => showAddLogModal(context, item),
      child: NeumorphicContainer(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          children: [
            Icon(categoryIcon(item.category), color: t.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dueSummary(status, item),
                    style: TextStyle(
                      color: dueColor,
                      fontWeight: status.isDueSoon
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (staleWarning != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.speed, size: 16, color: t.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            staleWarning,
                            style: TextStyle(
                              color: t.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<_ItemAction>(
              tooltip: 'Tùy chọn',
              icon: Icon(Icons.more_vert, color: t.textSecondary),
              onSelected: (action) {
                switch (action) {
                  case _ItemAction.log:
                    showAddLogModal(context, item);
                  case _ItemAction.reading:
                    showUpdateReadingModal(context, item);
                  case _ItemAction.edit:
                    showEditItemModal(context, item);
                  case _ItemAction.delete:
                    _confirmDelete(context);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _ItemAction.log,
                  child: Text('Ghi bảo trì'),
                ),
                if (item.recurrenceType == RecurrenceType.byValue)
                  const PopupMenuItem(
                    value: _ItemAction.reading,
                    child: Text('Cập nhật chỉ số'),
                  ),
                const PopupMenuItem(
                  value: _ItemAction.edit,
                  child: Text('Sửa'),
                ),
                const PopupMenuItem(
                  value: _ItemAction.delete,
                  child: Text('Xóa'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) {
    final provider = context.read<TrackedItemProvider>();
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa "${item.name}"?'),
        content: const Text('Toàn bộ lịch sử bảo trì của món đồ cũng bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            // Deletes straight from the button handler rather than after
            // awaiting the dialog's result — the write then starts in the
            // tap's own zone, which widget tests can run for real.
            onPressed: () {
              Navigator.of(context).pop();
              provider.deleteItem(item.id);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}

enum _ItemAction { log, reading, edit, delete }

class _ThemeMenu extends StatelessWidget {
  const _ThemeMenu();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return PopupMenuButton<String>(
      tooltip: 'Đổi giao diện',
      icon: const Icon(Icons.palette_outlined),
      initialValue: settings.themeId,
      itemBuilder: (_) => [
        for (final NeumorphicThemeConfig theme in neumorphicThemePresets)
          PopupMenuItem(
            value: theme.id,
            // onTap (called directly on tap) rather than the button's
            // onSelected (called after the menu's future completes) — see
            // _ItemCard._confirmDelete for why.
            onTap: () => settings.setThemeId(theme.id),
            child: Row(
              children: [
                CircleAvatar(radius: 8, backgroundColor: theme.accent),
                const SizedBox(width: 10),
                Text(theme.label),
              ],
            ),
          ),
      ],
    );
  }
}
