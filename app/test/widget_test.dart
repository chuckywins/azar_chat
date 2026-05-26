import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:azar_chat_app/theme.dart';

void main() {
  test('theme builds with dark brightness', () {
    final t = buildAzarTheme();
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, AzarPalette.bg);
  });
}
