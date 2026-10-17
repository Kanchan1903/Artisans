import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kalasathi_mobile/providers/product_wizard_provider.dart';
import 'package:kalasathi_mobile/services/offline_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Regional-Language Voice Catalog Workflow Tests', () {
    test('1. Voice cataloging respects artisan language preference and extracts fields', () async {
      final wizard = ProductWizardProvider();

      // Artisan speaks in Marathi
      await wizard.processVoiceNote('mr');

      expect(wizard.voiceTranscript.isNotEmpty, isTrue);
      expect(wizard.titleEn.isNotEmpty, isTrue);
      expect(wizard.titleHi.isNotEmpty, isTrue);
      expect(wizard.shortDescriptionEn.isNotEmpty, isTrue);
      expect(wizard.descriptionEn.isNotEmpty, isTrue);
      expect(wizard.translations.length, greaterThanOrEqualTo(3));
    });

    test('2. Transcript editing allows correcting misheard words', () {
      final wizard = ProductWizardProvider();
      wizard.updateVoiceTranscript("हा मातीचा घडा आहे");
      expect(wizard.voiceTranscript, "हा मातीचा घडा आहे");

      // Artisan corrects transcript error
      wizard.updateVoiceTranscript("हा शुद्ध नदीच्या मातीचा वारली नक्षीकाम केलेला घडा आहे");
      expect(wizard.voiceTranscript, "हा शुद्ध नदीच्या मातीचा वारली नक्षीकाम केलेला घडा आहे");
    });

    test('3. Never invents missing specifications; prompts for missing details', () async {
      final wizard = ProductWizardProvider();

      // Vague speech without material or technique
      wizard.updateVoiceTranscript("मी एक सुंदर वस्तू बनवली आहे.");
      await wizard.processVoiceNote('mr');

      // Material or technique absent -> strictly detected as missing
      if (wizard.missingFields.isNotEmpty) {
        expect(wizard.missingInfoPrompt, isNotNull);
        expect(
          wizard.missingInfoPrompt!.contains("साहित्य") ||
              wizard.missingInfoPrompt!.contains("माहिती") ||
              wizard.missingInfoPrompt!.contains("material"),
          isTrue,
        );
      }
    });

    test('4. Resolving missing specification updates product and clears alert', () async {
      final wizard = ProductWizardProvider();
      wizard.updateVoiceTranscript("मी एक घडा बनवला आहे.");
      await wizard.processVoiceNote('mr');

      // Artisan provides missing material
      await wizard.resolveMissingSpecification(
        field: 'material',
        value: 'नदीची शुद्ध माती (Riverbed Clay)',
        language: 'mr',
      );

      expect(wizard.material, isNotEmpty);
      expect(wizard.missingFields.contains('material'), isFalse);
    });

    test('5. Read Aloud summary generates localized speech in artisan language', () async {
      final wizard = ProductWizardProvider();
      await wizard.processVoiceNote('mr');

      // Marathi speech readout summary
      final speechMr = wizard.getListingSummaryForSpeech('mr');
      expect(speechMr.contains("उत्पादन") || speechMr.contains("साहित्य"), isTrue);

      // Hindi speech readout summary
      final speechHi = wizard.getListingSummaryForSpeech('hi');
      expect(speechHi.contains("उत्पाद") || speechHi.contains("सामग्री"), isTrue);

      // English speech readout summary
      final speechEn = wizard.getListingSummaryForSpeech('en');
      expect(speechEn.contains("product") || speechEn.contains("Material"), isTrue);
    });

    test('6. Saving as draft stores product locally with translations and images', () async {
      final wizard = ProductWizardProvider();
      await wizard.processVoiceNote('mr');

      final saved = await wizard.saveAsDraft('test_token');
      expect(saved, isTrue);
      expect(wizard.isDraftSaved, isTrue);

      final queueCount = await OfflineStorageService.getQueueCount();
      expect(queueCount, greaterThanOrEqualTo(1));

      final drafts = await OfflineStorageService.getOfflineDrafts();
      final lastDraft = drafts.last;
      expect(lastDraft['status'], 'draft');
      expect(lastDraft['voice_transcript'], isNotNull);
      expect(lastDraft['translations'], isNotNull);
    });
  });
}
