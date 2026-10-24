import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acordeon_flutter/main.dart';

void main() {
  testWidgets('capture bass panel', (WidgetTester tester) async {
    debugPrint('STEP 1');
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        child: RepaintBoundary(key: key, child: const AcordeonApp()),
      ),
    );
    debugPrint('STEP 2');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    debugPrint('STEP 3');

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    debugPrint('STEP 4');
    final image = await boundary.toImage(pixelRatio: 1.0);
    debugPrint('STEP 5');
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    debugPrint('STEP 6');
    final file = File(
      r'C:\Users\vfcp1\AppData\Local\Temp\opencode\bass_panel.png',
    );
    file.writeAsBytesSync(byteData!.buffer.asUint8List());
    debugPrint('STEP 7');
  });
}
