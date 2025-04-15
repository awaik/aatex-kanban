import 'package:aatex_board/aatex_board.dart';
import 'package:aatex_board/src/utils/log.dart';
import 'package:flutter/material.dart';

class AATexBoardScrollController {
  AATexBoardState? _boardState;

  /// Returns the current board state if it exists
  AATexBoardState? get boardState => _boardState;

  /// Sets the board state - used internally by AATexBoard
  void setBoardState(AATexBoardState state) {
    _boardState = state;
  }

  /// Scrolls the board horizontally to make the specified group visible, preferably in the center
  void scrollToGroup(
    String groupId, {
    void Function(BuildContext)? completed,
  }) {
    Log.debug(
        '[scrollToGroup] START - attempting to scroll to groupId=$groupId');

    if (_boardState == null) {
      Log.warn('[scrollToGroup] _boardState is null');
      if (completed != null) {
        final context = _getAnyAvailableContext();
        if (context != null) {
          completed(context);
        }
      }
      return;
    }

    // Look for the column key directly among the keys, not their content
    final columnKeys = _boardState!.groupDragTargetKeys.keys.toList();
    Log.debug(
        '[scrollToGroup] Available column keys: ${columnKeys.join(', ')}');

    // Get the context of the parent container of this column through an element in this column
    BuildContext? targetContext;
    if (columnKeys.contains(groupId)) {
      Log.debug('[scrollToGroup] Found direct key for groupId=$groupId');

      // Get the first card in the needed column to obtain its context
      final cardKeys = _boardState!.groupDragTargetKeys[groupId]?.values;
      if (cardKeys != null && cardKeys.isNotEmpty) {
        for (final cardKey in cardKeys) {
          if (cardKey.currentContext != null) {
            targetContext = cardKey.currentContext;
            break;
          }
        }
      }
    }

    // If we didn't find a context in the target column, we're looking for any context for the callback
    if (targetContext == null) {
      Log.warn(
          '[scrollToGroup] No direct context found in target column, searching other columns...');

      // Let's try to find the column using ValueKey
      for (final child in _boardState!.boardContentChildren) {
        if (child.widget.key is ValueKey &&
            (child.widget.key as ValueKey).value == groupId) {
          Log.debug(
              '[scrollToGroup] Found column widget with ValueKey=$groupId');
          if (child is StatefulElement || child is StatelessElement) {
            targetContext = child;
            break;
          }
        }
      }

      // If we still haven't found a context, we take any available one
      if (targetContext == null) {
        targetContext = _getAnyAvailableContext();
        if (targetContext == null) {
          Log.error(
              '[scrollToGroup] No valid context found for callback, aborting');
          return;
        }
      }
    }

    // Find the column widget through the parent context
    Element? columnElement;
    targetContext!.visitAncestorElements((element) {
      if (element.widget.key is ValueKey &&
          (element.widget.key as ValueKey).value == groupId) {
        columnElement = element;
        return false; // stop the search
      }
      return true; // continue searching
    });

    if (columnElement == null) {
      Log.warn(
          '[scrollToGroup] Could not find column element with key=$groupId, searching by widget type');
      // If we didn't find by key, try to find by widget type and data
      targetContext.visitAncestorElements((element) {
        if (element.widget is ConstrainedBox &&
            element.toString().contains(groupId)) {
          columnElement = element;
          return false;
        }
        return true;
      });
    }

    if (columnElement == null) {
      Log.error(
          '[scrollToGroup] Column element not found, falling back to child context');
      columnElement = targetContext as Element;
    }

    // Get ScrollController for horizontal scrolling
    final scrollController = _boardState!.horizontalScrollController;
    if (scrollController == null || !scrollController.hasClients) {
      Log.warn('[scrollToGroup] ScrollController is null or has no clients');
      if (completed != null) {
        completed(targetContext);
      }
      return;
    }

    // Scroll to the group
    final RenderBox box = columnElement!.renderObject as RenderBox;
    final position = box.localToGlobal(Offset.zero);

    // Dimensions and positions
    final screenWidth = WidgetsBinding.instance.window.physicalSize.width /
        WidgetsBinding.instance.window.devicePixelRatio;
    final groupWidth = box.size.width;
    Log.debug(
        '[scrollToGroup] Group position: dx=${position.dx}, dy=${position.dy}');
    Log.debug(
        '[scrollToGroup] Screen width: $screenWidth, Group width: $groupWidth');

    // Try to center the column on the screen
    final targetOffset = position.dx - (screenWidth / 2) + (groupWidth / 2);
    Log.debug(
        '[scrollToGroup] Current scroll position: ${scrollController.position.pixels}');
    Log.debug('[scrollToGroup] Target offset before clamping: $targetOffset');

    // Make sure we don't scroll beyond the range
    final clampedOffset = targetOffset.clamp(
        scrollController.position.minScrollExtent,
        scrollController.position.maxScrollExtent);
    Log.debug(
        '[scrollToGroup] Final clamped offset for scrolling: $clampedOffset');

    // If we're already at the right position or very close, don't scroll
    if ((scrollController.position.pixels - clampedOffset).abs() < 5.0) {
      Log.debug(
          '[scrollToGroup] Already at target position, no need to scroll');
      if (completed != null) {
        completed(targetContext);
      }
      return;
    }

    // Perform scrolling
    Log.debug('[scrollToGroup] Animating to offset: $clampedOffset');

    // Save a reference to the current context while it's valid
    final contextToUse = targetContext;

    scrollController
        .animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    )
        .then((_) {
      Log.debug('[scrollToGroup] Scroll animation completed');
      if (completed != null && contextToUse != null) {
        // Call the callback only if the context is not null
        completed(contextToUse);
      } else if (completed != null) {
        // If the context became null, let's find a new context
        final newContext = _getAnyAvailableContext();
        if (newContext != null) {
          completed(newContext);
        } else {
          Log.warn(
              '[scrollToGroup] Cannot call completed: no valid context available after animation');
        }
      }
    }).catchError((error) {
      Log.error('[scrollToGroup] Error during scroll animation: $error');
      if (completed != null) {
        // In case of error, try to get an up-to-date context
        final errorContext = _getAnyAvailableContext();
        if (errorContext != null) {
          completed(errorContext);
        } else {
          Log.warn(
              '[scrollToGroup] Cannot call completed after error: no valid context available');
        }
      }
    });
  }

  /// Helper method for getting any available context
  BuildContext? _getAnyAvailableContext() {
    if (_boardState == null) return null;

    // Try to find any available context from drag targets
    for (final groupKeys in _boardState!.groupDragTargetKeys.values) {
      for (final key in groupKeys.values) {
        if (key.currentContext != null) {
          return key.currentContext!;
        }
      }
    }
    return null;
  }

  void scrollToBottom(
    String groupId, {
    void Function(BuildContext)? completed,
  }) {
    _boardState?.reorderFlexActionMap[groupId]?.scrollToBottom(completed);
  }

  void scrollToItem(
    String groupId,
    int index, {
    void Function(BuildContext)? completed,
  }) {
    _boardState?.reorderFlexActionMap[groupId]?.scrollToItem(index, completed);
  }
}
