import 'package:flutter_test/flutter_test.dart';
import 'package:kalasathi_mobile/providers/product_wizard_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Product pricing review state', () {
    test('does not invent prices before storefront data is loaded', () {
      final wizard = ProductWizardProvider();

      expect(wizard.suggestedPrice, 0);
      expect(wizard.costFloor, 0);
      expect(wizard.premiumPrice, 0);
      expect(wizard.hasSuggestedPrice, isFalse);
      expect(wizard.isVerifiedMarketPrice, isFalse);
    });

    test('keeps artisan cost inputs separate from market recommendations', () {
      final wizard = ProductWizardProvider();

      wizard.setArtisanCosts(
        materialCost: 200,
        laborHours: 4,
        hourlyRate: 85,
        packagingCost: 30,
        shippingCost: 60,
      );

      expect(wizard.hasArtisanCostInputs, isTrue);
      expect(wizard.materialCost, 200);
      expect(wizard.laborHours, 4);
      expect(wizard.suggestedPrice, 0);
      expect(wizard.costFloor, 0);
    });

    test('clears pricing recommendation state when starting a new product', () {
      final wizard = ProductWizardProvider();
      wizard.setArtisanCosts(
        materialCost: 100,
        laborHours: 2,
        hourlyRate: 50,
        packagingCost: 0,
        shippingCost: 0,
      );

      wizard.resetWizard();

      expect(wizard.hasArtisanCostInputs, isFalse);
      expect(wizard.suggestedPrice, 0);
      expect(wizard.acceptedPrice, 0);
      expect(wizard.pricingRevisionId, isNull);
      expect(wizard.priceSelectionSaved, isFalse);
    });
  });
}
