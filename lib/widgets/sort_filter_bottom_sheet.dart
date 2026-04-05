import 'dart:async';

import 'package:draw/draw.dart' as draw;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/feed_sort.dart';
import 'package:yarc/notifiers/feed_notifier.dart';

class SortFilterBottomSheet extends StatefulWidget {
  const SortFilterBottomSheet({
    required this.onSortApplied,
    super.key,
  });

  final VoidCallback onSortApplied;

  /// Shows the bottom sheet in the context.
  static void show(
    BuildContext context, {
    required VoidCallback onSortApplied,
  }) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) =>
            SortFilterBottomSheet(onSortApplied: onSortApplied),
      ),
    );
  }

  @override
  State<SortFilterBottomSheet> createState() => _SortFilterBottomSheetState();
}

class _SortFilterBottomSheetState extends State<SortFilterBottomSheet> {
  String _timeFilterLabel(draw.TimeFilter filter) {
    return switch (filter) {
      draw.TimeFilter.hour => 'Past Hour',
      draw.TimeFilter.day => 'Today',
      draw.TimeFilter.week => 'This Week',
      draw.TimeFilter.month => 'This Month',
      draw.TimeFilter.year => 'This Year',
      draw.TimeFilter.all => 'All Time',
    };
  }

  IconData _sortIcon(FeedSort sort) {
    return switch (sort) {
      FeedSort.best => Icons.recommend,
      FeedSort.hot => Icons.local_fire_department,
      FeedSort.newest => Icons.new_releases,
      FeedSort.top => Icons.trending_up,
      FeedSort.controversial => Icons.bolt,
      FeedSort.rising => Icons.moving,
    };
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<FeedNotifier>();
    final currentSort = notifier.currentSort;
    final currentTimeFilter = notifier.currentTimeFilter;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // The API only supports 'best' on the front page.
    final availableSorts = notifier.currentSubreddit == null
        ? FeedSort.values
        : FeedSort.values.where((s) => s != FeedSort.best).toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Text(
              'Sort Posts By',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: availableSorts.map((sort) {
                final isSelected = currentSort == sort;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    tileColor: isSelected
                        ? colorScheme.secondaryContainer
                        : null,
                    title: Text(
                      feedSortLabel(sort),
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? colorScheme.onSecondaryContainer
                            : null,
                      ),
                    ),
                    leading: Icon(
                      _sortIcon(sort),
                      color: isSelected
                          ? colorScheme.onSecondaryContainer
                          : null,
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: colorScheme.onSecondaryContainer,
                          )
                        : null,
                    onTap: () {
                      notifier.setSort(sort);
                      if (!feedSortNeedsTimeFilter(sort)) {
                        widget.onSortApplied();
                        Navigator.pop(context);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          if (feedSortNeedsTimeFilter(currentSort)) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Divider(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Text(
                'Time Range',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 12,
                children: draw.TimeFilter.values.map((filter) {
                  final isSelected = currentTimeFilter == filter;
                  return ChoiceChip(
                    label: Text(_timeFilterLabel(filter)),
                    selected: isSelected,
                    showCheckmark: false,
                    avatar: isSelected
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: colorScheme.onSecondaryContainer,
                          )
                        : null,
                    selectedColor: colorScheme.secondaryContainer,
                    labelStyle: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        notifier.setTimeFilter(filter);
                        widget.onSortApplied();
                        Navigator.pop(context);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
