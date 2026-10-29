import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/providers/product_wizard_provider.dart';
import 'package:kalasathi_mobile/screens/add_product/add_product_wizard_screen.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';

// Minimal 1x1 transparent PNG bytes for mock Image.memory decoding
final kTransparentImage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  testWidgets('AddProductWizardScreen Step 2 renders 10 variations and header card', (tester) async {
    final wizard = ProductWizardProvider();
    final auth = AuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductWizardProvider>.value(value: wizard),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: const MaterialApp(
          locale: Locale('mr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AddProductWizardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Add valid image bytes (valid 1x1 PNG)
    wizard.addPhoto(kTransparentImage);
    wizard.nextStep(); // Advance to Step 2 (AI Studio)

    // Run AI studio variations
    await wizard.processPhotoInAIStudio(token: 'test_token');

    expect(wizard.imageVariations.length, 10);
    expect(wizard.selectedVariationIds.length, 3);

    // Settle UI after variations are set
    await tester.pumpAndSettle();

    // Verify Header Card texts
    expect(find.text('Choose Your Best 3 Photos'), findsOneWidget);
    expect(find.text('तुमचे ३ सर्वोत्तम फोटो निवडा'), findsOneWidget);

    // Verify live counter pill
    expect(find.textContaining('3 of 3 selected'), findsOneWidget);

    // Verify regenerate button
    expect(find.text('पुन्हा तयार करा'), findsOneWidget);

    // Verify Continue button
    expect(find.textContaining('पुढे जा: आवाज वर्णन'), findsOneWidget);

    // Test selection rules: attempting to select a 4th image is blocked
    final unselectedVar = wizard.imageVariations.firstWhere(
      (v) => !wizard.selectedVariationIds.contains(v['id']),
    );
    final allowed = wizard.toggleVariationSelection(unselectedVar['id'] as String);
    expect(allowed, isFalse, reason: 'Must not allow selecting a 4th variation');
    expect(wizard.selectedVariationIds.length, 3);

    // Deselect one
    final firstSelected = wizard.selectedVariationIds.first;
    wizard.toggleVariationSelection(firstSelected);
    expect(wizard.selectedVariationIds.length, 2);
    await tester.pumpAndSettle();

    // Now re-selecting the unselected one succeeds
    final selectSuccess = wizard.toggleVariationSelection(unselectedVar['id'] as String);
    expect(selectSuccess, isTrue);
    expect(wizard.selectedVariationIds.length, 3);
  });
}
