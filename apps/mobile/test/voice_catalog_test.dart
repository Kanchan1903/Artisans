import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kalasathi_mobile/providers/product_wizard_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Regional voice description workflow', () {
    test('does not fabricate transcript or description when speech is empty',
        () async {
      final wizard = ProductWizardProvider();

      await wizard.processVoiceNote('mr', token: 'test-token');

      expect(wizard.voiceTranscript, isEmpty);
      expect(wizard.descriptionEn, isEmpty);
      expect(wizard.speechError, contains('No speech was recognized'));
    });

    test('artisan can review and edit the recognized transcript', () {
      final wizard = ProductWizardProvider();
      wizard.updateVoiceTranscript('पहिले वाक्य');
      wizard.updateVoiceTranscript('दुरुस्त केलेले वाक्य');

      expect(wizard.voiceTranscript, 'दुरुस्त केलेले वाक्य');
    });

    test('English description remains editable for artisan confirmation', () {
      final wizard = ProductWizardProvider();
      wizard.updateEnglishDescription('A hand-painted clay bowl.');

      expect(wizard.descriptionEn, 'A hand-painted clay bowl.');
      expect(wizard.descriptionManuallyEdited, isTrue);
      expect(wizard.descriptionNeedsReview, isFalse);
    });

    test('listing summary remains available in selected language', () {
      final wizard = ProductWizardProvider();
      final marathi = wizard.getListingSummaryForSpeech('mr');
      final hindi = wizard.getListingSummaryForSpeech('hi');
      final english = wizard.getListingSummaryForSpeech('en');

      expect(marathi, contains('तुमचे उत्पादन'));
      expect(hindi, contains('आपका उत्पाद'));
      expect(english, contains('Your product'));
    });
  });
}
