import 'package:flutter/material.dart';

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
  });

  final Widget? child;
  final EdgeInsets margin;
  final BoxDecoration decoration;
  final BoxConstraints boxConstraints;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      margin: margin,
      constraints: boxConstraints,
      decoration: decoration,
      child: child,
    );
  }
}
