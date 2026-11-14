import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/providers/product_wizard_provider.dart';
import 'package:kalasathi_mobile/screens/add_product/add_product_wizard_screen.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('AddProductWizardScreen Step 3 renders Dynamic Pricing with Approve, Reject, and Manual buttons', (tester) async {
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
          home: AddProductWizardScreen(initialStep: 3), // Step 3 is Fair Pricing
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify "Add Price Manually" button
    expect(find.text('Add Price Manually'), findsOneWidget);

    // Verify "Approve Price" button
    expect(find.text('Approve Price'), findsOneWidget);

    // Verify "Reject / Try Again" button
    expect(find.text('Reject / Try Again'), findsOneWidget);
  });
}
