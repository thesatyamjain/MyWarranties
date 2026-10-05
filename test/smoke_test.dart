import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_warranties/main.dart';
import 'package:my_warranties/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final onboarded in [false, true]) {
    testWidgets('app renders (onboarded=$onboarded)', (tester) async {
      SharedPreferences.setMockInitialValues({'onboarded': onboarded});
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      final s = Store();
      await s.load();
      await tester.pumpWidget(App(s));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.byType(Text), findsWidgets);
    });
  }
}
