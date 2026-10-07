import 'package:flutter/material.dart';

abstract final class HeritagePalette {
  static const canvas = Color(0xFFF7F9F6);
  static const surface = Color(0xFFFFFFFF);
  static const forest = Color(0xFF174A3B);
  static const red = Color(0xFFCE342E);
  static const sun = Color(0xFFFFC928);
  static const ink = Color(0xFF202622);
  static const rule = Color(0xFFD8DFD9);
  static const muted = Color(0xFF647169);
}

class HeritageTricolorBand extends StatelessWidget {
  const HeritageTricolorBand({super.key, this.height = 4});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Row(
        children: [
          Expanded(child: ColoredBox(color: HeritagePalette.red)),
          Expanded(child: ColoredBox(color: HeritagePalette.sun)),
          Expanded(child: ColoredBox(color: HeritagePalette.ink)),
        ],
      ),
    );
  }
}
