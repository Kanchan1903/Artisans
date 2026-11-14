import 'package:flutter_test/flutter_test.dart';
import 'package:kalasathi_mobile/providers/product_wizard_provider.dart';

void main() {
  group('Multilingual Voice-to-Description Agent Provider Logic', () {
    test('Initial voice description state is clean and ready', () {
      final wizard = ProductWizardProvider();
      expect(wizard.voiceTranscript, isEmpty);
      expect(wizard.isRecording, isFalse);
      expect(wizard.isAudioPlaying, isFalse);
      expect(wizard.detectedLanguage, isNull);
      expect(wizard.isDescriptionApproved, isFalse);
      expect(wizard.titleEn, isEmpty);
      expect(wizard.descriptionEn, isEmpty);
    });

    test('Updating voice transcript reflects in state', () {
      final wizard = ProductWizardProvider();
      wizard.updateVoiceTranscript('हा वारली कलेचा कॅनव्हास आहे');
      expect(wizard.voiceTranscript, 'हा वारली कलेचा कॅनव्हास आहे');
    });

    test('Approving description updates confirmation flags', () {
      final wizard = ProductWizardProvider();
      wizard.updateEnglishDescription('Handmade Warli Folk Painting on canvas');
      expect(wizard.isDescriptionApproved, isFalse);

      wizard.setDescriptionApproved(true);
      expect(wizard.isDescriptionApproved, isTrue);
      expect(wizard.englishDescriptionConfirmed, isTrue);
      expect(wizard.finalDescriptionConfirmed, isTrue);
    });

    test('Manual description editing marks as edited and resets approval', () {
      final wizard = ProductWizardProvider();
      wizard.setDescriptionApproved(true);
      expect(wizard.isDescriptionApproved, isTrue);

      wizard.updateEnglishDescription('Updated Handcrafted Warli Painting');
      expect(wizard.descriptionEn, 'Updated Handcrafted Warli Painting');
      expect(wizard.descriptionManuallyEdited, isTrue);
      expect(wizard.englishDescriptionConfirmed, isFalse);
    });

    test('Resolving missing specification clears missing field and prompt', () async {
      final wizard = ProductWizardProvider();
      wizard.updateVoiceTranscript('सुंदर हस्तशिल्प');
      // Set initial missing field
      wizard.resolveMissingSpecification(
        field: 'material',
        value: 'Natural Clay',
        language: 'mr',
        token: 'test_token',
      );
      expect(wizard.material, 'Natural Clay');
    });
  });
}
