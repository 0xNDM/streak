import 'package:flutter/material.dart';

extension InkOn on Color {
  Color get ink => computeLuminance() > 0.55 ? Colors.black : Colors.white;
}
