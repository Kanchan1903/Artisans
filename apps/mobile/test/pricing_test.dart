import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kalasathi_mobile/providers/product_wizard_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Intelligent Product Pricing Workflow Tests', () {
    test('1. Calculates transparent cost breakdown with fair living wage defaults', () async {
      final wizard = ProductWizardProvider();

      // Recalculate with known artisan input
      await wizard.recalculatePricing(
        materialCost: 200.0,
        laborHours: 4.0,
        hourlyRate: 85.0, // Default fair living wage
        packagingCost: 30.0,
        shippingCost: 60.0,
        language: 'mr',
      );

      // Direct costs = 200 + (4 * 85 = 340) + 30 + 60 = 630
      // Cost floor = 630 / (1 - 0.08) = 630 / 0.92 = 684.78 -> ~685
      expect(wizard.costFloor, greaterThanOrEqualTo(630.0));
      expect(wizard.suggestedPrice, greaterThanOrEqualTo(wizard.costFloor));
      expect(wizard.premiumPrice, greaterThanOrEqualTo(wizard.suggestedPrice));

      // Accepted price initially defaults to the suggested market price
      expect(wizard.acceptedPrice, equals(wizard.suggestedPrice));

      // Cost breakdown details
      expect(wizard.costBreakdown['material_cost'], equals(200.0));
      expect(wizard.costBreakdown['labor_hours'], equals(4.0));
      expect(wizard.costBreakdown['hourly_rate'], equals(85.0));
    });

    test('2. Allows selecting between the 3 distinct price tiers', () async {
      final wizard = ProductWizardProvider();
      await wizard.recalculatePricing(
        materialCost: 150.0,
        laborHours: 3.0,
        language: 'mr',
      );

      // Select Cost Floor
      wizard.selectPrice(wizard.costFloor);
      expect(wizard.acceptedPrice, equals(wizard.costFloor));
      expect(wizard.customPriceOverride, isNull);
      expect(wizard.priceOverrideWarning, isNull);

      // Select Premium Price
      wizard.selectPrice(wizard.premiumPrice);
      expect(wizard.acceptedPrice, equals(wizard.premiumPrice));
      expect(wizard.customPriceOverride, isNull);

      // Select Suggested Price
      wizard.selectPrice(wizard.suggestedPrice);
      expect(wizard.acceptedPrice, equals(wizard.suggestedPrice));
    });

    test('3. Custom price override above cost floor is valid with no warning', () async {
      final wizard = ProductWizardProvider();
      await wizard.recalculatePricing(
        materialCost: 200.0,
        laborHours: 4.0,
        language: 'mr',
      );

      final customValidPrice = wizard.costFloor + 200.0;
      await wizard.applyCustomPriceOverride(customValidPrice, 'mr');

      expect(wizard.acceptedPrice, equals(customValidPrice));
      expect(wizard.customPriceOverride, equals(customValidPrice));
      expect(wizard.priceOverrideWarning, isNull);
    });

    test('4. Custom price override below cost floor displays a financial loss warning', () async {
      final wizard = ProductWizardProvider();
      await wizard.recalculatePricing(
        materialCost: 300.0,
        laborHours: 5.0,
        language: 'mr',
      );

      // Artisan tries to sell way below cost floor
      final customLossPrice = wizard.costFloor - 150.0;
      await wizard.applyCustomPriceOverride(customLossPrice, 'mr');

      expect(wizard.acceptedPrice, equals(customLossPrice));
      expect(wizard.customPriceOverride, equals(customLossPrice));
      expect(wizard.priceOverrideWarning, isNotNull);
      expect(
        wizard.priceOverrideWarning!.contains('नुकसान') ||
            wizard.priceOverrideWarning!.contains('सावधान') ||
            wizard.priceOverrideWarning!.contains('loss') ||
            wizard.priceOverrideWarning!.contains('Warning'),
        isTrue,
      );
    });

    test('5. Editing costs recalculates floor and suggested prices dynamically', () async {
      final wizard = ProductWizardProvider();
      await wizard.recalculatePricing(
        materialCost: 100.0,
        laborHours: 2.0,
        language: 'hi',
      );
      final initialFloor = wizard.costFloor;

      // Increase material cost and hours (e.g. intricate craft)
      await wizard.recalculatePricing(
        materialCost: 500.0,
        laborHours: 8.0,
        language: 'hi',
      );

      expect(wizard.costFloor, greaterThan(initialFloor));
      expect(wizard.suggestedPrice, greaterThan(initialFloor));
      expect(wizard.materialCost, equals(500.0));
      expect(wizard.laborHours, equals(8.0));
    });

    test('6. Pricing connects to product draft and retains accepted price', () async {
      final wizard = ProductWizardProvider();
      wizard.updateVoiceTranscript("सुंदर हस्तनिर्मित मातीचा वारली नक्षीकाम केलेला घडा.");
      await wizard.processVoiceNote('mr');

      await wizard.recalculatePricing(
        materialCost: 180.0,
        laborHours: 4.0,
        language: 'mr',
      );

      // Artisan approves the suggested price
      final chosenPrice = wizard.suggestedPrice;
      wizard.selectPrice(chosenPrice);

      // Save as draft
      final saved = await wizard.saveAsDraft("test_token_123");
      expect(saved, isTrue);
      expect(wizard.isDraftSaved, isTrue);
      expect(wizard.acceptedPrice, equals(chosenPrice));
    });
  });
}
