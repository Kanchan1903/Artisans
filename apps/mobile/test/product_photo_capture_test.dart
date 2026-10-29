import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/providers/product_wizard_provider.dart';
import 'package:kalasathi_mobile/screens/add_product/add_product_wizard_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Product photo capture', () {
    test(
        'recognizes JPEG, PNG, and WebP signatures and rejects unsupported bytes',
        () {
      expect(
        ProductWizardProvider.detectProductImageType([0xff, 0xd8, 0xff, 0x00]),
        ('jpg', 'image/jpeg'),
      );
      expect(
        ProductWizardProvider.detectProductImageType(
            [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        ('png', 'image/png'),
      );
      expect(
        ProductWizardProvider.detectProductImageType([
          ...'RIFF'.codeUnits,
          0x00,
          0x00,
          0x00,
          0x00,
          ...'WEBP'.codeUnits,
        ]),
        ('webp', 'image/webp'),
      );
      expect(ProductWizardProvider.detectProductImageType([1, 2, 3]), isNull);
    });

    testWidgets('camera step keeps camera and gallery choices available',
        (tester) async {
      final wizard = ProductWizardProvider();
      SharedPreferences.setMockInitialValues({});
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
            home: AddProductWizardScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Capture Photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(find.text('Please take or choose a photo first'), findsOneWidget);
    });
  });
}
