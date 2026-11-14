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
  testWidgets('AddProductWizardScreen Step 2 renders Describe Your Product voice screen', (tester) async {
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
          home: AddProductWizardScreen(initialStep: 2), // Step 2 is Voice Catalog
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify "Describe Your Product" header
    expect(find.text('Describe Your Product'), findsOneWidget);

    // Verify "Speak in your own language" subtext
    expect(
      find.text('Speak in your own language (Marathi, Hindi, Tamil, Telugu, etc.)'),
      findsOneWidget,
    );

    // Verify Microphone button is present
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

    // Verify initial recording prompt
    expect(find.text('Tap & Speak'), findsOneWidget);
  });
}
