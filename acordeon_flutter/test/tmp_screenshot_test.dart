import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:acordeon_flutter/main.dart';

void main() {
  testWidgets('capture bass panel', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        child: RepaintBoundary(key: key, child: const AcordeonApp()),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    late final ui.Image image;
    await tester.runAsync(() async {
      image = await boundary.toImage(pixelRatio: 1.0);
    });
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      r'C:\Users\vfcp1\AppData\Local\Temp\opencode\bass_panel.png',
    );
    file.writeAsBytesSync(byteData!.buffer.asUint8List());
  });
}
