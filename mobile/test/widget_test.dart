import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:abb_kontrol/widgets/status_badge.dart';

void main() {
  testWidgets('StatusBadge onaylandi durumu için doğru etiketi gösterir', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: StatusBadge(durum: 'onaylandi'))));

    expect(find.text('Onaylandı'), findsOneWidget);
  });
}
