import 'package:aatex_board/aatex_board.dart';
import 'package:aatex_board/src/utils/log.dart';
import 'package:flutter/material.dart';

class AATexBoardScrollController {
  AATexBoardState? _boardState;

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

    // Ищем ключ для колонки непосредственно среди ключей, а не их содержимого
    final columnKeys = _boardState!.groupDragTargetKeys.keys.toList();
    Log.debug(
        '[scrollToGroup] Available column keys: ${columnKeys.join(', ')}');

    // Получаем контекст родительского контейнера этой колонки через элемент в этой колонке
    BuildContext? targetContext;
    if (columnKeys.contains(groupId)) {
      Log.debug('[scrollToGroup] Found direct key for groupId=$groupId');

      // Получаем первую карточку в нужной колонке для получения её контекста
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

    // Если не нашли контекст в целевой колонке, ищем любой контекст для коллбэка
    if (targetContext == null) {
      Log.warn(
          '[scrollToGroup] No direct context found in target column, searching other columns...');

      // Попробуем найти колонку используя ValueKey
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

      // Если всё еще не нашли контекст, берем любой доступный
      if (targetContext == null) {
        targetContext = _getAnyAvailableContext();
        if (targetContext == null) {
          Log.error(
              '[scrollToGroup] No valid context found for callback, aborting');
          return;
        }
      }
    }

    // Находим виджет колонки через родительский контекст
    Element? columnElement;
    targetContext!.visitAncestorElements((element) {
      if (element.widget.key is ValueKey &&
          (element.widget.key as ValueKey).value == groupId) {
        columnElement = element;
        return false; // прекращаем поиск
      }
      return true; // продолжаем поиск
    });

    if (columnElement == null) {
      Log.warn(
          '[scrollToGroup] Could not find column element with key=$groupId, searching by widget type');
      // Если не нашли по ключу, пробуем найти по типу виджета и данным
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

    // Получаем ScrollController для горизонтальной прокрутки
    final scrollController = _boardState!.horizontalScrollController;
    if (scrollController == null || !scrollController.hasClients) {
      Log.warn('[scrollToGroup] ScrollController is null or has no clients');
      if (completed != null) {
        completed(targetContext);
      }
      return;
    }

    // Прокручиваем к группе
    final RenderBox box = columnElement!.renderObject as RenderBox;
    final position = box.localToGlobal(Offset.zero);

    // Размеры и позиции
    final screenWidth = WidgetsBinding.instance.window.physicalSize.width /
        WidgetsBinding.instance.window.devicePixelRatio;
    final groupWidth = box.size.width;
    Log.debug(
        '[scrollToGroup] Group position: dx=${position.dx}, dy=${position.dy}');
    Log.debug(
        '[scrollToGroup] Screen width: $screenWidth, Group width: $groupWidth');

    // Пытаемся центрировать колонку на экране
    final targetOffset = position.dx - (screenWidth / 2) + (groupWidth / 2);
    Log.debug(
        '[scrollToGroup] Current scroll position: ${scrollController.position.pixels}');
    Log.debug('[scrollToGroup] Target offset before clamping: $targetOffset');

    // Убеждаемся, что не прокручиваем за пределы диапазона
    final clampedOffset = targetOffset.clamp(
        scrollController.position.minScrollExtent,
        scrollController.position.maxScrollExtent);
    Log.debug(
        '[scrollToGroup] Final clamped offset for scrolling: $clampedOffset');

    // Если уже находимся на нужной позиции или очень близко, не прокручиваем
    if ((scrollController.position.pixels - clampedOffset).abs() < 5.0) {
      Log.debug(
          '[scrollToGroup] Already at target position, no need to scroll');
      if (completed != null) {
        completed(targetContext);
      }
      return;
    }

    // Выполняем прокрутку
    Log.debug('[scrollToGroup] Animating to offset: $clampedOffset');

    // Сохраняем ссылку на текущий контекст, пока он действителен
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
        // Вызываем коллбэк только если контекст не null
        completed(contextToUse);
      } else if (completed != null) {
        // Если контекст стал null, найдем новый контекст
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
        // В случае ошибки пытаемся получить актуальный контекст
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

  /// Вспомогательный метод для получения любого доступного контекста
  BuildContext? _getAnyAvailableContext() {
    if (_boardState == null) return null;

    // Пытаемся найти любой доступный контекст из драг-таргетов
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
