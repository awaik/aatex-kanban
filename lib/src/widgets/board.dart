import 'package:aatex_board/src/controllers/board_scroll_controller.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../rendering/board_overlay.dart';
import '../utils/log.dart';

import '../controllers/board_controller.dart';
import 'board_group/group.dart';
import 'board_group/group_data.dart';
import 'reorder_flex/drag_state.dart';
import 'reorder_flex/drag_target_interceptor.dart';
import 'reorder_flex/reorder_flex.dart';
import 'reorder_phantom/phantom_controller.dart';

class AATexBoardConfig {
  const AATexBoardConfig.config({
    this.boardCornerRadius = 6.0,
    this.groupCornerRadius = 6.0,
    this.groupBackgroundColor = Colors.transparent,
    this.groupMargin = const EdgeInsets.symmetric(horizontal: 8),
    this.groupHeaderPadding = const EdgeInsets.symmetric(horizontal: 16),
    this.groupBodyPadding = const EdgeInsets.symmetric(horizontal: 12),
    this.groupFooterPadding = const EdgeInsets.symmetric(horizontal: 12),
    this.stretchGroupHeight = true,
    this.cardMargin = const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
  });

  // board
  final double boardCornerRadius;

  // group
  final double groupCornerRadius;
  final Color groupBackgroundColor;
  final EdgeInsets groupMargin;
  final EdgeInsets groupHeaderPadding;
  final EdgeInsets groupBodyPadding;
  final EdgeInsets groupFooterPadding;
  final bool stretchGroupHeight;

  // card
  final EdgeInsets cardMargin;
}

class AATexBoard extends StatelessWidget {
  const AATexBoard({
    super.key,
    required this.controller,
    required this.cardBuilder,
    this.headerBuilder,
    this.footerBuilder,
    this.background,
    this.groupConstraints = const BoxConstraints(maxWidth: 200),
    this.scrollController,
    this.config = const AATexBoardConfig.config(),
    this.boardScrollController,
    this.leading,
    this.trailing,
  });

  /// A controller for [AATexBoard] widget.
  ///
  /// A [AATexBoardController] can be used to provide an initial value of
  /// the board by calling `addGroup` method with the passed in parameter
  /// [AATexGroupData]. A [AATexGroupData] represents one
  /// group data. Whenever the user modifies the board, this controller will
  /// update the corresponding group data.
  ///
  /// Also, you can register the callbacks that receive the changes. Check out
  /// the [AATexBoardController] for more information.
  ///
  final AATexBoardController controller;

  /// The widget that will be rendered as the background of the board.
  final Widget? background;

  /// The [cardBuilder] function which will be invoked on each card build.
  /// The [cardBuilder] takes the [BuildContext],[AATexGroupData] and
  /// the corresponding [AATexGroupItem].
  ///
  /// must return a widget.
  final AATexBoardCardBuilder cardBuilder;

  /// The [headerBuilder] function which will be invoked on each group build.
  /// The [headerBuilder] takes the [BuildContext] and [AATexGroupData].
  ///
  /// must return a widget.
  final AATexBoardHeaderBuilder? headerBuilder;

  /// The [footerBuilder] function which will be invoked on each group build.
  /// The [footerBuilder] takes the [BuildContext] and [AATexGroupData].
  ///
  /// must return a widget.
  final AATexBoardFooterBuilder? footerBuilder;

  /// A constraints applied to [AAtexBoardGroup] widget.
  final BoxConstraints groupConstraints;

  /// A controller is used by the [ReorderFlex].
  ///
  /// The [ReorderFlex] will used the primary scrollController of the current
  /// [BuildContext] by using PrimaryScrollController.of(context).
  /// If the primary scrollController is null, we will assign a new [ScrollController].
  final ScrollController? scrollController;

  ///
  final AATexBoardConfig config;

  /// A controller is used to control each group scroll actions.
  ///
  final AATexBoardScrollController? boardScrollController;

  /// A widget that is shown before the first group in the Board
  ///
  final Widget? leading;

  /// A widget that is shown after the last group in the Board
  ///
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: Consumer<AATexBoardController>(
        builder: (context, notifier, child) {
          // Create a new state only if it doesn't exist yet or preserve the existing one
          final boardState =
              boardScrollController?.boardState ?? AATexBoardState();
          final phantomController = BoardPhantomController(
            delegate: controller,
            groupsState: boardState,
          );

          // Save the state in the controller to preserve it between rebuilds
          if (boardScrollController != null) {
            boardScrollController!.setBoardState(boardState);
          }

          return _AATexBoardContent(
            config: config,
            boardController: controller,
            scrollController: scrollController,
            scrollManager: boardScrollController,
            boardState: boardState,
            background: background,
            delegate: phantomController,
            groupConstraints: groupConstraints,
            cardBuilder: cardBuilder,
            footerBuilder: footerBuilder,
            headerBuilder: headerBuilder,
            phantomController: phantomController,
            onReorder: controller.moveGroup,
            leading: leading,
            trailing: trailing,
          );
        },
      ),
    );
  }
}

