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
    final column = AATexGroupData(
      id: "1",
      name: "1",
      items: [TextItem("a"), TextItem("b"), TextItem("c"), TextItem("d")],
    );

    boardData.addGroup(column);
  }

  @override
  Widget build(BuildContext context) {
    return AATexBoard(
      controller: boardData,
      cardBuilder: (context, column, columnItem) {
        return _RowWidget(item: columnItem as TextItem, key: ObjectKey(columnItem));
      },
    );
  }
}

class _RowWidget extends StatelessWidget {
  final TextItem item;
  const _RowWidget({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(key: ObjectKey(item), height: 60, color: Colors.green, child: Center(child: Text(item.s)));
  }
}

class TextItem extends AATexGroupItem {
  final String s;

  TextItem(this.s);

  @override
  String get id => s;
}
