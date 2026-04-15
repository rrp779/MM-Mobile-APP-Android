import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppIcon extends StatelessWidget {
  final bool isActive;
  final String outlinePath;
  final String filledPath;
  final double size;
  final Color? color;

  const AppIcon({
    Key? key,
    required this.isActive,
    required this.outlinePath,
    required this.filledPath,
    this.size = 24,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (isActive ? const Color(0xFFEA0180) : null);

    return SvgPicture.asset(
      isActive ? filledPath : outlinePath,
      width: size,
      height: size,
      colorFilter: effectiveColor != null
          ? ColorFilter.mode(effectiveColor, BlendMode.srcIn)
          : null,
    );
  }
}