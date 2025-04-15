import 'package:flutter/material.dart';
import 'package:aatex_board/src/widgets/board_group/group_data.dart';

class AATexGroupCard extends StatelessWidget {
  const AATexGroupCard({
    super.key,
    this.child,
    this.margin = const EdgeInsets.all(4),
    this.decoration = const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.zero,
    ),
    this.boxConstraints = const BoxConstraints(minHeight: 40),
    this.item,
  });

  final Widget? child;
  final EdgeInsets margin;
  final BoxDecoration decoration;
  final BoxConstraints boxConstraints;
  final AATexGroupItem? item;

  @override
  Widget build(BuildContext context) {
    // If an item is provided and it implements the ActiveableGroupItem interface,
    // check its active state and apply the appropriate decoration
    BoxDecoration finalDecoration = decoration;

    if (item != null && item is ActiveableGroupItem) {
      final activeItem = item as ActiveableGroupItem;
      if (activeItem.isActive) {
        // Apply the active element style
        if (activeItem.highlightBorder != null) {
          finalDecoration = BoxDecoration(
            color: activeItem.highlightColor,
            border: Border(
              top: activeItem.highlightBorder!,
              left: activeItem.highlightBorder!,
              right: activeItem.highlightBorder!,
              bottom: activeItem.highlightBorder!,
            ),
            borderRadius: decoration.borderRadius,
          );
        } else if (activeItem.highlightColor != null) {
          // If there's only a highlight color
          finalDecoration = BoxDecoration(
            color: activeItem.highlightColor,
            borderRadius: decoration.borderRadius,
          );
        }
      }
    }

    return Container(
      clipBehavior: Clip.hardEdge,
      margin: margin,
      constraints: boxConstraints,
      decoration: finalDecoration,
      child: child,
    );
  }
}
