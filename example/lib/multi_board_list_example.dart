import 'package:aatex_board/aatex_board.dart';
import 'package:flutter/material.dart';

class MultiBoardListExample extends StatefulWidget {
  const MultiBoardListExample({Key? key}) : super(key: key);

  @override
  State<MultiBoardListExample> createState() => _MultiBoardListExampleState();
}

class _MultiBoardListExampleState extends State<MultiBoardListExample> {
  final AATexBoardController controller = AATexBoardController(
    onMoveGroup: (fromGroupId, fromIndex, toGroupId, toIndex) {
      debugPrint('Move item from $fromIndex to $toIndex');
    },
    onMoveGroupItem: <T>(groupId, fromIndex, toIndex, item) {
      debugPrint('Move $groupId:$fromIndex to $groupId:$toIndex - item $item');
    },
    onMoveGroupItemToGroup: <T>(fromGroupId, fromIndex, toGroupId, toIndex, T item) {
      debugPrint('Move $fromGroupId:$fromIndex to $toGroupId:$toIndex - item $item');
    },
  );

  late AATexBoardScrollController boardController;

  @override
  void initState() {
    super.initState();
    boardController = AATexBoardScrollController();

    // Create 10 columns with 50 items each
    for (int colIndex = 1; colIndex <= 10; colIndex++) {
      final List<AATexGroupItem> items = [];

      // Add 50 items to each column
      for (int itemIndex = 1; itemIndex <= 50; itemIndex++) {
        final itemId = "item_${colIndex}_$itemIndex";

        // Add a mix of TextItems and RichTextItems
        if (itemIndex % 5 == 0) {
          items.add(
            RichTextItem(
              id: itemId, // Use direct itemId
              title: "Card $itemIndex",
              subtitle: 'April 11, 2025 - Item #$itemIndex',
            ),
          );
        } else {
          items.add(
            TextItem(
              id: itemId, // Use direct itemId
              text: "Card $itemIndex",
            ),
          );
        }
      }

      final column = AATexGroupData(id: "column_$colIndex", name: "Col_$colIndex", items: items);

      controller.addGroup(column);
    }
  }

  void _showCard() {
    print('====== SHOW CARD BUTTON PRESSED ======');
    print('Attempting to display card #43 in column 8');

    try {
      // Display card #43 in column 8
      controller
          .displayCard(
            groupId: "column_8",
            itemId: "item_8_43",
            highlightColor: Colors.amber.withOpacity(0.5),
            boardScrollController: boardController, // Pass the scroll controller
          )
          .then((success) {
            print('displayCard completed with result: $success');
          })
          .catchError((error) {
            print('Error in displayCard: $error');
            print('Stack trace: ${StackTrace.current}');
          });
    } catch (e) {
      print('Exception while calling displayCard: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = AATexBoardConfig.config(
      groupBackgroundColor: HexColor.fromHex('#F7F8FC'),
      stretchGroupHeight: false,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Column Board Example'),
        actions: [
          // Button to find and highlight card #43 in column 8
          ElevatedButton(onPressed: _showCard, child: const Text('Find card 8-43')),
        ],
      ),
      body: AATexBoard(
        controller: controller,
        cardBuilder: (context, group, groupItem) {
          return AATexGroupCard(key: ValueKey(groupItem.id), child: _buildCard(groupItem));
        },
        boardScrollController: boardController,
        footerBuilder: (context, columnData) {
          return AATexGroupFooter(
            icon: const Icon(Icons.add, size: 20),
            title: const Text('New'),
            height: 50,
            margin: config.groupBodyPadding,
            onAddButtonClick: () {
              boardController.scrollToBottom(columnData.id);
            },
          );
        },
        headerBuilder: (context, columnData) {
          return AATexGroupHeader(
            icon: const Icon(Icons.lightbulb_circle),
            title: SizedBox(
              width: 60,
              child: TextField(
                controller: TextEditingController()..text = columnData.headerData.groupName,
                onSubmitted: (val) {
                  controller.getGroupController(columnData.headerData.groupId)!.updateGroupName(val);
                },
              ),
            ),
            addIcon: const Icon(Icons.add, size: 20),
            moreIcon: const Icon(Icons.more_horiz, size: 20),
            height: 50,
            margin: config.groupBodyPadding,
          );
        },
        groupConstraints: const BoxConstraints.tightFor(width: 240),
        config: config,
      ),
    );
  }

