import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kalasathi_mobile/main.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/providers/product_wizard_provider.dart';
import 'package:kalasathi_mobile/providers/order_provider.dart';

void main() {
  testWidgets('KalaSathi app smoke test: loads language picker with native Indian scripts',
      (WidgetTester tester) async {
    // Set realistic smartphone viewport dimensions
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Build KalaSathi app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ProductWizardProvider()),
          ChangeNotifierProvider(create: (_) => OrderProvider()),
        ],
        child: const KalaSathiApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify native Indian scripts are rendered on the first launch language picker
    expect(find.text('मराठी'), findsOneWidget);
    expect(find.text('हिन्दी'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('বাংলা'), findsOneWidget);
    expect(find.text('தமிழ்'), findsOneWidget);
    expect(find.text('తెలుగు'), findsOneWidget);
    expect(find.text('ಕನ್ನಡ'), findsOneWidget);
    expect(find.text('മലയാളം'), findsOneWidget);
    expect(find.text('ગુજરાતી'), findsOneWidget);
    expect(find.text('ਪੰਜਾਬੀ'), findsOneWidget);
    expect(find.text('ଓଡ଼ିଆ'), findsOneWidget);
    expect(find.text('অসমীয়া'), findsOneWidget);
  });
}
