import 'package:aatex_board/aatex_board.dart';
import 'package:flutter/material.dart';

class SingleBoardListExample extends StatefulWidget {
  const SingleBoardListExample({super.key});

  @override
  State<SingleBoardListExample> createState() => _SingleBoardListExampleState();
}

class _SingleBoardListExampleState extends State<SingleBoardListExample> {
  final AATexBoardController boardData = AATexBoardController();

  @override
  void initState() {
    super.initState();

    // Create 10 columns with 50 items each
    for (int colIndex = 1; colIndex <= 10; colIndex++) {
      final List<AATexGroupItem> items = [];

      // Add 50 items to each column
      for (int itemIndex = 1; itemIndex <= 50; itemIndex++) {
        // Create unique IDs for each item
        final itemId = "item_${colIndex}_$itemIndex";
        items.add(TextItem(itemId));
      }

      final column = AATexGroupData(id: "column_$colIndex", name: "Column $colIndex", items: items);

      boardData.addGroup(column);
    }
  }

  void _showCard() {
    // Display card #43 in column 8
    boardData.displayCard(groupId: "column_8", itemId: "item_8_43", highlightColor: Colors.amber.withOpacity(0.5));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AATexBoard Example'),
        actions: [
          // Button to trigger highlighting card in column 8, item #43
          ElevatedButton(onPressed: _showCard, child: const Text('Find card 8-43')),
        ],
      ),
      body: AATexBoard(
        controller: boardData,
        cardBuilder: (context, column, columnItem) {
          return _RowWidget(item: columnItem as TextItem, key: ObjectKey(columnItem));
        },
      ),
    );
  }
}

class _RowWidget extends StatelessWidget {
  final TextItem item;
  const _RowWidget({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // Check if this item is active, show highlight if it is
    final isActive = (item as ActiveableGroupItem).isActive;
    final highlightColor = (item as ActiveableGroupItem).highlightColor;
    final highlightBorder = (item as ActiveableGroupItem).highlightBorder;

    // Создаем decoration с рамкой, если элемент активен
    BoxDecoration decoration = BoxDecoration(
      color: isActive ? (highlightColor ?? Colors.blue.withOpacity(0.3)) : Colors.green,
    );

    // Добавляем рамку для активного элемента
    if (isActive && highlightBorder != null) {
      decoration = BoxDecoration(
        color: isActive ? (highlightColor ?? Colors.blue.withOpacity(0.3)) : Colors.green,
        border: Border(top: highlightBorder, left: highlightBorder, right: highlightBorder, bottom: highlightBorder),
        borderRadius: BorderRadius.circular(4),
      );
    }

    return Container(
      key: ObjectKey(item),
      height: 60,
      decoration: decoration,
      child: Center(
        child: Text(
          item.s,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}

// Update TextItem to implement ActiveableGroupItem to support highlighting
class TextItem extends AATexGroupItem implements ActiveableGroupItem {
  final String s;
  final bool _isActive;
  final Color? _highlightColor;
  final BorderSide? _highlightBorder;

  TextItem(this.s, {bool isActive = false, Color? highlightColor, BorderSide? highlightBorder})
    : _isActive = isActive,
      _highlightColor = highlightColor,
      _highlightBorder = highlightBorder;

  @override
  String get id => s;

  @override
  bool get isActive => _isActive;

  @override
  Color? get highlightColor => _highlightColor;

  @override
  BorderSide? get highlightBorder => _highlightBorder;

  @override
  TextItem copyWith({bool? isActive, Color? highlightColor, BorderSide? highlightBorder}) {
    return TextItem(
      s,
      isActive: isActive ?? _isActive,
      highlightColor: highlightColor ?? _highlightColor,
      highlightBorder: highlightBorder ?? _highlightBorder,
    );
  }
}
