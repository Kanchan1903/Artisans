import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalasathi_mobile/providers/product_wizard_provider.dart';

void main() {
  test('Add Product Wizard 5-step state transition test', () async {
    final wizard = ProductWizardProvider();

    expect(wizard.currentStep, 0);

    // Step 1: Camera
    wizard.addPhoto(Uint8List.fromList([1, 2, 3]));
    expect(wizard.photos.length, 1);
    wizard.nextStep();
    expect(wizard.currentStep, 1);

    // Step 2: AI Studio
    await wizard.processPhotoInAIStudio(token: 'test_token');
    expect(wizard.enhancedImageBase64, isNotNull);
    wizard.nextStep();
    expect(wizard.currentStep, 2);

    // Step 3: Voice Cataloging
    await wizard.processVoiceNote('mr');
    expect(wizard.voiceTranscript.isNotEmpty, isTrue);
    expect(wizard.titleEn.isNotEmpty, isTrue);
    expect(wizard.material.isNotEmpty, isTrue);
    wizard.nextStep();
    expect(wizard.currentStep, 3);

    // Step 4: Pricing Assistant
    expect(wizard.costFloor, greaterThan(0));
    expect(wizard.suggestedPrice, greaterThan(wizard.costFloor));
    expect(wizard.premiumPrice, greaterThan(wizard.suggestedPrice));
    wizard.selectPrice(wizard.suggestedPrice);
    expect(wizard.acceptedPrice, wizard.suggestedPrice);
    wizard.nextStep();
    expect(wizard.currentStep, 4);

    // Step 5: Publish Live
    final published = await wizard.publishProduct('test_token');
    expect(published, isTrue);
    expect(wizard.isPublished, isTrue);
  });
}
