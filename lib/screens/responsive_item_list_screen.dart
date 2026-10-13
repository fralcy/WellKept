import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_localizations.dart';
import '../core/models/due_status.dart';
import '../core/providers/settings_provider.dart';
import '../core/providers/tracked_item_provider.dart';
import '../core/utils/item_labels.dart';
import '../core/widgets/item_photo.dart';
import '../core/widgets/neumorphic_container.dart';
import '../models/tracked_item.dart';
import 'modals/add_item_modal.dart';
import 'modals/add_log_modal.dart';
import 'modals/settings_modal.dart';
import 'modals/update_reading_modal.dart';
import 'responsive_screen.dart';

/// The app's only route: every tracked item, most urgent first. Adding an
/// item or a log happens in modals, never by pushing a new route.
class ResponsiveItemListScreen extends StatelessWidget {
  const ResponsiveItemListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsProvider>().themeConfig;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: t.background,
        foregroundColor: t.textPrimary,
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showSettingsModal(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddItemModal(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.addItem),
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
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TrackedItemProvider>();
    final items = provider.itemsByUrgency();

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.emptyList,
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
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final dueColor = status.isOverdue
        ? scheme.error
        : status.isDueSoon
        ? t.accent
        : t.textSecondary;
    final staleWarning = staleReadingWarning(l10n, status);
    final icon = SizedBox.square(
      dimension: 48,
      child: Icon(categoryIcon(item.category), color: t.accent),
    );

    return GestureDetector(
      onTap: () => showAddLogModal(context, item),
      child: NeumorphicContainer(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          children: [
            if (item.photoId != null)
              ItemPhoto(photoId: item.photoId!, size: 48, placeholder: icon)
            else
              icon,
            const SizedBox(width: 12),
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
                    dueSummary(l10n, status, item),
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
              tooltip: l10n.moreOptions,
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
                    _confirmDelete(context, l10n);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _ItemAction.log,
                  child: Text(l10n.menuLog),
                ),
                if (item.recurrenceType == RecurrenceType.byValue)
                  PopupMenuItem(
                    value: _ItemAction.reading,
                    child: Text(l10n.menuUpdateReading),
                  ),
                PopupMenuItem(
                  value: _ItemAction.edit,
                  child: Text(l10n.menuEdit),
                ),
                PopupMenuItem(
                  value: _ItemAction.delete,
                  child: Text(l10n.delete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppLocalizations l10n) {
    final provider = context.read<TrackedItemProvider>();
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteItemTitle(item.name)),
        content: Text(l10n.deleteItemBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            // Deletes straight from the button handler rather than after
            // awaiting the dialog's result — the write then starts in the
            // tap's own zone, which widget tests can run for real.
            onPressed: () {
              Navigator.of(context).pop();
              provider.deleteItem(item.id);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

enum _ItemAction { log, reading, edit, delete }