  Widget _buildCard(AATexGroupItem item) {
    // Check if the item is active
    final isActive = item is ActiveableGroupItem && (item as ActiveableGroupItem).isActive;
    final highlightColor = (item is ActiveableGroupItem) ? (item as ActiveableGroupItem).highlightColor : null;
    final highlightBorder = (item is ActiveableGroupItem) ? (item as ActiveableGroupItem).highlightBorder : null;

    // Apply decoration with border if active
    BoxDecoration? decoration;

    if (isActive) {
      if (highlightBorder != null) {
        // Используем highlightBorder для создания рамки
        decoration = BoxDecoration(
          color: highlightColor,
          border: Border(top: highlightBorder, left: highlightBorder, right: highlightBorder, bottom: highlightBorder),
          borderRadius: BorderRadius.circular(4),
        );
      } else {
        // Используем стандартную рамку, если highlightBorder не задан
        decoration = BoxDecoration(
          color: highlightColor ?? Colors.blue.withOpacity(0.2),
          border: Border.all(color: Colors.blue, width: 2),
          borderRadius: BorderRadius.circular(4),
        );
      }
    }

    if (item is TextItem) {
      return Container(
        decoration: decoration,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Text(item.s, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
          ),
        ),
      );
    }

    if (item is RichTextItem) {
      return Container(decoration: decoration, child: RichTextCard(item: item));
    }

    throw UnimplementedError();
  }
}

class RichTextCard extends StatefulWidget {
  final RichTextItem item;
  const RichTextCard({required this.item, Key? key}) : super(key: key);

  @override
  State<RichTextCard> createState() => _RichTextCardState();
}

class _RichTextCardState extends State<RichTextCard> {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item.title, style: const TextStyle(fontSize: 14), textAlign: TextAlign.left),
            const SizedBox(height: 10),
            Text(widget.item.subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class TextItem extends AATexGroupItem implements ActiveableGroupItem {
  final String _id;
  final String s;
  final bool _isActive;
  final Color? _highlightColor;
  final BorderSide? _highlightBorder;

  TextItem({
    required String id,
    required String text,
    bool isActive = false,
    Color? highlightColor,
    BorderSide? highlightBorder,
  }) : _id = id,
       s = text,
       _isActive = isActive,
       _highlightColor = highlightColor,
       _highlightBorder = highlightBorder;

  @override
  String get id => _id;

  @override
  bool get isActive => _isActive;

  @override
  Color? get highlightColor => _highlightColor;

  @override
  BorderSide? get highlightBorder => _highlightBorder;

  @override
  TextItem copyWith({bool? isActive, Color? highlightColor, BorderSide? highlightBorder}) {
    return TextItem(
      id: _id,
      text: s,
      isActive: isActive ?? _isActive,
      highlightColor: highlightColor ?? _highlightColor,
      highlightBorder: highlightBorder ?? _highlightBorder,
    );
  }
}

class RichTextItem extends AATexGroupItem implements ActiveableGroupItem {
  final String _id;
  final String title;
  final String subtitle;
  final bool _isActive;
  final Color? _highlightColor;
  final BorderSide? _highlightBorder;

  RichTextItem({
    required String id,
    required this.title,
    required this.subtitle,
    bool isActive = false,
    Color? highlightColor,
    BorderSide? highlightBorder,
  }) : _id = id,
       _isActive = isActive,
       _highlightColor = highlightColor,
       _highlightBorder = highlightBorder;

  @override
  String get id => _id;

  @override
  bool get isActive => _isActive;

  @override
  Color? get highlightColor => _highlightColor;

  @override
  BorderSide? get highlightBorder => _highlightBorder;

  @override
  RichTextItem copyWith({bool? isActive, Color? highlightColor, BorderSide? highlightBorder}) {
    return RichTextItem(
      id: _id,
      title: title,
      subtitle: subtitle,
      isActive: isActive ?? _isActive,
      highlightColor: highlightColor ?? _highlightColor,
      highlightBorder: highlightBorder ?? _highlightBorder,
    );
  }
}

extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
