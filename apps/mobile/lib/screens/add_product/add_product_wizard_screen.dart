import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/providers/product_wizard_provider.dart';
import 'package:kalasathi_mobile/services/voice_guidance_service.dart';
import 'package:kalasathi_mobile/theme/app_theme.dart';
import 'package:kalasathi_mobile/widgets/image_comparison_slider.dart';
import 'package:kalasathi_mobile/widgets/voice_help_fab.dart';

class AddProductWizardScreen extends StatefulWidget {
  const AddProductWizardScreen({super.key});

  @override
  State<AddProductWizardScreen> createState() => _AddProductWizardScreenState();
}

class _AddProductWizardScreenState extends State<AddProductWizardScreen> {
  late final TextEditingController _customPriceCtrl;

  @override
  void initState() {
    super.initState();
    _customPriceCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductWizardProvider>(context, listen: false).resetWizard();
    });
  }

  @override
  void dispose() {
    _customPriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wizard = Provider.of<ProductWizardProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    final stepTitles = [
      l10n.translate('stepCamera'),
      l10n.translate('stepStudio'),
      l10n.translate('stepVoice'),
      l10n.translate('stepPricing'),
      l10n.translate('stepPublish'),
    ];

    final stepHelp = [
      l10n.translate('helpCamera'),
      l10n.translate('helpStudio'),
      l10n.translate('helpVoice'),
      l10n.translate('helpPricing'),
      "एका टॅपमध्ये उत्पादन थेट वेबसाइटवर लाइव्ह करा.",
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundSand,
      appBar: AppBar(
        title: Text(stepTitles[wizard.currentStep]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (wizard.currentStep > 0 && !wizard.isPublished) {
              wizard.previousStep();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      floatingActionButton: VoiceHelpFab(
        customMessage: stepHelp[wizard.currentStep],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Progress Bar ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: List.generate(5, (index) {
                  final isPassed = index <= wizard.currentStep;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 6,
                      decoration: BoxDecoration(
                        color: isPassed ? AppTheme.terracotta : AppTheme.borderWarm,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),

            // ─── Step Content ────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _buildStepContent(wizard, l10n, auth),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(ProductWizardProvider wizard, AppLocalizations l10n, AuthProvider auth) {
    switch (wizard.currentStep) {
      case 0:
        return _buildCameraStep(wizard, l10n);
      case 1:
        return _buildStudioStep(wizard, l10n);
      case 2:
        return _buildVoiceStep(wizard, l10n, auth);
      case 3:
        return _buildPricingStep(wizard, l10n, auth);
      case 4:
        return _buildPublishStep(wizard, l10n, auth);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Step 1: Smart Camera ──────────────────────────────────────────────────
  Widget _buildCameraStep(ProductWizardProvider wizard, AppLocalizations l10n) {
    return Column(
      children: [
        // Camera Viewfinder Simulation with Smart Guidance Overlay
        Container(
          width: double.infinity,
          height: 340,
          decoration: BoxDecoration(
            color: const Color(0xFF1F1D1B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.terracotta, width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Framing guides
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white30, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              // Simulated handicraft in frame
              const Icon(
                Icons.palette_rounded,
                size: 110,
                color: Color(0xFFC85A32),
              ),
              // Smart Camera Guidance Banner
              Positioned(
                top: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.turmeric, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wb_sunny_rounded, color: AppTheme.turmeric, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l10n.translate('guidanceGoodLight'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Photo count indicator
        Text(
          "${wizard.photos.length}/4 ${l10n.translate('photosTaken')}",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 16),

        // Shutter Button
        ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt_rounded, size: 28),
          label: Text(l10n.translate('capturePhoto')),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.terracotta,
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
          onPressed: () {
            // Add sample image bytes
            wizard.addPhoto(Uint8List.fromList(List.filled(100, 255)));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("फोटो टिपला! (Photo captured successfully)"),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        const SizedBox(height: 14),

        if (wizard.photos.isNotEmpty)
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward_rounded, size: 24),
            label: Text("${l10n.translate('continueBtn')} (${l10n.translate('stepStudio')})"),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.indigo),
            onPressed: () async {
              await wizard.processPhotoInAIStudio();
              wizard.nextStep();
            },
          ),
      ],
    );
  }

  // ─── Step 2: AI Image Studio ───────────────────────────────────────────────
  Widget _buildStudioStep(ProductWizardProvider wizard, AppLocalizations l10n) {
    if (wizard.isProcessingAI) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Column(
            children: [
              const CircularProgressIndicator(color: AppTheme.terracotta, strokeWidth: 4),
              const SizedBox(height: 24),
              const Text(
                "एआय स्टुडिओ १०-१५ विविध आकर्षक पर्याय तयार करत आहे...\n(AI Studio is generating 10–15 studio variations...)",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    final variations = wizard.imageVariations;
    final selectedIds = wizard.selectedVariationIds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Studio Step Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.turmericLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.turmeric.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppTheme.turmericDark, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "एआय स्टुडिओ: १२ व्यावसायिक पर्याय तयार",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textCharcoal),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "वेबसाइटवर अधिक विक्रीसाठी ३ ते ४ सर्वोत्तम चित्रे निवडा (${selectedIds.length}/4 निवडले)",
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Selection Counter Pill
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selectedIds.length >= 3 ? AppTheme.successGreenLight : AppTheme.terracottaLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedIds.length >= 3 ? AppTheme.successGreen : AppTheme.terracotta,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selectedIds.length >= 3 ? Icons.check_circle : Icons.photo_library_rounded,
                    color: selectedIds.length >= 3 ? AppTheme.successGreen : AppTheme.terracotta,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "निवडलेली चित्रे: ${selectedIds.length} / 4 (Selected)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: selectedIds.length >= 3 ? AppTheme.successGreen : AppTheme.terracotta,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.volume_up_rounded, size: 18),
              label: const Text("ऐका", style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                VoiceGuidanceService.speakPrompt(
                  context,
                  "एआयने तयार केलेल्या १२ फोटोंपैकी खरेदीदारांना आकर्षित करणारे ३ ते ४ फोटो निवडा.",
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Grid of 10-15 Variations
        if (variations.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: variations.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              final variation = variations[index];
              final varId = variation['id'] as String;
              final isSelected = selectedIds.contains(varId);
              final isPrimary = selectedIds.isNotEmpty && selectedIds.first == varId;
              final titleMr = variation['title_mr'] ?? variation['title'] ?? 'पर्याय ${index + 1}';
              final imgUrl = variation['image_url'] as String? ?? '';

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  wizard.toggleVariationSelection(varId);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? AppTheme.terracotta : AppTheme.borderWarm,
                      width: isSelected ? 3.0 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected ? AppTheme.terracotta.withOpacity(0.15) : Colors.black.withOpacity(0.04),
                        blurRadius: isSelected ? 8 : 4,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: _buildVariationThumbnail(imgUrl),
                            ),
                            // Top Right Selection Badge
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.terracotta : Colors.white.withOpacity(0.85),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? AppTheme.terracotta : AppTheme.textMuted,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                                    : null,
                              ),
                            ),
                            // Top Left Primary / Hero Tag
                            if (isPrimary)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successGreen,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    "मुख्य (Hero)",
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Title caption
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          titleMr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppTheme.terracottaDark : AppTheme.textCharcoal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
        else
          // Fallback Comparison Slider if no variations loaded
          Column(
            children: [
              ImageComparisonSlider(
                beforeImage: const NetworkImage(
                  "https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=600",
                ),
                afterImage: const NetworkImage(
                  "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=600",
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),

        const SizedBox(height: 24),

        ElevatedButton.icon(
          icon: const Icon(Icons.arrow_forward_rounded, size: 24),
          label: Text("${l10n.translate('continueBtn')} (${l10n.translate('stepVoice')}) - ${selectedIds.length} निवडले"),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
          onPressed: () {
            wizard.nextStep();
          },
        ),
      ],
    );
  }

  Widget _buildVariationThumbnail(String url) {
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    } else if (url.startsWith('http')) {
      return Image.network(url, fit: BoxFit.cover);
    }
    return Container(
      color: AppTheme.backgroundSand,
      child: const Icon(Icons.image, color: AppTheme.textMuted),
    );
  }

  // ─── Step 3: Regional-Language Voice Cataloging ───────────────────────────
  Widget _buildVoiceStep(ProductWizardProvider wizard, AppLocalizations l10n, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          l10n.translate('voicePrompt'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textCharcoal),
        ),
        const SizedBox(height: 6),
        Text(
          auth.selectedLanguage == 'mr'
              ? "उदा. 'हा वारली कलेचा कॅनव्हास आहे. तांदळाच्या पिठाने रंगवला आहे. ६ तास लागले आणि १५० रुपये खर्च झाले.'"
              : "उदा. 'यह शुद्ध नदी की मिट्टी से बना घड़ा है। चार घंटे लगे और अस्सी रुपये खर्च हुए।'",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 24),

        // Big Accessible Mic Button (min 56dp, 110dp circle)
        GestureDetector(
          onTap: () async {
            wizard.toggleRecording();
            if (!wizard.isRecording) {
              await wizard.processVoiceNote(auth.selectedLanguage);
            }
          },
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: wizard.isRecording ? Colors.red : AppTheme.terracotta,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (wizard.isRecording ? Colors.red : AppTheme.terracotta).withOpacity(0.35),
                  blurRadius: 24,
                  spreadRadius: 6,
                )
              ],
            ),
            child: Icon(
              wizard.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
              size: 54,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          wizard.isRecording
              ? (auth.selectedLanguage == 'mr' ? 'बोलत रहा... (ऐकत आहोत)' : 'बोलते रहें... (सुन रहे हैं)')
              : (wizard.voiceTranscript.isEmpty
                  ? l10n.translate('startRecording')
                  : (auth.selectedLanguage == 'mr' ? 'पुन्हा रेकॉर्ड करा (Tap to Re-record)' : 'फिर से रिकॉर्ड करें')),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: wizard.isRecording ? Colors.red : AppTheme.textCharcoal,
          ),
        ),
        const SizedBox(height: 20),

        if (wizard.isProcessingAI)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Column(
              children: [
                const CircularProgressIndicator(color: AppTheme.terracotta, strokeWidth: 3.5),
                const SizedBox(height: 16),
                Text(
                  auth.selectedLanguage == 'mr'
                      ? "आवाज समजून घेत आहे आणि १२ भाषांमध्ये अनुवाद करत आहे..."
                      : "आवाज से कैटलॉग तैयार हो रहा है और अनुवाद किया जा रहा है...",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else if (wizard.voiceTranscript.isNotEmpty) ...[
          // ─── 1. Spoken Transcript Card with Edit Button ──────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderWarm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.record_voice_over_rounded, color: AppTheme.terracotta, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          auth.selectedLanguage == 'mr' ? "तुमचा मूळ आवाज (Transcript)" : "आपका बोला गया विवरण",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.terracotta),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: "ऐका (Listen)",
                          icon: const Icon(Icons.volume_up_rounded, color: AppTheme.indigo),
                          onPressed: () {
                            VoiceGuidanceService.speakPrompt(context, wizard.voiceTranscript);
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.terracotta),
                          label: Text(
                            auth.selectedLanguage == 'mr' ? "दुरुस्त करा" : "सुधारें",
                            style: const TextStyle(color: AppTheme.terracotta, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            _showEditTranscriptDialog(context, wizard, auth);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  "\"${wizard.voiceTranscript}\"",
                  style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: AppTheme.textCharcoal),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── 2. Missing Specifications Alert (Rule 8: Never invent) ──────
          if (wizard.missingFields.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.turmericLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.turmeric, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppTheme.turmericDark, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        auth.selectedLanguage == 'mr' ? "अपूर्ण माहिती (Missing Details)" : "आवश्यक विवरण बाकी है",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.turmericDark, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    wizard.missingInfoPrompt ??
                        (auth.selectedLanguage == 'mr'
                            ? "कृपया हे शिल्प बनवण्यासाठी वापरलेले साहित्य (material) सांगा."
                            : "कृपया इस शिल्प में प्रयुक्त सामग्री (material) बताएं।"),
                    style: const TextStyle(fontSize: 14, color: AppTheme.textCharcoal, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(auth.selectedLanguage == 'mr' ? "माहिती जोडा (Add Details)" : "विवरण जोड़ें"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.turmericDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () {
                          _showAddMissingInfoDialog(context, wizard, auth);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ─── 3. Professional Structured Product Listing Card ────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderWarm),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        wizard.titleHi.isNotEmpty ? wizard.titleHi : wizard.titleEn,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textCharcoal),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: AppTheme.terracotta),
                      onPressed: () => _showEditListingDialog(context, wizard),
                    ),
                  ],
                ),
                Text(
                  wizard.titleEn,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 12),

                // Short summary description
                if (wizard.shortDescriptionHi.isNotEmpty || wizard.shortDescriptionEn.isNotEmpty) ...[
                  Text(
                    wizard.shortDescriptionHi.isNotEmpty ? wizard.shortDescriptionHi : wizard.shortDescriptionEn,
                    style: const TextStyle(fontSize: 14, color: AppTheme.textCharcoal, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                ],

                // Specifications chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildSpecChip(
                      icon: Icons.category_rounded,
                      label: wizard.categorySlug.toUpperCase(),
                      color: AppTheme.terracottaLight,
                      textColor: AppTheme.terracotta,
                    ),
                    _buildSpecChip(
                      icon: Icons.layers_rounded,
                      label: wizard.material.isNotEmpty
                          ? wizard.material
                          : (auth.selectedLanguage == 'mr' ? 'साहित्य बाकी' : 'सामग्री बाकी'),
                      color: wizard.material.isNotEmpty ? Colors.blue.shade50 : Colors.red.shade50,
                      textColor: wizard.material.isNotEmpty ? Colors.blue.shade800 : Colors.red.shade800,
                    ),
                    _buildSpecChip(
                      icon: Icons.brush_rounded,
                      label: wizard.technique.isNotEmpty
                          ? wizard.technique
                          : (auth.selectedLanguage == 'mr' ? 'पद्धत बाकी' : 'तकनीक बाकी'),
                      color: wizard.technique.isNotEmpty ? Colors.green.shade50 : Colors.orange.shade50,
                      textColor: wizard.technique.isNotEmpty ? Colors.green.shade800 : Colors.orange.shade800,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 12-Language translations badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.translate_rounded, size: 16, color: Colors.purple.shade700),
                      const SizedBox(width: 6),
                      Text(
                        auth.selectedLanguage == 'mr'
                            ? "१२ भारतीय भाषांमध्ये अनुवादित (12 Languages Ready)"
                            : "12 भारतीय भाषाओं में अनुवाद तैयार है",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── 4. Read Aloud Button (TTS in Artisan's Preferred Language) ──
          ElevatedButton.icon(
            icon: const Icon(Icons.volume_up_rounded, size: 24),
            label: Text(
              auth.selectedLanguage == 'mr' ? "संपूर्ण माहिती मोठ्याने ऐका (Read Aloud)" : "पूरी जानकारी सुनें (Read Aloud)",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {
              final spokenText = wizard.getListingSummaryForSpeech(auth.selectedLanguage);
              VoiceGuidanceService.speakPrompt(context, spokenText);
            },
          ),
          const SizedBox(height: 12),

          // ─── 5. Actions: Save as Draft, Preview, Continue to Pricing ─────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    wizard.isDraftSaved ? Icons.check_circle_rounded : Icons.save_as_rounded,
                    color: wizard.isDraftSaved ? Colors.green : AppTheme.terracotta,
                  ),
                  label: Text(
                    wizard.isDraftSaved
                        ? (auth.selectedLanguage == 'mr' ? 'मसुदा जतन केला' : 'ड्राफ्ट सहेजा')
                        : (auth.selectedLanguage == 'mr' ? 'मसुदा जतन करा' : 'ड्राफ्ट सहेजें'),
                    style: TextStyle(
                      color: wizard.isDraftSaved ? Colors.green : AppTheme.terracotta,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    await wizard.saveAsDraft(auth.authToken ?? '');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          auth.selectedLanguage == 'mr'
                              ? "उत्पादनाचा मसुदा यशस्वीपणे जतन केला! (Draft Saved)"
                              : "उत्पाद ड्राफ्ट सफलतापूर्वक सहेजा गया!",
                        ),
                        backgroundColor: AppTheme.terracotta,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.remove_red_eye_rounded, color: AppTheme.indigo),
                  label: Text(
                    auth.selectedLanguage == 'mr' ? "पूर्वावलोकन" : "पूर्वावलोकन",
                    style: const TextStyle(color: AppTheme.indigo, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showPreviewDialog(context, wizard, auth),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Continue to Pricing button
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward_rounded, size: 24),
            label: Text("${l10n.translate('continueBtn')} (${l10n.translate('stepPricing')})"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.terracotta,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              wizard.nextStep();
            },
          ),
        ] else ...[
          // Sample Voice Note Helper Button for instant test/demo
          OutlinedButton.icon(
            icon: const Icon(Icons.auto_fix_high_rounded),
            label: Text(auth.selectedLanguage == 'mr' ? "नमुना आवाज वापरा (Use Sample Voice)" : "नमूना आवाज का उपयोग करें"),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            onPressed: () async {
              await wizard.processVoiceNote(auth.selectedLanguage);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSpecChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }

  void _showEditTranscriptDialog(BuildContext context, ProductWizardProvider wizard, AuthProvider auth) {
    final controller = TextEditingController(text: wizard.voiceTranscript);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(auth.selectedLanguage == 'mr' ? "मजकूर दुरुस्त करा" : "विवरण सुधारें"),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "दुरुस्त केलेला मजकूर येथे लिहा...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("रद्द करा (Cancel)"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
            onPressed: () async {
              Navigator.pop(ctx);
              wizard.updateVoiceTranscript(controller.text);
              await wizard.processVoiceNote(auth.selectedLanguage);
            },
            child: const Text("जतन करा व पुन्हा तपासा"),
          ),
        ],
      ),
    );
  }

  void _showAddMissingInfoDialog(BuildContext context, ProductWizardProvider wizard, AuthProvider auth) {
    final matCtrl = TextEditingController(text: wizard.material);
    final techCtrl = TextEditingController(text: wizard.technique);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(auth.selectedLanguage == 'mr' ? "साहित्य व पद्धत जोडा" : "सामग्री और तकनीक जोड़ें"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: matCtrl,
              decoration: InputDecoration(
                labelText: auth.selectedLanguage == 'mr' ? "वापरलेले साहित्य (Material)" : "सामग्री (Material)",
                hintText: "उदा. नैसर्गिक माती, तांदळाचे पीठ, लाकूड",
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: techCtrl,
              decoration: InputDecoration(
                labelText: auth.selectedLanguage == 'mr' ? "कला पद्धत (Technique)" : "तकनीक (Technique)",
                hintText: "उदा. चाकावर घडवलेले, वारली हाताने रंगवलेले",
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("रद्द करा"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
            onPressed: () async {
              Navigator.pop(ctx);
              final clarification = "साहित्य: ${matCtrl.text.trim()}, पद्धत: ${techCtrl.text.trim()}";
              await wizard.processVoiceNote(auth.selectedLanguage, clarification: clarification);
            },
            child: const Text("पूर्ण करा (Apply)"),
          ),
        ],
      ),
    );
  }

  void _showEditListingDialog(BuildContext context, ProductWizardProvider wizard) {
    final titleCtrl = TextEditingController(text: wizard.titleHi.isNotEmpty ? wizard.titleHi : wizard.titleEn);
    final shortDescCtrl = TextEditingController(text: wizard.shortDescriptionHi.isNotEmpty ? wizard.shortDescriptionHi : wizard.shortDescriptionEn);
    final matCtrl = TextEditingController(text: wizard.material);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("उत्पादन माहिती संपादित करा"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: "शीर्षक (Title)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: shortDescCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: "संक्षिप्त वर्णन (Short Description)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: matCtrl,
                decoration: const InputDecoration(labelText: "साहित्य (Material)", border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("रद्द करा")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
            onPressed: () {
              wizard.updateField(
                titleHi: titleCtrl.text.trim(),
                shortDescriptionHi: shortDescCtrl.text.trim(),
                material: matCtrl.text.trim(),
              );
              Navigator.pop(ctx);
            },
            child: const Text("जतन करा"),
          ),
        ],
      ),
    );
  }

  void _showPreviewDialog(BuildContext context, ProductWizardProvider wizard, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "उत्पादन पूर्वावलोकन (Preview)",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.terracotta),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(),
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderWarm),
                  ),
                  child: const Center(
                    child: Icon(Icons.palette_rounded, size: 70, color: AppTheme.terracotta),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  wizard.titleHi.isNotEmpty ? wizard.titleHi : wizard.titleEn,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(wizard.titleEn, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                Text(
                  wizard.descriptionHi.isNotEmpty ? wizard.descriptionHi : wizard.descriptionEn,
                  style: const TextStyle(fontSize: 14, color: AppTheme.textCharcoal, height: 1.3),
                ),
                const SizedBox(height: 12),
                Text("साहित्य: ${wizard.material.isNotEmpty ? wizard.material : 'उपलब्ध नाही'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("पद्धत: ${wizard.technique.isNotEmpty ? wizard.technique : 'उपलब्ध नाही'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("ठीक आहे (Close)"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Step 4: Intelligent Pricing Assistant ────────────────────────────────
  Widget _buildPricingStep(ProductWizardProvider wizard, AppLocalizations l10n, AuthProvider auth) {
    final isMr = auth.selectedLanguage == 'mr';
    final isHi = auth.selectedLanguage == 'hi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Verification Status & Estimate Disclosure Banner ───────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: wizard.isVerifiedMarketPrice ? Colors.green.shade50 : Colors.amber.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: wizard.isVerifiedMarketPrice ? Colors.green.shade600 : Colors.amber.shade700,
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                wizard.isVerifiedMarketPrice ? Icons.verified_rounded : Icons.info_outline_rounded,
                color: wizard.isVerifiedMarketPrice ? Colors.green.shade700 : Colors.amber.shade900,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wizard.isVerifiedMarketPrice
                          ? (isMr ? "सत्यापित बाजार आधार (Verified Market Price)" : (isHi ? "सत्यापित बाज़ार डेटा" : "Verified Market Benchmark"))
                          : (isMr ? "अंदाजित किंमत (Unverified Cost-Based Estimate)" : (isHi ? "अनुमानित मूल्य (लागत आधार)" : "Unverified Cost-Based Estimate")),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: wizard.isVerifiedMarketPrice ? Colors.green.shade900 : Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      wizard.isVerifiedMarketPrice
                          ? (isMr
                              ? "ही किंमत TRIFED, CCIC व अधिकृत हस्तकला नोंदींमधील प्रत्यक्ष बाजारभावावर आधारित आहे."
                              : "यह मूल्य TRIFED, CCIC व सरकारी बाज़ार बेंचमार्क पर आधारित है।")
                          : (isMr
                              ? "या अचूक कलाकृतीसाठी थेट बाजार नोंद आढळली नाही. त्यामुळे अनधिकृत फुगवलेले भाव न लावता, रास्त मजुरी व खर्चावर आधारित प्रामाणिक अंदाजित किंमत दिली आहे."
                              : "इस विशिष्ट शिल्प हेतु कोई प्रत्यक्ष बाज़ार सूची नहीं मिली। अतः अनुमानित पारदर्शी मजदूरी पर आधारित मूल्य दिया गया है।"),
                      style: TextStyle(
                        fontSize: 12,
                        color: wizard.isVerifiedMarketPrice ? Colors.green.shade900 : Colors.amber.shade900,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── 2. Spoken Audio Explanation Card ─────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.turmericLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.turmeric, width: 1.5),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: isMr ? "किंमतीचा तपशील ऐका" : "मूल्य विवरण सुनें",
                icon: const Icon(Icons.volume_up_rounded, color: AppTheme.turmericDark, size: 28),
                onPressed: () {
                  VoiceGuidanceService.speakPrompt(
                    context,
                    wizard.priceExplanation.isNotEmpty
                        ? wizard.priceExplanation
                        : "साहित्याचा खर्च अधिक तुमचे श्रम यानुसार किमान किंमत ₹${wizard.costFloor.toStringAsFixed(0)} आहे.",
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  wizard.priceExplanation.isNotEmpty
                      ? wizard.priceExplanation
                      : "साहित्याचा खर्च अधिक तुमचे श्रम यानुसार किमान किंमत ₹${wizard.costFloor.toStringAsFixed(0)} आहे.",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textCharcoal, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 3. Itemized Cost Breakdown Card ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderWarm),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: AppTheme.terracotta, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isMr ? "खर्चाचा पारदर्शक तपशील" : (isHi ? "पारदर्शी लागत विवरण" : "Cost Breakdown"),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.terracotta),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.tune_rounded, size: 16, color: AppTheme.terracotta),
                    label: Text(
                      isMr ? "खर्च बदला" : (isHi ? "संपादित करें" : "Edit Costs"),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.terracotta),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.terracotta),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showEditCostsDialog(context, wizard, auth),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              _buildCostRow(isMr ? "कच्चा माल (Materials)" : "कच्चा माल", "₹ ${wizard.materialCost.toStringAsFixed(0)}"),
              _buildCostRow(
                isMr
                    ? "कारागीर श्रम (${wizard.laborHours} तास @ ₹${wizard.hourlyRate.toStringAsFixed(0)}/तास)"
                    : "श्रम (${wizard.laborHours} घंटे @ ₹${wizard.hourlyRate.toStringAsFixed(0)}/घं)",
                "₹ ${(wizard.laborHours * wizard.hourlyRate).toStringAsFixed(0)}",
              ),
              _buildCostRow(isMr ? "पॅकेजिंग साहित्य" : "पैकेजिंग सामग्री", "₹ ${wizard.packagingCost.toStringAsFixed(0)}"),
              _buildCostRow(isMr ? "वाहतूक / कुरिअर" : "परिवहन / डिलीवरी", "₹ ${wizard.shippingCost.toStringAsFixed(0)}"),
              _buildCostRow(
                isMr ? "प्लॅटफॉर्म व बँक गेटवे (8%)" : "प्लेटफ़ॉर्म और बैंक शुल्क (8%)",
                "₹ ${(wizard.costFloor * wizard.platformFeePercent).toStringAsFixed(0)}",
              ),
              const SizedBox(height: 6),
              const Divider(height: 1, thickness: 1.2),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMr ? "किमान सुरक्षित तळ (Cost Floor)" : "न्यूनतम लागत सीमा (Cost Floor)",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textCharcoal),
                  ),
                  Text(
                    "₹ ${wizard.costFloor.toStringAsFixed(0)}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.terracotta),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── 4. Three Distinct Understandable Price Tiers ──────────────────────
        Text(
          isMr ? "किंमत निवडा (Select Price Tier):" : "मूल्य विकल्प चुनें:",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textCharcoal),
        ),
        const SizedBox(height: 10),

        _buildPriceCard(
          title: l10n.translate('costFloor'),
          subtitle: isMr ? "केवळ साहित्याचा व मजुरीचा किमान खर्च भरून काढणारा दर" : l10n.translate('costFloorSub'),
          price: wizard.costFloor,
          isSelected: wizard.acceptedPrice == wizard.costFloor,
          badge: isMr ? "सुरक्षित तळ (Floor)" : "लागत सीमा",
          badgeColor: AppTheme.textMuted,
          onTap: () => wizard.selectPrice(wizard.costFloor),
        ),
        const SizedBox(height: 12),

        _buildPriceCard(
          title: l10n.translate('suggestedPrice'),
          subtitle: isMr ? "बाजारातील स्पर्धात्मक व नफ्यासह योग्य किंमत" : l10n.translate('suggestedPriceSub'),
          price: wizard.suggestedPrice,
          isSelected: wizard.acceptedPrice == wizard.suggestedPrice,
          badge: isMr ? "शिफारस (Recommended)" : "सुझाव",
          badgeColor: AppTheme.terracotta,
          onTap: () => wizard.selectPrice(wizard.suggestedPrice),
        ),
        const SizedBox(height: 12),

        _buildPriceCard(
          title: l10n.translate('premiumPrice'),
          subtitle: isMr ? "विशेष कलाकुसर, भेटवस्तू अथवा आंतरराष्ट्रीय विक्री दर" : l10n.translate('premiumPriceSub'),
          price: wizard.premiumPrice,
          isSelected: wizard.acceptedPrice == wizard.premiumPrice,
          badge: isMr ? "प्रीमियम (Export/Gallery)" : "प्रीमियम",
          badgeColor: AppTheme.indigo,
          onTap: () => wizard.selectPrice(wizard.premiumPrice),
        ),
        const SizedBox(height: 18),

        // ── 5. Artisan Custom Price Override & Warning ────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: wizard.priceOverrideWarning != null ? Colors.red.shade400 : AppTheme.borderWarm,
              width: wizard.priceOverrideWarning != null ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMr ? "स्वतःची पसंतीची किंमत टाका (Custom Price)" : (isHi ? "अपनी मनपसंद कीमत तय करें" : "Custom Price Override"),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textCharcoal),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "उदा. ${wizard.acceptedPrice.toStringAsFixed(0)}",
                        prefixText: "₹ ",
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.terracotta,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onPressed: () {
                      final val = double.tryParse(_customPriceCtrl.text.trim());
                      if (val != null && val > 0) {
                        wizard.applyCustomPriceOverride(val, auth.selectedLanguage);
                      }
                    },
                    child: Text(isMr ? "लागू करा" : "लागू करें"),
                  ),
                ],
              ),
              if (wizard.priceOverrideWarning != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade400),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          wizard.priceOverrideWarning!,
                          style: TextStyle(color: Colors.red.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ── 6. Legitimate Comparable Products / Market Benchmark ──────────────
        if (wizard.comparableProducts.isNotEmpty) ...[
          Text(
            isMr ? "सत्यापित बाजार संदर्भ (Market Benchmarks):" : "तुलनात्मक बाज़ार संदर्भ:",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textCharcoal),
          ),
          const SizedBox(height: 8),
          ...wizard.comparableProducts.map((comp) {
            final pTitle = comp['title'] as String? ?? 'Handicraft Item';
            final pPrice = (comp['price'] as num?)?.toDouble() ?? 0.0;
            final pSource = comp['source_platform'] as String? ?? 'TRIFED';
            final pDate = comp['retrieval_date'] as String? ?? '';
            final pScore = (comp['similarity_score'] as num?)?.toDouble() ?? 0.8;
            final pUrl = comp['source_url'] as String? ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          pTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "₹ ${pPrice.toStringAsFixed(0)}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.indigo),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Text(
                          pSource,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo.shade800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isMr ? "तपासणी: $pDate" : "सत्यापित: $pDate",
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                      const Spacer(),
                      Text(
                        "${(pScore * 100).toStringAsFixed(0)}% ${isMr ? 'जुळणी' : 'समानता'}",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade800),
                      ),
                    ],
                  ),
                  if (pUrl.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      pUrl,
                      style: TextStyle(fontSize: 10, color: Colors.blue.shade700, decoration: TextDecoration.underline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
        ],

        // ── 7. Influencing Factors ───────────────────────────────────────────
        if (wizard.influencingFactors.isNotEmpty) ...[
          Text(
            isMr ? "किंमतीवर प्रभाव टाकणारे घटक:" : "मूल्य निर्धारक घटक:",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textCharcoal),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: wizard.influencingFactors.map((factor) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundSand,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderWarm),
                ),
                child: Text(
                  factor,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textCharcoal, fontWeight: FontWeight.w500),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
        ],

        // ── 8. Acceptance CTA ────────────────────────────────────────────────
        ElevatedButton.icon(
          icon: const Icon(Icons.check_rounded, size: 24),
          label: Text(
            isMr
                ? "स्वीकारा: ₹ ${wizard.acceptedPrice.toStringAsFixed(0)} (पुढे जा)"
                : "स्वीकारें: ₹ ${wizard.acceptedPrice.toStringAsFixed(0)}",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            wizard.nextStep();
          },
        ),
      ],
    );
  }

  Widget _buildCostRow(String title, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 13, color: AppTheme.textCharcoal)),
          ),
          Text(amount, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textCharcoal)),
        ],
      ),
    );
  }

  void _showEditCostsDialog(BuildContext context, ProductWizardProvider wizard, AuthProvider auth) {
    final matCtrl = TextEditingController(text: wizard.materialCost.toStringAsFixed(0));
    final hoursCtrl = TextEditingController(text: wizard.laborHours.toString());
    final rateCtrl = TextEditingController(text: wizard.hourlyRate.toStringAsFixed(0));
    final packCtrl = TextEditingController(text: wizard.packagingCost.toStringAsFixed(0));
    final shipCtrl = TextEditingController(text: wizard.shippingCost.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          auth.selectedLanguage == 'mr' ? "खर्चाचा तपशील बदला" : "लागत विवरण संपादित करें",
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.terracotta),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: matCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: auth.selectedLanguage == 'mr' ? "कच्चा माल खर्च (₹)" : "सामग्री लागत (₹)",
                  border: const OutlineInputBorder(),
                  prefixText: "₹ ",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hoursCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: auth.selectedLanguage == 'mr' ? "कामाचे तास (Labour Hours)" : "श्रम के घंटे",
                  border: const OutlineInputBorder(),
                  suffixText: "तास",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: auth.selectedLanguage == 'mr' ? "दर तास मजुरी (Hourly Wage Rate ₹)" : "प्रति घंटा दर (₹)",
                  border: const OutlineInputBorder(),
                  prefixText: "₹ ",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: packCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: auth.selectedLanguage == 'mr' ? "पॅकेजिंग खर्च (₹)" : "पैकेजिंग लागत (₹)",
                  border: const OutlineInputBorder(),
                  prefixText: "₹ ",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: shipCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: auth.selectedLanguage == 'mr' ? "वाहतूक / डिलिव्हरी (₹)" : "शिपिंग / परिवहन (₹)",
                  border: const OutlineInputBorder(),
                  prefixText: "₹ ",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(auth.selectedLanguage == 'mr' ? "रद्द करा" : "रद्द करें"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
            onPressed: () async {
              Navigator.pop(ctx);
              final mCost = double.tryParse(matCtrl.text.trim()) ?? wizard.materialCost;
              final lHrs = double.tryParse(hoursCtrl.text.trim()) ?? wizard.laborHours;
              final hRate = double.tryParse(rateCtrl.text.trim()) ?? wizard.hourlyRate;
              final pCost = double.tryParse(packCtrl.text.trim()) ?? wizard.packagingCost;
              final sCost = double.tryParse(shipCtrl.text.trim()) ?? wizard.shippingCost;

              await wizard.recalculatePricing(
                materialCost: mCost,
                laborHours: lHrs,
                hourlyRate: hRate,
                packagingCost: pCost,
                shippingCost: sCost,
                language: auth.selectedLanguage,
              );
            },
            child: Text(auth.selectedLanguage == 'mr' ? "पुन्हा मोजा (Calculate)" : "पुनर्गणना करें"),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard({
    required String title,
    required String subtitle,
    required double price,
    required bool isSelected,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppTheme.terracotta : AppTheme.borderWarm,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.terracotta.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppTheme.terracotta : AppTheme.textMuted,
              size: 26,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
            Text(
              "₹ ${price.toStringAsFixed(0)}",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.terracotta : AppTheme.textCharcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step 5: Publish Live ──────────────────────────────────────────────────
  Widget _buildPublishStep(ProductWizardProvider wizard, AppLocalizations l10n, AuthProvider auth) {
    final isMr = auth.selectedLanguage == 'mr';

    // ── 1. Success State ─────────────────────────────────────────────────────
    if (wizard.isPublished) {
      return Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: AppTheme.successGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 54),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.translate('publishedSuccess'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textCharcoal),
          ),
          if (wizard.publishedProductId != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.indigoLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "उत्पादन क्रमांक: #${wizard.publishedProductId} (Live on Website)",
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.indigo, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            "कलासाथी ई-कॉमर्स वेबसाइटवर उत्पादन क्षणात उपलब्ध झाले आहे! खरेदीदार आता हे उत्पादन पाहू व खरेदी करू शकतात.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.storefront_rounded),
            label: Text(l10n.translate('viewWebsite')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.indigo,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            child: const Text("डॅशबोर्डवर परत जा (Back to Home)"),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      );
    }

    // ── 2. Draft & Pre-Publish Review State ───────────────────────────────────
    final primaryImgBase64 = wizard.enhancedImageBase64;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Draft indicator banner if already saved
        if (wizard.isDraftSaved || wizard.draftProductId != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.indigoLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.indigo.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bookmark_added_rounded, color: AppTheme.indigo, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isMr
                        ? "मसुदा सुरक्षित जतन केला आहे${wizard.draftProductId != null ? ' (#${wizard.draftProductId})' : ''}. आता अंतिम प्रसिद्धी करा."
                        : "ड्राफ़्ट सुरक्षित है। लाइव प्रकाशित करने के लिए नीचे टैप करें।",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.indigo),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Product Summary Card with Actual Selected Image
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderWarm, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Actual Selected/Enhanced Image Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey.shade100,
                      child: primaryImgBase64 != null
                          ? (primaryImgBase64.startsWith('data:image')
                              ? Image.memory(
                                  base64Decode(primaryImgBase64.split(',').last),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey),
                                )
                              : Image.network(
                                  primaryImgBase64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey),
                                ))
                          : (wizard.photos.isNotEmpty
                              ? Image.memory(wizard.photos[0], fit: BoxFit.cover)
                              : const Icon(Icons.palette_rounded, size: 40, color: AppTheme.terracotta)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wizard.titleHi.isNotEmpty ? wizard.titleHi : wizard.titleEn,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (wizard.titleEn.isNotEmpty && wizard.titleHi.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            wizard.titleEn,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          "किंमत: ₹ ${wizard.acceptedPrice.toStringAsFixed(0)}",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.terracotta),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMr ? "साहित्य (Material):" : "सामग्री:",
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  Text(
                    wizard.material.isNotEmpty ? wizard.material : "अस्सल पारंपारिक",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMr ? "कला पद्धत (Technique):" : "तकनीक:",
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  Text(
                    wizard.technique.isNotEmpty ? wizard.technique : "हस्तनिर्मित",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMr ? "विक्रीसाठी उपलब्ध नग (Stock):" : "स्टॉक (Stock):",
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppTheme.textMuted),
                        visualDensity: VisualDensity.compact,
                        onPressed: wizard.inventoryStock > 1
                            ? () => wizard.setInventoryStock(wizard.inventoryStock - 1)
                            : null,
                      ),
                      Text(
                        "${wizard.inventoryStock} नग",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.indigo),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20, color: AppTheme.indigo),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => wizard.setInventoryStock(wizard.inventoryStock + 1),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.successGreenLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.translate_rounded, color: AppTheme.successGreen, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isMr ? "१२ भारतीय भाषांमध्ये सूची तयार आहे." : "12 भारतीय भाषाओं में अनुवाद तैयार है।",
                        style: const TextStyle(fontSize: 11, color: AppTheme.successGreen, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ── 3. Failure State Alert & Retry ────────────────────────────────────
        if (wizard.publishError != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMr ? "प्रकाशन अयशस्वी" : "प्रकाशन विफल",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        wizard.publishError!,
                        style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // ── 4. Large Action Buttons (Save Draft + One-Tap Publish) ───────────
        ElevatedButton.icon(
          icon: wizard.isPublishing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : const Icon(Icons.rocket_launch_rounded, size: 26),
          label: Text(
            wizard.isPublishing
                ? (isMr ? "वेबसाइटवर पाठवत आहे..." : "प्रकाशित हो रहा है...")
                : (wizard.publishError != null
                    ? (isMr ? "पुन्हा प्रयत्न करा (Retry)" : "पुनः प्रयास करें")
                    : l10n.translate('publishNow')),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successGreen,
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
          onPressed: wizard.isPublishing
              ? null
              : () async {
                  await wizard.publishProduct(auth.authToken ?? "mock_token");
                },
        ),
        const SizedBox(height: 12),

        if (!wizard.isDraftSaved && !wizard.isPublishing) ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.save_as_rounded, size: 20, color: AppTheme.indigo),
            label: Text(isMr ? "मसुदा म्हणून जतन करा (Save Draft)" : "ड्राफ़्ट के रूप में सहेजें"),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.indigo),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              await wizard.saveAsDraft(auth.authToken ?? "mock_token");
            },
          ),
        ],
      ],
    );
  }
}
