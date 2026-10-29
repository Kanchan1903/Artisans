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
    // AI Studio is a backend-dependent step; the state navigation itself is
    // independent of API availability.
    wizard.nextStep();
    expect(wizard.currentStep, 2);

    // Step 3: Voice Cataloging starts empty; the device recognizer supplies
    // real speech and the backend must translate it before a description exists.
    await wizard.processVoiceNote('mr', token: 'test_token');
    expect(wizard.voiceTranscript, isEmpty);
    expect(wizard.descriptionEn, isEmpty);
    expect(wizard.speechError, contains('No speech was recognized'));
    wizard.nextStep();
    expect(wizard.currentStep, 3);

    // Step 4: Pricing Assistant
    expect(wizard.costFloor, 0);
    expect(wizard.suggestedPrice, 0);
    expect(wizard.premiumPrice, 0);
    wizard.nextStep();
    expect(wizard.currentStep, 4);

    // Step 5: Publish Live
    final published = await wizard.publishProduct('test_token');
    expect(published, isFalse);
    expect(wizard.isPublished, isFalse);
  });
}
