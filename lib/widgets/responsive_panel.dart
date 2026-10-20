import 'package:flutter/material.dart';

class ResponsivePanel extends StatelessWidget {
  final Widget child;
  final double widthFactor;
  final double? minWidth;
  final double? maxWidth;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final BorderRadiusGeometry borderRadius;
  final Alignment alignment;

  const ResponsivePanel({
    super.key,
    required this.child,
    this.widthFactor = 1,
    this.minWidth,
    this.maxWidth,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color = const Color(0xFF5345AB),
    this.borderColor = const Color(0xFFE5D36D),
    this.borderWidth = 7,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final panelWidth = (availableWidth * widthFactor).clamp(
          minWidth ?? 0,
          maxWidth ?? double.infinity,
        ).toDouble();

        return Align(
          alignment: alignment,
          child: Container(
            width: panelWidth,
            height: height,
            margin: margin,
            padding: padding,
            decoration: BoxDecoration(
              color: color,
              borderRadius: borderRadius,
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }
}