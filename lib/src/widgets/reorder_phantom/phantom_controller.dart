import 'package:flutter/widgets.dart';

import 'package:aatex_board/aatex_board.dart';

import '../../utils/log.dart';
import '../reorder_flex/drag_state.dart';
import '../reorder_flex/drag_target.dart';
import '../reorder_flex/drag_target_interceptor.dart';

import 'phantom_state.dart';

abstract class BoardPhantomControllerDelegate {
  AATexGroupController? controller(String groupId);

  bool removePhantom(String groupId);

  /// Insert the phantom into the group
  ///
  /// * [groupId] id of the group
  /// * [index] the phantom occupies index
  void insertPhantom(
    String groupId,
    int index,
    PhantomGroupItem item,
  );

  /// Update the group's phantom index if it exists.
  /// [toGroupId] the id of the group
  /// [newIndex] the index of the dragTarget
  void updatePhantom(String groupId, int newIndex);

  void moveGroupItemToAnotherGroup<T>(
    String fromGroupId,
    int fromGroupIndex,
    String toGroupId,
    int toGroupIndex,
    T item,
  );
}

class BoardPhantomController extends OverlapDragTargetDelegate
    implements CrossReorderFlexDragTargetDelegate {
  BoardPhantomController({
    required this.delegate,
    required this.groupsState,
  });

  final BoardPhantomControllerDelegate delegate;
  final AATexBoardState groupsState;

  PhantomRecord? phantomRecord;
  final phantomState = GroupPhantomState();

  /// Determines whether the group should perform reorder
  ///
  /// Returns `true` if the fromGroupId and toGroupId of the phantomRecord
  /// equal to the passed in groupId.
  ///
  /// Returns `true` if the phantomRecord is null
  ///
  bool shouldReorder(String groupId) {
    if (phantomRecord != null) {
      return phantomRecord!.toGroupId == groupId &&
          phantomRecord!.fromGroupId == groupId;
    }
    return true;
  }

  void updateIndex(int fromIndex, int toIndex) {
    if (phantomRecord == null) {
      return;
    }
    assert(phantomRecord!.fromGroupIndex == fromIndex);
    phantomRecord?.updateFromGroupIndex(toIndex);
  }

  void groupStartDragging(String groupId) {
    phantomState.setGroupIsDragging(groupId, true);
  }

  /// Remove the phantom in the group when the group is end dragging.
  void groupEndDragging(String groupId) {
    phantomState.setGroupIsDragging(groupId, false);
    if (phantomRecord == null) return;

    final fromGroupId = phantomRecord!.fromGroupId;
    final toGroupId = phantomRecord!.toGroupId;
    final item = phantomRecord!.item;
    if (fromGroupId == groupId) {
      phantomState.notifyDidRemovePhantom(toGroupId);
    }

    if (phantomRecord!.toGroupId == groupId) {
      delegate.moveGroupItemToAnotherGroup(
        fromGroupId,
        phantomRecord!.fromGroupIndex,
        toGroupId,
        phantomRecord!.toGroupIndex,
        item,
      );

      Log.debug(
          "[$BoardPhantomController] did move ${phantomRecord.toString()}");
      phantomRecord = null;
    }
  }

  /// Remove the phantom in the group if it contains phantom
  void _removePhantom(String groupId) {
    final didRemove = delegate.removePhantom(groupId);
    if (didRemove) {
      phantomState.notifyDidRemovePhantom(groupId);
      phantomState.removeGroupListener(groupId);
    }
  }

  void _insertPhantom(
    String toGroupId,
    FlexDragTargetData dragTargetData,
    int phantomIndex,
  ) {
    final phantomContext = PassthroughPhantomContext(
      index: phantomIndex,
      dragTargetData: dragTargetData,
    );
    phantomState.addGroupListener(toGroupId, phantomContext);

    delegate.insertPhantom(
      toGroupId,
      phantomIndex,
      PhantomGroupItem(phantomContext),
    );

    phantomState.notifyDidInsertPhantom(toGroupId, phantomIndex);
  }

  /// Reset or initial the [PhantomRecord]
  ///
  ///
  /// * [groupId] the id of the group
  /// * [dragTargetData]
  /// * [dragTargetIndex]
  ///
  void _resetPhantomRecord(
    String groupId,
    FlexDragTargetData dragTargetData,
    int dragTargetIndex,
  ) {
    // Log.debug(
    //     '[$BoardPhantomController] move Group:[${dragTargetData.reorderFlexId}]:${dragTargetData.draggingIndex} '
    //     'to Group:[$groupId]:$dragTargetIndex');

    phantomRecord = PhantomRecord(
      toGroupId: groupId,
      toGroupIndex: dragTargetIndex,
      fromGroupId: dragTargetData.reorderFlexId,
      fromGroupIndex: dragTargetData.draggingIndex,
      item: dragTargetData.reorderFlexItem,
    );
    Log.debug('[$BoardPhantomController] will move: $phantomRecord');
  }

  @override
  bool acceptNewDragTargetData(
    String reorderFlexId,
    FlexDragTargetData dragTargetData,
    int dragTargetIndex,
  ) {
    if (phantomRecord == null) {
      _resetPhantomRecord(reorderFlexId, dragTargetData, dragTargetIndex);
      _insertPhantom(reorderFlexId, dragTargetData, dragTargetIndex);

      return true;
    }

    final isNewDragTarget = phantomRecord!.toGroupId != reorderFlexId;
    if (isNewDragTarget) {
      /// Remove the phantom when the dragTarget is moved from one group to another group.
      _removePhantom(phantomRecord!.toGroupId);
      _resetPhantomRecord(reorderFlexId, dragTargetData, dragTargetIndex);
      _insertPhantom(reorderFlexId, dragTargetData, dragTargetIndex);
    }

    return isNewDragTarget;
  }

  @override
  void updateDragTargetData(
    String reorderFlexId,
    int dragTargetIndex,
  ) {
    phantomRecord?.updateInsertedIndex(dragTargetIndex);

    assert(phantomRecord != null);
    if (phantomRecord!.toGroupId == reorderFlexId) {
      /// Update the existing phantom index
      delegate.updatePhantom(phantomRecord!.toGroupId, dragTargetIndex);
    }
  }

  @override
  void cancel() {
    if (phantomRecord == null) {
      return;
    }

    /// Remove the phantom when the dragTarge is go back to the original group.
    _removePhantom(phantomRecord!.toGroupId);
    phantomRecord = null;
  }

  @override
  void dragTargetDidMoveToReorderFlex(
    String reorderFlexId,
    FlexDragTargetData dragTargetData,
    int dragTargetIndex,
  ) {
    // Memoizing the current reorderFlexId to avoid redundant operations
    if (_lastReorderFlexId == reorderFlexId &&
        _lastDragTargetIndex == dragTargetIndex &&
        dragTargetData.reorderFlexId == _lastSourceFlexId) {
      return;
    }

    _lastReorderFlexId = reorderFlexId;
    _lastDragTargetIndex = dragTargetIndex;
    _lastSourceFlexId = dragTargetData.reorderFlexId;

    acceptNewDragTargetData(
      reorderFlexId,
      dragTargetData,
      dragTargetIndex,
    );
  }

  // Memoization variables to reduce redundant operations
  String? _lastReorderFlexId;
  int? _lastDragTargetIndex;
  String? _lastSourceFlexId;

  @override
  int getInsertedIndex(String dragTargetId) {
    if (phantomState.isDragging(dragTargetId)) {
      return -1;
    }

    final controller = delegate.controller(dragTargetId);
    if (controller != null) {
      return controller.groupData.items.length;
    }

    return 0;
  }
}