class _AATexBoardContent extends StatefulWidget {
  const _AATexBoardContent({
    required this.config,
    required this.onReorder,
    required this.delegate,
    required this.boardController,
    required this.scrollManager,
    required this.boardState,
    required this.groupConstraints,
    required this.cardBuilder,
    required this.phantomController,
    this.leading,
    this.trailing,
    this.scrollController,
    this.background,
    this.headerBuilder,
    this.footerBuilder,
  }) : reorderFlexConfig = const ReorderFlexConfig(
          direction: Axis.horizontal,
          dragDirection: Axis.horizontal,
        );

  final AATexBoardConfig config;
  final OnReorder onReorder;
  final OverlapDragTargetDelegate delegate;
  final AATexBoardController boardController;
  final AATexBoardScrollController? scrollManager;
  final AATexBoardState boardState;
  final BoxConstraints groupConstraints;
  final AATexBoardCardBuilder cardBuilder;
  final BoardPhantomController phantomController;
  final Widget? leading;
  final Widget? trailing;
  final ScrollController? scrollController;
  final Widget? background;
  final AATexBoardHeaderBuilder? headerBuilder;
  final AATexBoardFooterBuilder? footerBuilder;
  final ReorderFlexConfig reorderFlexConfig;

  @override
  State<_AATexBoardContent> createState() => _AATexBoardContentState();
}

class _AATexBoardContentState extends State<_AATexBoardContent> {
  final GlobalKey _boardContentKey =
      GlobalKey(debugLabel: '$_AATexBoardContent overlay key');
  late BoardOverlayEntry _overlayEntry;
  late final _scrollController = widget.scrollController ?? ScrollController();

