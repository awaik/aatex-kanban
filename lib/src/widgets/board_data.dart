import 'dart:collection';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:equatable/equatable.dart';

import 'package:aatex_board/src/widgets/board_group/group_data.dart';
import 'package:aatex_board/src/widgets/board.dart';

import '../utils/log.dart';

import 'reorder_flex/reorder_flex.dart';
import 'reorder_phantom/phantom_controller.dart';

typedef OnMoveGroup = void Function(
  String fromGroupId,
  int fromIndex,
  String toGroupId,
  int toIndex,
);

typedef OnMoveGroupItem = void Function<T>(
  String groupId,
  int fromIndex,
  int toIndex,
  T item,
);

typedef OnMoveGroupItemToGroup = void Function<T>(
  String fromGroupId,
  int fromIndex,
  String toGroupId,
  int toIndex,
  T item,
);

typedef OnStartDraggingCard = void Function(
  String groupId,
  int index,
);

/// A controller for [AATexBoard] widget.
///
/// A [AATexBoardController] can be used to provide an initial value of
/// the board by calling `addGroup` method with the passed in parameter
/// [AATexGroupData]. A [AATexGroupData] represents one
/// group data. Whenever the user modifies the board, this controller will
/// update the corresponding group data.
///
/// Also, you can register the callbacks that receive the changes.
/// [onMoveGroup] will get called when moving the group from one position to
/// another.
///
/// [onMoveGroupItem] will get called when moving the group's items.
///
/// [onMoveGroupItemToGroup] will get called when moving the group's item from
/// one group to another group.
class AATexBoardController extends ChangeNotifier
    with EquatableMixin
    implements BoardPhantomControllerDelegate, ReoderFlexDataSource {
  AATexBoardController({
    this.onMoveGroup,
    this.onMoveGroupItem,
    this.onMoveGroupItemToGroup,
    this.onStartDraggingCard,
  });

  final List<AATexGroupData> _groupDatas = [];

  /// [onMoveGroup] will get called when moving the group from one position to
  /// another.
  final OnMoveGroup? onMoveGroup;

  /// [onMoveGroupItem] will get called when moving the group's items.
  final OnMoveGroupItem? onMoveGroupItem;

  /// [onMoveGroupItemToGroup] will get called when moving the group's item from
  /// one group to another group.
  final OnMoveGroupItemToGroup? onMoveGroupItemToGroup;

  final OnStartDraggingCard? onStartDraggingCard;

  /// Returns the unmodifiable list of [AATexGroupData]
  UnmodifiableListView<AATexGroupData> get groupDatas => UnmodifiableListView(_groupDatas);

  /// Returns list of group id
  List<String> get groupIds => _groupDatas.map((groupData) => groupData.id).toList();

  final LinkedHashMap<String, AATexGroupController> _groupControllers = LinkedHashMap();

  /// Adds a new group to the end of the current group list.
  ///
  /// If you don't want to notify the listener after adding a new group, the
  /// [notify] should set to false. Default value is true.
  void addGroup(AATexGroupData groupData, {bool notify = true}) {
    if (_groupControllers[groupData.id] != null) return;

    final controller = AATexGroupController(groupData: groupData);
    _groupDatas.add(groupData);
    _groupControllers[groupData.id] = controller;
    if (notify) notifyListeners();
  }

  /// Inserts a new group at the given index
  ///
  /// If you don't want to notify the listener after inserting the new group, the
  /// [notify] should set to false. Default value is true.
  void insertGroup(
    int index,
    AATexGroupData groupData, {
    bool notify = true,
  }) {
    if (_groupControllers[groupData.id] != null) return;

    final controller = AATexGroupController(groupData: groupData);
    _groupDatas.insert(index, groupData);
    _groupControllers[groupData.id] = controller;
    if (notify) notifyListeners();
  }

  /// Adds a list of groups to the end of the current group list.
  ///
  /// If you don't want to notify the listener after adding the groups, the
  /// [notify] should set to false. Default value is true.
  void addGroups(List<AATexGroupData> groups, {bool notify = true}) {
    for (final column in groups) {
      addGroup(column, notify: false);
    }

    if (groups.isNotEmpty && notify) notifyListeners();
  }

  /// Removes the group with id [groupId]
  ///
  /// If you don't want to notify the listener after removing the group, the
  /// [notify] should set to false. Default value is true.
  void removeGroup(String groupId, {bool notify = true}) {
    final index = _groupDatas.indexWhere((group) => group.id == groupId);
    if (index == -1) {
      Log.warn(
        'Try to remove Group:[$groupId] failed. Group:[$groupId] does not exist',
      );
    }

    if (index != -1) {
      _groupDatas.removeAt(index);
      _groupControllers.remove(groupId);

      if (notify) notifyListeners();
    }
  }

  /// Removes a list of groups
  ///
  /// If you don't want to notify the listener after removing the groups, the
  /// [notify] should set to false. Default value is true.
  void removeGroups(List<String> groupIds, {bool notify = true}) {
    for (final groupId in groupIds) {
      removeGroup(groupId, notify: false);
    }

    if (groupIds.isNotEmpty && notify) notifyListeners();
  }

  /// Remove all the groups controller.
  ///
  /// This method should get called when you want to remove all the current
  /// groups or get ready to reinitialize the [AATexBoard].
  void clear() {
    _groupDatas.clear();
    for (final group in _groupControllers.values) {
      group.dispose();
    }
    _groupControllers.clear();

    notifyListeners();
  }

  /// Returns the [AATexGroupController] with id [groupId].
  AATexGroupController? getGroupController(String groupId) {
    final groupController = _groupControllers[groupId];
    if (groupController == null) {
      Log.warn('Group:[$groupId] \'s controller is not exist');
    }

    return groupController;
  }

  /// Moves the group controller from [fromIndex] to [toIndex] and notify the
  /// listeners.
  ///
  /// If you don't want to notify the listener after moving the group, the
  /// [notify] should set to false. Default value is true.
  void moveGroup(int fromIndex, int toIndex, {bool notify = true}) {
    final toGroupData = _groupDatas[toIndex];
    final fromGroupData = _groupDatas.removeAt(fromIndex);

    _groupDatas.insert(toIndex, fromGroupData);
    onMoveGroup?.call(fromGroupData.id, fromIndex, toGroupData.id, toIndex);
    if (notify) notifyListeners();
  }

  /// Moves the group's item from [fromIndex] to [toIndex]
  /// If the group with id [groupId] is not exist, this method will do nothing.
  void moveGroupItem<T>(String groupId, int fromIndex, int toIndex, T item) {
    if (getGroupController(groupId)?.move(fromIndex, toIndex) ?? false) {
      onMoveGroupItem?.call(groupId, fromIndex, toIndex, item);
    }
  }

  /// Adds the [AATexGroupItem] to the end of the group
  ///
  /// If the group with id [groupId] is not exist, this method will do nothing.
  void addGroupItem(String groupId, AATexGroupItem item) {
    getGroupController(groupId)?.add(item);
  }

  /// Inserts the [AATexGroupItem] at [index] in the group
  ///
  /// It will do nothing if the group with id [groupId] is not exist
  void insertGroupItem(String groupId, int index, AATexGroupItem item) {
    getGroupController(groupId)?.insert(index, item);
  }

  /// Removes the item with id [itemId] from the group
  ///
  /// It will do nothing if the group with id [groupId] is not exist
  void removeGroupItem(String groupId, String itemId) {
    getGroupController(groupId)?.removeWhere((item) => item.id == itemId);
  }

  /// Replaces or inserts the [AATexGroupItem] to the end of the group.
  ///
  /// If the group with id [groupId] is not exist, this method will do nothing.
  void updateGroupItem(String groupId, AATexGroupItem item) {
    getGroupController(groupId)?.replaceOrInsertItem(item);
  }

  void enableGroupDragging(bool isEnable) {
    for (final groupController in _groupControllers.values) {
      groupController.enableDragging(isEnable);
    }
  }

  /// Moves the item at [fromGroupIndex] in group with id [fromGroupId] to
  /// group with id [toGroupId] at [toGroupIndex]
  @override
  @protected
  void moveGroupItemToAnotherGroup<T>(
    String fromGroupId,
    int fromGroupIndex,
    String toGroupId,
    int toGroupIndex,
    T item,
  ) {
    final fromGroupController = getGroupController(fromGroupId)!;
    final toGroupController = getGroupController(toGroupId)!;
    final fromGroupItem = fromGroupController.removeAt(fromGroupIndex);
    if (fromGroupItem == null) return;

    if (toGroupController.items.length > toGroupIndex) {
      assert(toGroupController.items[toGroupIndex] is PhantomGroupItem);

      toGroupController.replace(toGroupIndex, fromGroupItem);
      onMoveGroupItemToGroup?.call(
        fromGroupId,
        fromGroupIndex,
        toGroupId,
        toGroupIndex,
        item,
      );
    }
  }

  /// Highlights a specific card and makes others inactive.
  /// Ensures the card is visible by scrolling to its column and position.
  ///
  /// Parameters:
  /// - [groupId]: The ID of the group/column containing the card
  /// - [itemId]: The ID of the card to highlight
  /// - [highlightColor]: Optional color for highlighting the card
  /// - [highlightBorder]: Optional border for highlighting the card
  /// - [animationDuration]: Duration for scroll animation (defaults to 300ms)
  /// - [boardScrollController]: The scroll controller to use for scrolling to the card
  Future<bool> displayCard({
    required String groupId,
    required String itemId,
    Color? highlightColor,
    BorderSide? highlightBorder,
    Duration animationDuration = const Duration(milliseconds: 300),
    AATexBoardScrollController? boardScrollController,
  }) async {
    Log.debug('====== START DISPLAY CARD ======');
    Log.debug('Attempting to display card: groupId=$groupId, itemId=$itemId');

    // Find the group controller
    final groupController = getGroupController(groupId);
    if (groupController == null) {
      Log.warn('Cannot display card: Group with ID "$groupId" not found');
      Log.debug('====== END DISPLAY CARD (FAILED) ======');
      return false;
    }
    Log.debug('Found group controller for "$groupId"');

    // Find the item index
    final itemIndex = groupController.items.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) {
      Log.warn('Cannot display card: Item with ID "$itemId" not found in group "$groupId"');
      Log.debug('====== END DISPLAY CARD (FAILED) ======');
      return false;
    }
    Log.debug('Found item at index $itemIndex in group "$groupId"');

    // Reset active state for all cards in all groups
    Log.debug('Resetting active state for all cards in all groups...');
    int inactiveCardsCount = 0;
    for (final controller in _groupControllers.values) {
      for (var i = 0; i < controller.items.length; i++) {
        final item = controller.items[i];
        if (!item.isPhantom && item is AATexGroupItem) {
          // Make item inactive by setting its property
          if (item is ActiveableGroupItem) {
            final updatedItem = (item as ActiveableGroupItem).copyWith(
              isActive: false,
              highlightColor: null,
              highlightBorder: null,
            );
            controller.replace(i, updatedItem as AATexGroupItem);
            inactiveCardsCount++;
          }
        }
      }
    }
    Log.debug('Reset active state for $inactiveCardsCount cards');

    // Get the target item and set it as active
    Log.debug('Setting target card as active...');
    final targetItem = groupController.items[itemIndex];
    if (!targetItem.isPhantom && targetItem is AATexGroupItem) {
      if (targetItem is ActiveableGroupItem) {
        Log.debug('Target card implements ActiveableGroupItem interface');

        // Use provided highlight border or default to 4px green border
        final border = highlightBorder ??
            const BorderSide(
              color: Colors.green,
              width: 4.0,
            );

        final updatedItem = (targetItem as ActiveableGroupItem).copyWith(
          isActive: true,
          highlightColor: highlightColor,
          highlightBorder: border,
        );
        groupController.replace(itemIndex, updatedItem as AATexGroupItem);
        Log.debug('Successfully set card as active with highlightBorder: ${border.toString()}');
      } else {
        Log.warn('Target card does not implement ActiveableGroupItem interface');
      }
    } else {
      Log.warn('Target card is either a phantom or not an AATexGroupItem');
    }

    // Notify listeners to update UI
    notifyListeners();
    Log.debug('Notified listeners of card state changes');

    // Scroll to make the card visible if a scroll controller is provided
    try {
      if (boardScrollController != null) {
        Log.debug('Scroll controller provided, attempting to scroll to group and item...');

        // Создаем Completer для ожидания завершения прокрутки
        final completer = Completer<bool>();

        // Сначала прокручиваем к колонке горизонтально, чтобы она была видима
        Log.debug('First, scrolling horizontally to make column visible...');
        boardScrollController.scrollToGroup(
          groupId,
          completed: (context) {
            Log.debug('Horizontal scroll completed, now scrolling to specific item...');

            // Затем прокручиваем к элементу в колонке вертикально
            boardScrollController.scrollToItem(
              groupId,
              itemIndex,
              completed: (context) {
                Log.debug('Vertical scroll completed - item $itemId in group $groupId is now visible');
                completer.complete(true);
              },
            );
          },
        );

        Log.debug('Scroll commands issued successfully');
        return await completer.future;
      } else {
        Log.warn('Cannot scroll to card: No board scroll controller provided');
        Log.debug('No scrolling performed (no controller)');
        Log.debug('====== END DISPLAY CARD (PARTIAL SUCCESS) ======');
        return false;
      }
    } catch (e) {
      Log.error('Error scrolling to display card: $e');
      Log.debug('Stack trace: ${StackTrace.current}');
      Log.debug('Scrolling failed');
      Log.debug('====== END DISPLAY CARD (FAILURE) ======');
      return false;
    }
  }

  @override
  List<Object?> get props => [_groupDatas];

  @override
  AATexGroupController? controller(String groupId) => _groupControllers[groupId];

  @override
  String get identifier => '$AATexBoardController';

  @override
  UnmodifiableListView<ReoderFlexItem> get items => UnmodifiableListView(_groupDatas);

  @override
  @protected
  bool removePhantom(String groupId) {
    final groupController = getGroupController(groupId);
    if (groupController == null) {
      Log.warn('Can not find the group controller with groupId: $groupId');
      return false;
    }
    final index = groupController.items.indexWhere((item) => item.isPhantom);
    final isExist = index != -1;
    if (isExist) {
      groupController.removeAt(index);

      Log.debug(
        '[$AATexBoardController] Group:[$groupId] remove phantom, current count: ${groupController.items.length}',
      );
    }
    return isExist;
  }

  @override
  @protected
  void updatePhantom(String groupId, int newIndex) {
    final groupController = getGroupController(groupId)!;
    final index = groupController.items.indexWhere((item) => item.isPhantom);

    if (index != -1) {
      if (index != newIndex) {
        Log.trace(
          '[$BoardPhantomController] update $groupId:$index to $groupId:$newIndex',
        );
        final item = groupController.removeAt(index, notify: false);
        if (item != null) {
          groupController.insert(newIndex, item, notify: false);
        }
      }
    }
  }

  @override
  @protected
  void insertPhantom(String groupId, int index, PhantomGroupItem item) =>
      getGroupController(groupId)!.insert(index, item);
}