/// Use [PhantomRecord] to record where to remove the group item and where to
/// insert the group item.
///
/// [fromGroupId] the group that phantom comes from
/// [fromGroupIndex] the index of the phantom from the original group
/// [toGroupId] the group that the phantom moves into
/// [toGroupIndex] the index of the phantom moves into the group
///
class PhantomRecord<T> {
  PhantomRecord({
    required this.toGroupId,
    required this.toGroupIndex,
    required this.fromGroupId,
    required this.fromGroupIndex,
    required this.item,
  });

  final String toGroupId;
  int toGroupIndex;
  final String fromGroupId;
  int fromGroupIndex;
  final T item;

  void updateFromGroupIndex(int index) => fromGroupIndex = index;

  void updateInsertedIndex(int index) {
    if (toGroupIndex == index) {
      return;
    }

    Log.debug(
      '[$PhantomRecord] Group:[$toGroupId] update position $toGroupIndex -> $index',
    );
    toGroupIndex = index;
  }

  @override
  String toString() =>
      'Group:[$fromGroupId]:$fromGroupIndex to Group:[$toGroupId]:$toGroupIndex';
}

class PhantomGroupItem extends AATexGroupItem {
  PhantomGroupItem(PassthroughPhantomContext insertedPhantom)
      : phantomContext = insertedPhantom;

  final PassthroughPhantomContext phantomContext;

  @override
  bool get isPhantom => true;

  @override
  String get id => phantomContext.itemData.id;

  Size? get feedbackSize => phantomContext.feedbackSize;

  Widget get draggingWidget => phantomContext.draggingWidget == null
      ? const SizedBox()
      : phantomContext.draggingWidget!;

  @override
  String toString() => 'phantom:$id';
}

class PassthroughPhantomContext extends FakeDragTargetEventTrigger
    implements FakeDragTargetEventData, PassthroughPhantomListener {
  PassthroughPhantomContext({
    required this.index,
    required this.dragTargetData,
  });

  @override
  int index;

  @override
  final FlexDragTargetData dragTargetData;

  @override
  Size? get feedbackSize => dragTargetData.feedbackSize;

  Widget? get draggingWidget => dragTargetData.draggingWidget;

  AATexGroupItem get itemData =>
      dragTargetData.reorderFlexItem as AATexGroupItem;

  @override
  void Function(int?)? onInserted;

  @override
  VoidCallback? onDragEnded;

  @override
  void fakeOnDragEnded(VoidCallback callback) {
    onDragEnded = callback;
  }

  @override
  void fakeOnDragStart(void Function(int? index) callback) {
    onInserted = callback;
  }
}

class PassthroughPhantomWidget extends PhantomWidget {
  PassthroughPhantomWidget({
    super.key,
    required super.opacity,
    required this.passthroughPhantomContext,
  }) : super(child: passthroughPhantomContext.draggingWidget);

  final PassthroughPhantomContext passthroughPhantomContext;
}

class PhantomDraggableBuilder extends ReorderFlexDraggableTargetBuilder {
  PhantomDraggableBuilder();
  @override
  Widget? build<T extends DragTargetData>(
    BuildContext context,
    Widget child,
    DragTargetOnStarted onDragStarted,
    DragTargetOnEnded<T> onDragEnded,
    DragTargetWillAccepted<T> onWillAccept,
    AnimationController insertAnimationController,
    AnimationController deleteAnimationController,
  ) {
    if (child is PassthroughPhantomWidget) {
      return FakeDragTarget<T>(
        eventTrigger: child.passthroughPhantomContext,
        eventData: child.passthroughPhantomContext,
        onDragStarted: onDragStarted,
        onDragEnded: onDragEnded,
        onWillAccept: onWillAccept,
        insertAnimationController: insertAnimationController,
        deleteAnimationController: deleteAnimationController,
        child: child,
      );
    }

    return null;
  }
}