  @override
  void initState() {
    super.initState();

    // Save a reference to the scroll controller in boardState for use in scrollToGroup
    widget.boardState.horizontalScrollController = _scrollController;

    _overlayEntry = BoardOverlayEntry(
      builder: (context) => Stack(
        children: [
          if (widget.background != null)
            Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(widget.config.boardCornerRadius),
              ),
              child: widget.background,
            ),

          ///
          ///TODO:  awaik - implement a scrollbar
          ///
          Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: widget.reorderFlexConfig.direction,
              controller: _scrollController,
              child: ReorderFlex(
                config: widget.reorderFlexConfig,
                scrollController: _scrollController,
                onReorder: widget.onReorder,
                dataSource: widget.boardController,
                autoScroll: true,
                interceptor: OverlappingDragTargetInterceptor(
                  reorderFlexId: widget.boardController.identifier,
                  acceptedReorderFlexId: widget.boardController.groupIds,
                  delegate: widget.delegate,
                  columnsState: widget.boardState,
                ),
                leading: widget.leading,
                trailing: widget.trailing,
                children: _buildColumns(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BoardOverlay(
        key: _boardContentKey,
        initialEntries: [_overlayEntry],
      );

  List<Widget> _buildColumns() {
    final List<Widget> children = [];

    // Create a list of column widgets
    final columnWidgets =
        widget.boardController.groupDatas.asMap().entries.map((item) {
      final columnData = item.value;
      final columnIndex = item.key;

      final dataSource = _BoardGroupDataSourceImpl(
        groupId: columnData.id,
        boardController: widget.boardController,
      );

      final reorderFlexAction = ReorderFlexActionImpl();
      widget.boardState.reorderFlexActionMap[columnData.id] = reorderFlexAction;

      return ChangeNotifierProvider.value(
        key: ValueKey(columnData.id),
        value: widget.boardController.getGroupController(columnData.id),
        child: Consumer<AATexGroupController>(
          builder: (context, value, child) => ConstrainedBox(
            constraints: widget.groupConstraints,
            child: AAtexBoardGroup(
              margin: _marginFromIndex(columnIndex),
              bodyPadding: widget.config.groupBodyPadding,
              headerBuilder: _buildHeader,
              footerBuilder: widget.footerBuilder,
              cardBuilder: widget.cardBuilder,
              dataSource: dataSource,
              scrollController: ScrollController(),
              phantomController: widget.phantomController,
              onReorder: widget.boardController.moveGroupItem,
              cornerRadius: widget.config.groupCornerRadius,
              backgroundColor: widget.config.groupBackgroundColor,
              dragStateStorage: widget.boardState,
              dragTargetKeys: widget.boardState,
              reorderFlexAction: reorderFlexAction,
              stretchGroupHeight: widget.config.stretchGroupHeight,
              onDragStarted: (index) {
                widget.boardController.onStartDraggingCard
                    ?.call(columnData.id, index);
              },
            ),
          ),
        ),
      );
    }).toList();

    // Add widgets to the children list
    children.addAll(columnWidgets);

    // Add a function to save references to elements after building
    // This is needed for the scrollToGroup method
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Clear previous elements
      widget.boardState.boardContentChildren.clear();

      // For each element with a key, find it in the element tree
      for (final columnData in widget.boardController.groupDatas) {
        final columnKey = ValueKey(columnData.id);
        // Use context to find the element by key
        Element? element;
        void findElementWithKey(Element e) {
          if (e.widget.key == columnKey) {
            element = e;
            return;
          }
          e.visitChildren(findElementWithKey);
        }

        context.visitChildElements(findElementWithKey);

        if (element != null) {
          widget.boardState.boardContentChildren.add(element!);
          Log.debug(
              '[_buildColumns] Saved column element with key: ${columnData.id}');
        }
      }

      Log.debug(
          '[_buildColumns] Total column elements saved: ${widget.boardState.boardContentChildren.length}');
    });

    return children;
  }

  Widget? _buildHeader(BuildContext context, AATexGroupData groupData) {
    if (widget.headerBuilder == null) {
      return null;
    }
    return Selector<AATexGroupController, AATexGroupHeaderData>(
      selector: (context, controller) => controller.groupData.headerData,
      builder: (context, _, __) => widget.headerBuilder!(context, groupData)!,
    );
  }

  EdgeInsets _marginFromIndex(int index) {
    if (widget.boardController.groupDatas.isEmpty) {
      return widget.config.groupMargin;
    }

    if (index == 0) {
      // remove the left padding of the first group
      return widget.config.groupMargin.copyWith(left: 0);
    }

    if (index == widget.boardController.groupDatas.length - 1) {
      // remove the right padding of the last group
      return widget.config.groupMargin.copyWith(right: 0);
    }

    return widget.config.groupMargin;
  }
}

class _BoardGroupDataSourceImpl extends AATexGroupDataDataSource {
  _BoardGroupDataSourceImpl({
    required this.groupId,
    required this.boardController,
  });

  final String groupId;
  final AATexBoardController boardController;

  @override
  AATexGroupData get groupData =>
      boardController.getGroupController(groupId)!.groupData;

  @override
  List<String> get acceptedGroupIds => boardController.groupIds;
}

class AATexBoardState extends DraggingStateStorage
    implements ReorderDragTargetKeys {
  final Map<String, DraggingState> groupDragStates = {};
  final Map<String, Map<String, GlobalObjectKey>> groupDragTargetKeys = {};

  /// Quick access to the [AAtexBoardGroup], the [GlobalKey] is bind to the
  /// AATexBoardGroup's [ReorderFlex] widget.
  final Map<String, ReorderFlexActionImpl> reorderFlexActionMap = {};

  /// The scroll controller for the main horizontal scrolling of groups
  ScrollController? horizontalScrollController;

  /// Store references to column widgets for easier access
  List<Element> boardContentChildren = [];

  @override
  DraggingState? readState(String reorderFlexId) =>
      groupDragStates[reorderFlexId];

  @override
  void insertState(String reorderFlexId, DraggingState state) {
    Log.trace('$reorderFlexId Write dragging state: $state');
    groupDragStates[reorderFlexId] = state;
  }

  @override
  void removeState(String reorderFlexId) {
    groupDragStates.remove(reorderFlexId);
  }

  @override
  void insertDragTarget(
    String reorderFlexId,
    String key,
    GlobalObjectKey<State<StatefulWidget>> value,
  ) {
    Map<String, GlobalObjectKey>? group = groupDragTargetKeys[reorderFlexId];
    if (group == null) {
      group = {};
      groupDragTargetKeys[reorderFlexId] = group;
    }
    group[key] = value;
  }

  @override
  GlobalObjectKey<State<StatefulWidget>>? getDragTarget(
    String reorderFlexId,
    String key,
  ) {
    final Map<String, GlobalObjectKey>? group =
        groupDragTargetKeys[reorderFlexId];
    if (group != null) {
      return group[key];
    }

    return null;
  }

  @override
  void removeDragTarget(String reorderFlexId) {
    groupDragTargetKeys.remove(reorderFlexId);
  }
}

class ReorderFlexActionImpl extends ReorderFlexAction {}
