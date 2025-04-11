import 'dart:collection';

import 'package:flutter/material.dart';

import 'package:equatable/equatable.dart';

import 'package:aatex_board/src/utils/log.dart';
import 'package:aatex_board/src/widgets/reorder_flex/reorder_flex.dart';

typedef IsDraggable = bool;

/// Interface for group items that can be activated/highlighted
abstract class ActiveableGroupItem {
  /// Whether this item is currently active (highlighted)
  bool get isActive;

  /// Color used for highlighting this item when active
  Color? get highlightColor;

  /// Border used for highlighting this item when active
  BorderSide? get highlightBorder;

  /// Creates a copy of this item with the specified active state, highlight color and border
  ActiveableGroupItem copyWith({
    bool? isActive,
    Color? highlightColor,
    BorderSide? highlightBorder,
  });
}

/// A item represents the generic data model of each group card.
///
/// Each item displayed in the group required to implement this class.
abstract class AATexGroupItem extends ReorderFlexItem {
  bool get isPhantom => false;

  /// Controls if this item should animate when moving between groups
  /// Default is true
  bool get animateOnGroupChange => true;

  /// Duration for cross-group animation
  /// If null, system default will be used
  Duration? get crossGroupAnimationDuration => null;

  @override
  String toString() => id;
}

/// [AATexGroupController] is used to handle the [AATexGroupData].
///
/// * Remove an item by calling [removeAt] method.
/// * Move item to another position by calling [move] method.
/// * Insert item to index by calling [insert] method
/// * Replace item at index by calling [replace] method.
///
/// All there operations will notify listeners by default.
///
class AATexGroupController extends ChangeNotifier with EquatableMixin {
  AATexGroupController({required this.groupData});

  final AATexGroupData groupData;

  @override
  List<Object?> get props => groupData.props;

  /// Returns the readonly List<AATexGroupItem>
  UnmodifiableListView<AATexGroupItem> get items =>
      UnmodifiableListView(groupData.items);

  void updateGroupName(String newName) {
    if (groupData.headerData.groupName != newName) {
      groupData.headerData.groupName = newName;
      _notify();
    }
  }

  /// Remove the item at [index].
  /// * [index] the index of the item you want to remove
  /// * [notify] the default value of [notify] is true, it will notify the
  /// listener. Set to false if you do not want to notify the listeners.
  ///
  AATexGroupItem? removeAt(int index, {bool notify = true}) {
    if (groupData._items.length <= index) {
      Log.error(
        'Fatal error, index is out of bounds. Index: $index,  len: ${groupData._items.length}',
      );
      return null;
    }

    if (index < 0) {
      Log.error('Invalid index:$index');
      return null;
    }

    Log.debug('[$AATexGroupController] $groupData remove item at $index');
    final item = groupData._items.removeAt(index);
    if (notify) {
      _notify();
    }
    return item;
  }

  void removeWhere(bool Function(AATexGroupItem) condition) {
    final index = items.indexWhere(condition);
    if (index != -1) {
      removeAt(index);
    }
  }

  /// Move the item from [fromIndex] to [toIndex]. It will do nothing if the
  /// [fromIndex] equal to the [toIndex].
  bool move(int fromIndex, int toIndex) {
    assert(toIndex >= 0);
    if (groupData._items.length < fromIndex) {
      Log.error(
        'Out of bounds error. index: $fromIndex should not greater than ${groupData._items.length}',
      );
      return false;
    }

    if (fromIndex == toIndex) {
      return false;
    }

    Log.debug(
      '[$AATexGroupController] $groupData move item from $fromIndex to $toIndex',
    );
    final item = groupData._items.removeAt(fromIndex);
    groupData._items.insert(toIndex, item);
    _notify();
    return true;
  }

  /// Insert an item to [index] and notify the listen if the value of [notify]
  /// is true.
  ///
  /// The default value of [notify] is true.
  bool insert(int index, AATexGroupItem item, {bool notify = true}) {
    assert(index >= 0);
    Log.debug('[$AATexGroupController] $groupData insert $item at $index');

    if (_containsItem(item)) {
      return false;
    } else {
      if (groupData._items.length > index) {
        groupData._items.insert(index, item);
      } else {
        groupData._items.add(item);
      }

      if (notify) _notify();
      return true;
    }
  }

  bool add(AATexGroupItem item, {bool notify = true}) {
    if (_containsItem(item)) {
      return false;
    } else {
      groupData._items.add(item);
      if (notify) _notify();
      return true;
    }
  }

  /// Replace the item at index with the [newItem].
  void replace(int index, AATexGroupItem newItem) {
    if (groupData._items.isEmpty) {
      groupData._items.add(newItem);
      Log.debug('[$AATexGroupController] $groupData add $newItem');
    } else {
      if (index >= groupData._items.length) {
        Log.error(
          '[$AATexGroupController] unexpected items length, index should less than the count of the items. Index: $index, items count: ${items.length}',
        );
        return;
      }

      final removedItem = groupData._items.removeAt(index);
      groupData._items.insert(index, newItem);
      Log.debug(
        '[$AATexGroupController] $groupData replace $removedItem with $newItem at $index',
      );
    }

    _notify();
  }

  void replaceOrInsertItem(AATexGroupItem newItem) {
    final index = groupData._items.indexWhere((item) => item.id == newItem.id);
    if (index != -1) {
      groupData._items.removeAt(index);
      groupData._items.insert(index, newItem);
      _notify();
    } else {
      groupData._items.add(newItem);
      _notify();
    }
  }

  bool _containsItem(AATexGroupItem item) {
    return groupData._items.indexWhere((element) => element.id == item.id) !=
        -1;
  }

  void enableDragging(bool isEnable) {
    groupData.draggable.value = isEnable;

    for (final item in groupData._items) {
      item.draggable.value = isEnable;
    }
  }

  void _notify() {
    notifyListeners();
  }
}

/// [AATexGroupData] represents the data of each group of the Board.
class AATexGroupData<T> extends ReorderFlexItem with EquatableMixin {
  AATexGroupData({
    required this.id,
    required String name,
    this.customData,
    List<AATexGroupItem> items = const [],
  })  : _items = items,
        headerData = AATexGroupHeaderData(
          groupId: id,
          groupName: name,
        );

  @override
  final String id;
  AATexGroupHeaderData headerData;
  final T? customData;

  final List<AATexGroupItem> _items;

  /// Returns the readonly List<AATexGroupItem>
  UnmodifiableListView<AATexGroupItem> get items =>
      UnmodifiableListView([..._items]);

  @override
  List<Object?> get props => [id, ..._items];

  @override
  String toString() => 'Group:[$id]';
}

class AATexGroupHeaderData {
  AATexGroupHeaderData({
    required this.groupId,
    required this.groupName,
  });

  String groupId;
  String groupName;
}
