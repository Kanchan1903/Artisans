import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/providers/product_wizard_provider.dart';
import 'package:kalasathi_mobile/screens/add_product/add_product_wizard_screen.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Minimal 1x1 transparent PNG bytes for mock Image.memory decoding
final kTransparentImage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  testWidgets('AddProductWizardScreen Step 1 renders AI Photo Studio with controls & background cards', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final wizard = ProductWizardProvider();
    final auth = AuthProvider();
    await auth.setLanguage('en');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductWizardProvider>.value(value: wizard),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AddProductWizardScreen(initialStep: 1),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify Preservation card is visible
    expect(find.text('Original Craft Preserved 100%'), findsOneWidget);

    // Verify Studio Controls: View Original, Undo, Redo, Reset
    expect(find.text('View Original'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Redo'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);

    // Verify Remove Background button before background is removed
    expect(find.text('Remove Background Automatically'), findsOneWidget);
  });
}
