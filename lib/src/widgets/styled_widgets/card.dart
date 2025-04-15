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
    // Base card with original decoration
    Widget cardWidget = Container(
      clipBehavior: Clip.hardEdge,
      margin: margin,
      constraints: boxConstraints,
      decoration: decoration,
      child: child,
    );

    // If an item is provided and it implements the ActiveableGroupItem interface,
    // check its active state and apply overlay if needed
    if (item != null && item is ActiveableGroupItem) {
      final activeItem = item as ActiveableGroupItem;
      if (activeItem.isActive) {
        // Instead of changing the card's color, we stack a semi-transparent overlay and border on top
        cardWidget = Stack(
          children: [
            // Original card
            cardWidget,
            // Overlay with highlight color at 10% opacity
            if (activeItem.highlightColor != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: activeItem.highlightColor,
                    border: activeItem.highlightBorder != null
                        ? Border(
                            top: activeItem.highlightBorder!,
                            left: activeItem.highlightBorder!,
                            right: activeItem.highlightBorder!,
                            bottom: activeItem.highlightBorder!,
                          )
                        : null,
                  ),
                ),
              ),
            // Full color border
            if (activeItem.highlightBorder != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border(
                      top: activeItem.highlightBorder!,
                      left: activeItem.highlightBorder!,
                      right: activeItem.highlightBorder!,
                      bottom: activeItem.highlightBorder!,
                    ),
                    borderRadius: decoration.borderRadius,
                  ),
                ),
              ),
          ],
        );
      }
    }

    return cardWidget;
  }
}
