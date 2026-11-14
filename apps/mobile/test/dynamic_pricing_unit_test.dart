import 'package:flutter_test/flutter_test.dart';
import 'package:kalasathi_mobile/providers/product_wizard_provider.dart';

void main() {
  group('Dynamic Pricing Agent Provider Logic', () {
    test('Initial pricing state is clean and ready', () {
      final wizard = ProductWizardProvider();
      expect(wizard.suggestedPrice, 0.0);
      expect(wizard.customPriceOverride, isNull);
      expect(wizard.pricingSources, isEmpty);
      expect(wizard.isDynamicPricingLoading, isFalse);
      expect(wizard.isRevisedByVoiceFeedback, isFalse);
      expect(wizard.isPricePreferenceScreenActive, isFalse);
    });

    test('Manual price entry overrides suggested price', () {
      final wizard = ProductWizardProvider();
      wizard.setCustomPriceDirect(750.0);
      expect(wizard.customPriceOverride, 750.0);
      expect(wizard.acceptedPrice, 750.0);
    });

    test('Toggling Price Preference screen updates active state', () {
      final wizard = ProductWizardProvider();
      expect(wizard.isPricePreferenceScreenActive, isFalse);
      wizard.setPricePreferenceScreenActive(true);
      expect(wizard.isPricePreferenceScreenActive, isTrue);
    });

    test('Submitting voice pricing feedback triggers dynamic agent flow gracefully', () async {
      final wizard = ProductWizardProvider();
      wizard.updateVoiceTranscript('मला याची किंमत ८०० रुपयांपेक्षा जास्त हवी आहे');
      
      // Call submitVoicePricingFeedback (with graceful offline mock/network fallback)
      await wizard.submitVoicePricingFeedback(
        voiceFeedback: 'मला ८०० रुपये हवेत',
        token: 'mock_token',
      );

      expect(wizard.voiceFeedbackTranscript, 'मला ८०० रुपये हवेत');
      expect(wizard.isDynamicPricingLoading, isFalse);
    });
  });
}
