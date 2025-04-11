import 'dart:collection';

import 'package:flutter/material.dart';

import 'package:aatex_board/src/widgets/reorder_flex/drag_state.dart';

import '../../rendering/board_overlay.dart';
import '../../utils/log.dart';
import '../reorder_flex/drag_target_interceptor.dart';
import '../reorder_flex/reorder_flex.dart';
import '../reorder_phantom/phantom_controller.dart';

import 'group_data.dart';

typedef OnGroupDragStarted = void Function(int index);

typedef OnGroupDragEnded = void Function(String groupId);

typedef OnGroupReorder = void Function<T>(
  String groupId,
  int fromIndex,
  int toIndex,
  T item,
);

typedef AATexBoardCardBuilder = Widget Function(
  BuildContext context,
  AATexGroupData groupData,
  AATexGroupItem item,
);

typedef AATexBoardHeaderBuilder = Widget? Function(
  BuildContext context,
  AATexGroupData groupData,
);

typedef AATexBoardFooterBuilder = Widget Function(
  BuildContext context,
  AATexGroupData groupData,
);

abstract class AATexGroupDataDataSource implements ReoderFlexDataSource {
  AATexGroupData get groupData;

  List<String> get acceptedGroupIds;

  @override
  String get identifier => groupData.id;

  @override
  UnmodifiableListView<AATexGroupItem> get items => groupData.items;

  void debugPrint() {
    String msg = '[$AATexGroupDataDataSource] $groupData data: ';
    for (final element in items) {
      msg = '$msg$element,';
    }

    Log.debug(msg);
  }
}

/// A [AAtexBoardGroup] represents the group UI of the Board.
///
class AAtexBoardGroup extends StatefulWidget {
  const AAtexBoardGroup({
    super.key,
    required this.cardBuilder,
    required this.onReorder,
    required this.dataSource,
    required this.phantomController,
    this.headerBuilder,
    this.footerBuilder,
    this.reorderFlexAction,
    this.dragStateStorage,
    this.dragTargetKeys,
    this.scrollController,
    this.onDragStarted,
    this.onDragEnded,
    this.margin = EdgeInsets.zero,
    this.bodyPadding = EdgeInsets.zero,
    this.cornerRadius = 0.0,
    this.backgroundColor = Colors.transparent,
    this.stretchGroupHeight = true,
  }) : config = const ReorderFlexConfig();

  final AATexBoardCardBuilder cardBuilder;
  final OnGroupReorder onReorder;
  final AATexGroupDataDataSource dataSource;
  final BoardPhantomController phantomController;
  final AATexBoardHeaderBuilder? headerBuilder;
  final AATexBoardFooterBuilder? footerBuilder;
  final ReorderFlexAction? reorderFlexAction;
  final DraggingStateStorage? dragStateStorage;
  final ReorderDragTargetKeys? dragTargetKeys;

  final ScrollController? scrollController;
  final OnGroupDragStarted? onDragStarted;

  final OnGroupDragEnded? onDragEnded;
  final EdgeInsets margin;
  final EdgeInsets bodyPadding;
  final double cornerRadius;
  final Color backgroundColor;
  final bool stretchGroupHeight;
  final ReorderFlexConfig config;

  String get groupId => dataSource.groupData.id;

  @override
  State<AAtexBoardGroup> createState() => _AAtexBoardGroupState();
}

class _AAtexBoardGroupState extends State<AAtexBoardGroup> {
  final GlobalKey _columnOverlayKey = GlobalKey(debugLabel: '$AAtexBoardGroup overlay key');
  late BoardOverlayEntry _overlayEntry;

  @override
  void initState() {
    super.initState();

    _overlayEntry = BoardOverlayEntry(
      builder: (BuildContext context) {
        final children = widget.dataSource.groupData.items.map((item) => _buildWidget(context, item)).toList();

        final header = widget.headerBuilder?.call(context, widget.dataSource.groupData);

        final footer = widget.footerBuilder?.call(context, widget.dataSource.groupData);

        final interceptor = CrossReorderFlexDragTargetInterceptor(
          reorderFlexId: widget.groupId,
          delegate: widget.phantomController,
          acceptedReorderFlexIds: widget.dataSource.acceptedGroupIds,
          draggableTargetBuilder: PhantomDraggableBuilder(),
        );

        final reorderFlex = Flexible(
          fit: widget.stretchGroupHeight ? FlexFit.tight : FlexFit.loose,
          child: Padding(
            padding: widget.bodyPadding,
            child: SingleChildScrollView(
              scrollDirection: widget.config.direction,
              controller: widget.scrollController,
              child: ReorderFlex(
                key: ValueKey(widget.groupId),
                dragStateStorage: widget.dragStateStorage,
                dragTargetKeys: widget.dragTargetKeys,
                scrollController: widget.scrollController,
                config: widget.config,
                onDragStarted: (index) {
                  widget.phantomController.groupStartDragging(widget.groupId);
                  widget.onDragStarted?.call(index);
                },
                onReorder: (fromIndex, toIndex) {
                  if (widget.phantomController.shouldReorder(widget.groupId)) {
                    widget.onReorder(widget.groupId, fromIndex, toIndex, widget.dataSource.groupData.items[fromIndex]);
                    widget.phantomController.updateIndex(fromIndex, toIndex);
                  }
                },
                onDragEnded: () {
                  widget.phantomController.groupEndDragging(widget.groupId);
                  widget.onDragEnded?.call(widget.groupId);
                  widget.dataSource.debugPrint();
                },
                dataSource: widget.dataSource,
                interceptor: interceptor,
                reorderFlexAction: widget.reorderFlexAction,
                children: children,
              ),
            ),
          ),
        );

        return Container(
          margin: widget.margin,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(widget.cornerRadius),
          ),
          child: Flex(
            direction: Axis.vertical,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (header != null) header,
              reorderFlex,
              if (footer != null) footer,
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => BoardOverlay(
        key: _columnOverlayKey,
        initialEntries: [_overlayEntry],
      );

  Widget _buildWidget(BuildContext context, AATexGroupItem item) {
    if (item is PhantomGroupItem) {
      return PassthroughPhantomWidget(
        key: UniqueKey(),
        opacity: widget.config.draggingWidgetOpacity,
        passthroughPhantomContext: item.phantomContext,
      );
    }

    return widget.cardBuilder(context, widget.dataSource.groupData, item);
  }
}
