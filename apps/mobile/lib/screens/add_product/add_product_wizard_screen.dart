import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/providers/product_wizard_provider.dart';
import 'package:kalasathi_mobile/screens/onboarding_screen.dart';
import 'package:kalasathi_mobile/services/voice_guidance_service.dart';
import 'package:kalasathi_mobile/theme/app_theme.dart';
import 'package:kalasathi_mobile/widgets/voice_help_fab.dart';

class AddProductWizardScreen extends StatefulWidget {
  const AddProductWizardScreen({super.key});

  @override
  State<AddProductWizardScreen> createState() => _AddProductWizardScreenState();
}

class _AddProductWizardScreenState extends State<AddProductWizardScreen> {
  late final TextEditingController _customPriceCtrl;
  late final TextEditingController _englishDescriptionCtrl;
  late final TextEditingController _finalPriceCtrl;
  final FocusNode _englishDescriptionFocus = FocusNode();
  final FocusNode _finalPriceFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _customPriceCtrl = TextEditingController();
    _englishDescriptionCtrl = TextEditingController();
    _finalPriceCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wizard = Provider.of<ProductWizardProvider>(context, listen: false);
      final language =
          Provider.of<AuthProvider>(context, listen: false).selectedLanguage;
      wizard.resetWizard();
      wizard.loadSpeechLocales(preferredLanguage: language);
    });
  }

  @override
  void dispose() {
    _customPriceCtrl.dispose();
    _englishDescriptionCtrl.dispose();
    _finalPriceCtrl.dispose();
    _englishDescriptionFocus.dispose();
    _finalPriceFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wizard = Provider.of<ProductWizardProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    if (!_englishDescriptionFocus.hasFocus &&
        _englishDescriptionCtrl.text != wizard.descriptionEn) {
      _englishDescriptionCtrl.text = wizard.descriptionEn;
    }
    final finalPriceText =
        wizard.acceptedPrice > 0 ? wizard.acceptedPrice.toStringAsFixed(2) : '';
    if (!_finalPriceFocus.hasFocus && _finalPriceCtrl.text != finalPriceText) {
      _finalPriceCtrl.text = finalPriceText;
    }

    final stepTitles = [
      l10n.translate('stepCamera'),
      l10n.translate('stepVoice'),
      l10n.translate('stepStudio'),
      l10n.translate('stepPricing'),
      l10n.translate('stepPublish'),
    ];

    final stepHelp = [
      l10n.translate('helpCamera'),
      l10n.translate('helpVoice'),
      l10n.translate('helpStudio'),
      l10n.translate('helpPricing'),
      l10n.translate('helpPublish'),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundSand,
      appBar: AppBar(
        title: Text(stepTitles[wizard.currentStep]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: wizard.isPublishing
              ? null
              : () {
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
                        color: isPassed
                            ? AppTheme.terracotta
                            : AppTheme.borderWarm,
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
                key: ValueKey('wizard_step_${wizard.currentStep}'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _buildStepContent(wizard, l10n, auth),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(
      ProductWizardProvider wizard, AppLocalizations l10n, AuthProvider auth) {
    switch (wizard.currentStep) {
      case 0:
        return _buildCameraStep(wizard, l10n, auth);
      case 1:
        return _buildVoiceStep(wizard, l10n, auth);
      case 2:
        return _buildStudioStep(wizard, l10n, auth);
      case 3:
        return _buildPricingStep(wizard, l10n, auth);
      case 4:
        return _buildPublishStep(wizard, l10n, auth);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Step 1: Smart Camera ──────────────────────────────────────────────────
  Widget _buildCameraStep(
      ProductWizardProvider wizard, AppLocalizations l10n, AuthProvider auth) {
    final hasPhoto = wizard.photos.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Camera / Image Preview Card
        Container(
          width: double.infinity,
          height: 270,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1C1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: hasPhoto
                  ? AppTheme.terracotta
                  : AppTheme.terracotta.withOpacity(0.4),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (hasPhoto) ...[
                // Captured photo preview
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.memory(
                    wizard.photos.first,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                // Badge: Original Photo Verified
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: AppTheme.successGreen, width: 1.5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: AppTheme.successGreen, size: 16),
                        SizedBox(width: 6),
                        Text(
                          "मूळ फोटो तयार (Original Photo)",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Professional Viewfinder Simulation
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppTheme.turmeric.withOpacity(0.5), width: 1.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      // Framing corners
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                  color: AppTheme.turmeric, width: 3),
                              left: BorderSide(
                                  color: AppTheme.turmeric, width: 3),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                  color: AppTheme.turmeric, width: 3),
                              right: BorderSide(
                                  color: AppTheme.turmeric, width: 3),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: AppTheme.turmeric, width: 3),
                              left: BorderSide(
                                  color: AppTheme.turmeric, width: 3),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: AppTheme.turmeric, width: 3),
                              right: BorderSide(
                                  color: AppTheme.turmeric, width: 3),
                            ),
                          ),
                        ),
                      ),
                      const Center(
                        child: Icon(Icons.photo_camera_rounded,
                            size: 76, color: Color(0xFFC85A32)),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 20,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      l10n.translate('cameraKeepInFrame'),
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Photography Guidance Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.turmericLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.turmeric.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      color: AppTheme.turmericDark, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.translate('cameraGuidanceTitle'),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textCharcoal),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                l10n.translate('cameraGuidanceTips'),
                style: TextStyle(
                    fontSize: 12, height: 1.4, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Native Capture and Gallery Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_rounded, size: 22),
                label: Text(hasPhoto
                    ? l10n.translate('cameraRetake')
                    : l10n.translate('capturePhoto')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.terracotta,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: wizard.isUploadingPhoto
                    ? null
                    : () async {
                        final success = await wizard.pickImageFromCamera(
                            token: auth.authToken);
                        if (!mounted) return;
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.translate('cameraCaptured')),
                              duration: Duration(seconds: 1),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                        } else {
                          if (wizard.lastCameraError != null) {
                            _showCameraPermissionDialog(
                                context, wizard.lastCameraError!);
                          } else if (wizard.photoUploadError != null) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(wizard.photoUploadError!)));
                          }
                        }
                      },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_rounded,
                    size: 22, color: AppTheme.terracotta),
                label: Text(
                  hasPhoto
                      ? l10n.translate('cameraChangeFromGallery')
                      : l10n.translate('cameraChooseFromGallery'),
                  style: const TextStyle(
                      color: AppTheme.terracotta, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side:
                      const BorderSide(color: AppTheme.terracotta, width: 1.8),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: wizard.isUploadingPhoto
                    ? null
                    : () async {
                        final success = await wizard.pickImageFromGallery(
                            token: auth.authToken);
                        if (!mounted) return;
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text(l10n.translate('cameraImageSelected')),
                              duration: Duration(seconds: 1),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                        } else {
                          if (wizard.lastCameraError != null) {
                            _showGalleryPermissionDialog(
                                context, wizard.lastCameraError!);
                          } else if (wizard.photoUploadError != null) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(wizard.photoUploadError!)));
                          }
                        }
                      },
              ),
            ),
          ],
        ),

        if (wizard.isUploadingPhoto) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(color: AppTheme.terracotta),
          const SizedBox(height: 6),
          const Text('Uploading original photo to your draft…',
              textAlign: TextAlign.center),
        ],
        if (wizard.photoUploadError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text(wizard.photoUploadError!,
                        style: TextStyle(color: Colors.red.shade800))),
                if (wizard.canRetryPhotoUpload &&
                    wizard.photoUploadRequiresAuthentication)
                  TextButton(
                    onPressed: wizard.isUploadingPhoto
                        ? null
                        : () async {
                            final phone =
                                auth.artisanProfile?['phone']?.toString();
                            await auth.logout();
                            if (!mounted) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OnboardingScreen(
                                  initialPhone: phone,
                                  popOnSuccess: true,
                                ),
                              ),
                            );
                          },
                    child: const Text('Sign in again'),
                  )
                else if (wizard.canRetryPhotoUpload)
                  TextButton(
                    onPressed: wizard.isUploadingPhoto
                        ? null
                        : () => wizard.retryPhotoUpload(auth.authToken),
                    child: const Text('Retry'),
                  ),
              ],
            ),
          ),
        ],

        if (hasPhoto) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: Colors.redAccent),
              label: Text(
                l10n.translate('cameraRemovePhoto'),
                style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              onPressed: wizard.isUploadingPhoto
                  ? null
                  : () async {
                      final removed =
                          await wizard.clearPhotos(token: auth.authToken);
                      if (!mounted) return;
                      if (!removed && wizard.photoUploadError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(wizard.photoUploadError!)));
                      }
                    },
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Quick Preset Sample Craft selector
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderWarm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.palette_outlined,
                      size: 18, color: AppTheme.terracotta),
                  SizedBox(width: 6),
                  Text(
                    l10n.translate('cameraTrySample'),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.textCharcoal),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: const Text("🏺"),
                    label: Text(l10n.translate('craftPottery'),
                        style: const TextStyle(fontSize: 12)),
                    onPressed: () => wizard
                        .loadSamplePhoto('assets/images/prod_pottery.jpg'),
                  ),
                  ActionChip(
                    avatar: const Text("🧵"),
                    label: Text(l10n.translate('craftHandloom'),
                        style: const TextStyle(fontSize: 12)),
                    onPressed: () => wizard
                        .loadSamplePhoto('assets/images/prod_handloom.jpg'),
                  ),
                  ActionChip(
                    avatar: const Text("💍"),
                    label: Text(l10n.translate('craftJewelry'),
                        style: const TextStyle(fontSize: 12)),
                    onPressed: () => wizard
                        .loadSamplePhoto('assets/images/prod_jewelry.jpg'),
                  ),
                  ActionChip(
                    avatar: const Text("🪵"),
                    label: Text(l10n.translate('craftWoodcraft'),
                        style: const TextStyle(fontSize: 12)),
                    onPressed: () => wizard
                        .loadSamplePhoto('assets/images/prod_woodcraft.jpg'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Continue to AI Studio Button (Enabled only if valid photo selected)
        ElevatedButton.icon(
          icon: const Icon(Icons.auto_awesome_rounded, size: 24),
          label: Text(
            !hasPhoto
                ? l10n.translate('cameraTakeOrChooseFirst')
                : !wizard.isCurrentPhotoUploaded
                    ? 'Upload the original photo before continuing'
                    : l10n.translate('cameraContinueDetails'),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: hasPhoto &&
                    wizard.isCurrentPhotoUploaded &&
                    !wizard.isUploadingPhoto
                ? AppTheme.indigo
                : Colors.grey.shade400,
            minimumSize: const Size.fromHeight(56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: hasPhoto &&
                  wizard.isCurrentPhotoUploaded &&
                  !wizard.isUploadingPhoto
              ? () {
                  wizard.nextStep();
                }
              : null,
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  // ─── Step 2: AI Image Studio & 10 Variations Selection ────────────────────
  Widget _buildStudioStep(
      ProductWizardProvider wizard, AppLocalizations l10n, AuthProvider auth) {
    if (wizard.isProcessingAI) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 20),
          child: Column(
            children: [
              const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                    color: AppTheme.terracotta, strokeWidth: 4.5),
              ),
              const SizedBox(height: 28),
              Text(
                wizard.imageJobStatus == 'uploading'
                    ? "उत्पादनाचा फोटो सुरक्षितपणे अपलोड करत आहे..."
                    : "एआय स्टुडिओ उत्पादनाचा फोटो प्रक्रिया करत आहे...",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textCharcoal),
              ),
              const SizedBox(height: 8),
              Text(
                wizard.imageJobStatus == 'uploading'
                    ? "Uploading your original product photo securely..."
                    : "CrewAI is processing the original photo and preparing catalog backgrounds...",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.turmericLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.turmeric.withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded,
                        color: AppTheme.turmericDark, size: 18),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "हस्तकलेचा मूळ आकार, रंग व नक्षी जतन केली जात आहे",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textCharcoal),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final variations = wizard.imageVariations;
    final selectedIds = wizard.selectedVariationIds;
    final isExact3 =
        selectedIds.length == 3 && wizard.imageJobStatus == 'completed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wizard.imageJobError != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wizard.imageJobError!,
                    style: TextStyle(color: Colors.orange.shade900)),
                if (wizard.imageJobStatus != 'retake_required' &&
                    wizard.imageJobStatus != 'awaiting_review')
                  TextButton.icon(
                    onPressed: () => wizard.retryImageJob(auth.authToken ?? ''),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry image processing'),
                  ),
              ],
            ),
          ),
        ],
        if (wizard.imageJobStatus == 'awaiting_review' &&
            variations.length >= 3) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text(
                  'I reviewed these images; the original product is preserved'),
              onPressed: () => wizard.approveImageReview(auth.authToken ?? ''),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Top Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderWarm),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Choose Your Best 3 Photos",
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textCharcoal,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 3),
              Text(
                "तुमचे ३ सर्वोत्तम फोटो निवडा",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.terracottaDark),
              ),
              SizedBox(height: 5),
              Text(
                "Review the processed product images, then select exactly three for your website catalog.",
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textMuted, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Live Selection Counter & Actions Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Live Counter Pill: "X of 3 selected"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isExact3
                    ? AppTheme.successGreenLight
                    : AppTheme.terracottaLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isExact3 ? AppTheme.successGreen : AppTheme.terracotta,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isExact3
                        ? Icons.check_circle_rounded
                        : Icons.photo_library_rounded,
                    color:
                        isExact3 ? AppTheme.successGreen : AppTheme.terracotta,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isExact3
                        ? "3 of 3 selected (३ पैकी ३ निवडले)"
                        : "${selectedIds.length} of 3 selected (३ पैकी ${selectedIds.length} निवडले)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isExact3
                          ? AppTheme.successGreen
                          : AppTheme.terracottaDark,
                    ),
                  ),
                ],
              ),
            ),

            // Regenerate Images Button with confirmation
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded,
                  size: 16, color: AppTheme.indigo),
              label: const Text(
                "पुन्हा तयार करा",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.indigo),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.indigo, width: 1.2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () =>
                  _showRegenerateConfirmDialog(context, wizard, auth),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Responsive Grid of 10 Variations
        if (variations.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: variations.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final variation = variations[index];
              final varId = variation['id'] as String;
              final isSelected = selectedIds.contains(varId);
              final isPrimary =
                  selectedIds.isNotEmpty && selectedIds.first == varId;
              final titleMr = variation['title_mr'] ??
                  variation['title'] ??
                  'पर्याय ${index + 1}';
              final titleEn = variation['title'] ?? 'Variation ${index + 1}';

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  final allowed = wizard.toggleVariationSelection(varId);
                  if (!allowed) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          "तुम्ही जास्तीत जास्त ३ फोटो निवडू शकता. कृपया आधी एक अनसिलेक्ट करा.\n(You can only select up to 3 photos. Please deselect one first.)",
                        ),
                        backgroundColor: AppTheme.terracotta,
                        duration: const Duration(seconds: 2),
                        action: SnackBarAction(
                          label: "समजले",
                          textColor: Colors.white,
                          onPressed: () {},
                        ),
                      ),
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.terracotta
                          : AppTheme.borderWarm,
                      width: isSelected ? 3.0 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? AppTheme.terracotta.withOpacity(0.2)
                            : Colors.black.withOpacity(0.04),
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
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16)),
                              child: _buildVariationThumbnail(variation),
                            ),
                            // Top Right Selection Badge / Checkbox
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.terracotta
                                      : Colors.white.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.terracotta
                                        : AppTheme.textMuted,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check_rounded,
                                        size: 18, color: Colors.white)
                                    : null,
                              ),
                            ),
                            // Top Left Primary / Hero Tag
                            if (isPrimary)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successGreen,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    "मुख्य चित्र",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            // Zoom / Fullscreen Preview Icon
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () =>
                                    _showImagePreviewDialog(context, variation),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.65),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.zoom_in_rounded,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Title caption
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 7),
                        child: Column(
                          children: [
                            Text(
                              titleMr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: isSelected
                                    ? AppTheme.terracottaDark
                                    : AppTheme.textCharcoal,
                              ),
                            ),
                            Text(
                              titleEn,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 10, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
        else
          // Fallback if variations failed
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text("पर्याय लोड होत आहेत... (Loading variations...)"),
            ),
          ),

        const SizedBox(height: 24),

        // Continue Button: Strictly disabled until exactly 3 photos are selected
        ElevatedButton.icon(
          icon: const Icon(Icons.arrow_forward_rounded, size: 24),
          label: Text(
            isExact3
                ? "पुढे जा: किंमत ठरवा (३ निवडले)"
                : "पुढे जाण्यासाठी बरोबर ३ फोटो निवडा (${selectedIds.length}/3 निवडले)",
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isExact3 ? AppTheme.indigo : Colors.grey.shade400,
            minimumSize: const Size.fromHeight(56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: isExact3
              ? () async {
                  final saved =
                      await wizard.saveImageSelection(auth.authToken ?? '');
                  if (saved) {
                    await wizard.loadPricingRecommendation(
                        token: auth.authToken ?? '');
                    wizard.nextStep();
                  }
                }
              : null,
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  void _showCameraPermissionDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.camera_alt_outlined,
                color: AppTheme.terracotta, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "कॅमेरा परवानगी आवश्यक",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error,
                style: const TextStyle(
                    fontSize: 13, height: 1.4, color: AppTheme.textCharcoal)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.turmericLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.turmeric.withOpacity(0.4)),
              ),
              child: const Text(
                "पर्याय: आपण थेट 'गॅलरीतून निवडा' वापरू शकता किंवा खालील त्वरित नमुना हस्तकला निवडून सुरू करू शकता.",
                style: TextStyle(fontSize: 12, color: AppTheme.textCharcoal),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.terracotta,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("समजले (OK)",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showGalleryPermissionDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.photo_library_outlined,
                color: AppTheme.terracotta, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "गॅलरी परवानगी आवश्यक",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error,
                style: const TextStyle(
                    fontSize: 13, height: 1.4, color: AppTheme.textCharcoal)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.terracotta,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("समजले (OK)",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showRegenerateConfirmDialog(
      BuildContext context, ProductWizardProvider wizard, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("नवीन पर्याय तयार करायचे का?"),
        content: const Text(
          "यामुळे सध्याचे पर्याय बदलतील आणि पुन्हा प्रक्रिया होईल.\n(This will replace the current options and process the photo again.)",
        ),
        actions: [
          TextButton(
            child: const Text("रद्द करा (Cancel)"),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
            child: const Text("पुन्हा तयार करा (Regenerate)"),
            onPressed: () {
              Navigator.pop(ctx);
              wizard.processPhotoInAIStudio(
                  token: auth.authToken ?? '', forceRegenerate: true);
            },
          ),
        ],
      ),
    );
  }

  void _showImagePreviewDialog(
      BuildContext context, Map<String, dynamic> variation) {
    final titleMr = variation['title_mr'] ?? variation['title'] ?? 'पर्याय';
    final titleEn = variation['title'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 320,
                width: double.infinity,
                child: _buildVariationThumbnail(variation),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    titleMr,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textCharcoal),
                    textAlign: TextAlign.center,
                  ),
                  if (titleEn.isNotEmpty)
                    Text(
                      titleEn,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.terracotta),
                    child: const Text("बंद करा (Close)"),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariationThumbnail(dynamic variation) {
    String url = '';
    if (variation is Map) {
      final dataUri = variation['data_uri'] as String? ?? '';
      final imageUrl = variation['image_url'] as String? ?? '';
      url = dataUri.isNotEmpty ? dataUri : imageUrl;
    } else if (variation is String) {
      url = variation;
    }

    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Container(
            color: AppTheme.backgroundSand,
            child: const Icon(Icons.broken_image, color: AppTheme.textMuted),
          ),
        );
      } catch (_) {}
    } else if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) =>
            const Icon(Icons.broken_image, color: AppTheme.textMuted),
      );
    }
    return Container(
      color: AppTheme.backgroundSand,
      child: const Icon(Icons.image, color: AppTheme.textMuted),
    );
  }

  // ─── Step 3: Regional-Language Voice Cataloging ───────────────────────────
  Widget _buildVoiceStep(
      ProductWizardProvider wizard, AppLocalizations l10n, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          l10n.translate('voicePrompt'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textCharcoal),
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
        if (wizard.speechLocales.isNotEmpty)
          DropdownButton<String>(
            value: wizard.speechLocales.any((locale) =>
                    locale.localeId.toLowerCase().split(RegExp('[-_]')).first ==
                    wizard.voiceLanguage)
                ? wizard.voiceLanguage
                : wizard.speechLocales.first.localeId
                    .toLowerCase()
                    .split(RegExp('[-_]'))
                    .first,
            items: wizard.speechLocales
                .map((locale) => DropdownMenuItem<String>(
                      value: locale.localeId
                          .toLowerCase()
                          .split(RegExp('[-_]'))
                          .first,
                      child: Text('${locale.name} (${locale.localeId})'),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) wizard.setVoiceLanguage(value);
            },
          ),
        GestureDetector(
          onTap: () async {
            if (wizard.isRecording) {
              await wizard.stopSpeechRecognition();
              await wizard.processVoiceNote(auth.selectedLanguage,
                  token: auth.authToken ?? '');
            } else {
              await wizard.startSpeechRecognition();
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
                  color: (wizard.isRecording ? Colors.red : AppTheme.terracotta)
                      .withOpacity(0.35),
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
              ? (auth.selectedLanguage == 'mr'
                  ? 'बोलत रहा... (ऐकत आहोत)'
                  : 'बोलते रहें... (सुन रहे हैं)')
              : (wizard.voiceTranscript.isEmpty
                  ? l10n.translate('startRecording')
                  : (auth.selectedLanguage == 'mr'
                      ? 'पुन्हा रेकॉर्ड करा (Tap to Re-record)'
                      : 'फिर से रिकॉर्ड करें')),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: wizard.isRecording ? Colors.red : AppTheme.textCharcoal,
          ),
        ),
        const SizedBox(height: 20),

        if (wizard.speechError != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(wizard.speechError!,
                      style: TextStyle(color: Colors.red.shade800)),
                ),
                if (wizard.voiceTranscript.trim().isNotEmpty)
                  TextButton(
                    onPressed: wizard.isProcessingAI
                        ? null
                        : () => wizard.processVoiceNote(
                              auth.selectedLanguage,
                              token: auth.authToken ?? '',
                            ),
                    child: const Text('Retry'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (wizard.isProcessingAI)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Column(
              children: [
                const CircularProgressIndicator(
                    color: AppTheme.terracotta, strokeWidth: 3.5),
                const SizedBox(height: 16),
                Text(
                  auth.selectedLanguage == 'mr'
                      ? "आवाज समजून घेत आहे आणि १२ भाषांमध्ये अनुवाद करत आहे..."
                      : "आवाज से कैटलॉग तैयार हो रहा है और अनुवाद किया जा रहा है...",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppTheme.textMuted),
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
                        const Icon(Icons.record_voice_over_rounded,
                            color: AppTheme.terracotta, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          auth.selectedLanguage == 'mr'
                              ? "तुमचा मूळ आवाज"
                              : "आपका बोला गया विवरण",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.terracotta),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: "ऐका",
                          icon: const Icon(Icons.volume_up_rounded,
                              color: AppTheme.indigo),
                          onPressed: () {
                            VoiceGuidanceService.speakPrompt(
                                context, wizard.voiceTranscript);
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.edit_rounded,
                              size: 16, color: AppTheme.terracotta),
                          label: Text(
                            auth.selectedLanguage == 'mr'
                                ? "दुरुस्त करा"
                                : "सुधारें",
                            style: const TextStyle(
                                color: AppTheme.terracotta,
                                fontWeight: FontWeight.bold),
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
                  style: const TextStyle(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textCharcoal),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderWarm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('English product description',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textCharcoal)),
                if (wizard.descriptionNeedsReview) ...[
                  const SizedBox(height: 6),
                  const Text('Please review this translation carefully.',
                      style: TextStyle(color: Colors.deepOrange)),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: _englishDescriptionCtrl,
                  focusNode: _englishDescriptionFocus,
                  minLines: 3,
                  maxLines: 6,
                  onChanged: wizard.updateEnglishDescription,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Review and edit the English description',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: wizard.englishDescriptionConfirmed,
                  onChanged: (value) =>
                      wizard.confirmEnglishDescription(value ?? false),
                  title: const Text(
                      'I confirm this English description is accurate.'),
                  controlAffinity: ListTileControlAffinity.leading,
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
                      const Icon(Icons.info_outline_rounded,
                          color: AppTheme.turmericDark, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        auth.selectedLanguage == 'mr'
                            ? "अपूर्ण माहिती"
                            : "आवश्यक विवरण बाकी है",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.turmericDark,
                            fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    wizard.missingInfoPrompt ??
                        (auth.selectedLanguage == 'mr'
                            ? "कृपया हे शिल्प बनवण्यासाठी वापरलेले साहित्य व पद्धत सांगा."
                            : "कृपया इस शिल्प में प्रयुक्त सामग्री और तकनीक बताएं।"),
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textCharcoal,
                        height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(auth.selectedLanguage == 'mr'
                            ? "माहिती जोडा"
                            : "विवरण जोड़ें"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.turmericDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
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
                        wizard.titleHi.isNotEmpty
                            ? wizard.titleHi
                            : wizard.titleEn,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textCharcoal),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded,
                          color: AppTheme.terracotta),
                      onPressed: () => _showEditListingDialog(context, wizard),
                    ),
                  ],
                ),
                Text(
                  wizard.titleEn,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                      fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 12),

                // Short summary description
                if (wizard.shortDescriptionHi.isNotEmpty ||
                    wizard.shortDescriptionEn.isNotEmpty) ...[
                  Text(
                    wizard.shortDescriptionHi.isNotEmpty
                        ? wizard.shortDescriptionHi
                        : wizard.shortDescriptionEn,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textCharcoal,
                        fontWeight: FontWeight.w500),
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
                          : (auth.selectedLanguage == 'mr'
                              ? 'साहित्य बाकी'
                              : 'सामग्री बाकी'),
                      color: wizard.material.isNotEmpty
                          ? Colors.blue.shade50
                          : Colors.red.shade50,
                      textColor: wizard.material.isNotEmpty
                          ? Colors.blue.shade800
                          : Colors.red.shade800,
                    ),
                    _buildSpecChip(
                      icon: Icons.brush_rounded,
                      label: wizard.technique.isNotEmpty
                          ? wizard.technique
                          : (auth.selectedLanguage == 'mr'
                              ? 'पद्धत बाकी'
                              : 'तकनीक बाकी'),
                      color: wizard.technique.isNotEmpty
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      textColor: wizard.technique.isNotEmpty
                          ? Colors.green.shade800
                          : Colors.orange.shade800,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 12-Language translations badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.translate_rounded,
                          size: 16, color: Colors.purple.shade700),
                      const SizedBox(width: 6),
                      Text(
                        auth.selectedLanguage == 'mr'
                            ? "१२ भारतीय भाषांमध्ये अनुवादित (12 Languages Ready)"
                            : "12 भारतीय भाषाओं में अनुवाद तैयार है",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade800),
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
              auth.selectedLanguage == 'mr'
                  ? "संपूर्ण माहिती मोठ्याने ऐका"
                  : "पूरी जानकारी सुनें",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {
              final spokenText =
                  wizard.getListingSummaryForSpeech(auth.selectedLanguage);
              VoiceGuidanceService.speakPrompt(context, spokenText);
            },
          ),
          const SizedBox(height: 12),

          // ─── 5. Actions: Save as Draft, Preview, Continue to Image Studio ─
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    wizard.isDraftSaved
                        ? Icons.check_circle_rounded
                        : Icons.save_as_rounded,
                    color: wizard.isDraftSaved
                        ? Colors.green
                        : AppTheme.terracotta,
                  ),
                  label: Text(
                    wizard.isDraftSaved
                        ? (auth.selectedLanguage == 'mr'
                            ? 'मसुदा जतन केला'
                            : 'ड्राफ्ट सहेजा')
                        : (auth.selectedLanguage == 'mr'
                            ? 'मसुदा जतन करा'
                            : 'ड्राफ्ट सहेजें'),
                    style: TextStyle(
                      color: wizard.isDraftSaved
                          ? Colors.green
                          : AppTheme.terracotta,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    final saved =
                        await wizard.saveAsDraft(auth.authToken ?? '');
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          !saved
                              ? 'Confirm the English description before saving this draft.'
                              : auth.selectedLanguage == 'mr'
                                  ? "उत्पादनाचा मसुदा यशस्वीपणे जतन केला!"
                                  : "उत्पाद ड्राफ्ट सफलतापूर्वक सहेजा गया!",
                        ),
                        backgroundColor:
                            saved ? AppTheme.terracotta : Colors.red.shade700,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.remove_red_eye_rounded,
                      color: AppTheme.indigo),
                  label: Text(
                    auth.selectedLanguage == 'mr'
                        ? "पूर्वावलोकन"
                        : "पूर्वावलोकन",
                    style: const TextStyle(
                        color: AppTheme.indigo, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showPreviewDialog(context, wizard, auth),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Continue to image studio
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward_rounded, size: 24),
            label: Text(
                "${l10n.translate('continueBtn')} (${l10n.translate('stepStudio')})"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.terracotta,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              wizard.processPhotoInAIStudio(token: auth.authToken ?? '');
              wizard.nextStep();
            },
          ),
        ] else ...[
          // Manual entry is available when device speech recognition is absent.
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Enter description by typing'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            onPressed: () => _showManualTranscriptDialog(context, wizard, auth),
          ),
        ],
      ],
    );
  }

  void _showManualTranscriptDialog(
      BuildContext context, ProductWizardProvider wizard, AuthProvider auth) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter product description'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
              border: OutlineInputBorder(), hintText: 'Describe your product'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              wizard.setVoiceLanguage(auth.selectedLanguage);
              wizard.updateVoiceTranscript(text);
              Navigator.pop(ctx);
              await wizard.processVoiceNote(auth.selectedLanguage,
                  token: auth.authToken ?? '');
            },
            child: const Text('Translate'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
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
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }

  void _showEditTranscriptDialog(
      BuildContext context, ProductWizardProvider wizard, AuthProvider auth) {
    final controller = TextEditingController(text: wizard.voiceTranscript);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(auth.selectedLanguage == 'mr'
            ? "मजकूर दुरुस्त करा"
            : "विवरण सुधारें"),
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
            child: const Text("रद्द करा"),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
            onPressed: () async {
              Navigator.pop(ctx);
              wizard.updateVoiceTranscript(controller.text);
              await wizard.processVoiceNote(auth.selectedLanguage,
                  token: auth.authToken ?? '');
            },
            child: const Text("जतन करा व पुन्हा तपासा"),
          ),
        ],
      ),
    );
  }

  void _showAddMissingInfoDialog(
      BuildContext context, ProductWizardProvider wizard, AuthProvider auth) {
    final matCtrl = TextEditingController(text: wizard.material);
    final techCtrl = TextEditingController(text: wizard.technique);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(auth.selectedLanguage == 'mr'
            ? "साहित्य व पद्धत जोडा"
            : "सामग्री और तकनीक जोड़ें"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: matCtrl,
              decoration: InputDecoration(
                labelText: auth.selectedLanguage == 'mr'
                    ? "वापरलेले साहित्य"
                    : "सामग्री",
                hintText: "उदा. नैसर्गिक माती, तांदळाचे पीठ, लाकूड",
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: techCtrl,
              decoration: InputDecoration(
                labelText:
                    auth.selectedLanguage == 'mr' ? "कला पद्धत" : "तकनीक",
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
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
            onPressed: () async {
              Navigator.pop(ctx);
              final clarification =
                  "साहित्य: ${matCtrl.text.trim()}, पद्धत: ${techCtrl.text.trim()}";
              await wizard.processVoiceNote(auth.selectedLanguage,
                  token: auth.authToken ?? '', clarification: clarification);
            },
            child: const Text("पूर्ण करा"),
          ),
        ],
      ),
    );
  }

  void _showEditListingDialog(
      BuildContext context, ProductWizardProvider wizard) {
    final titleCtrl = TextEditingController(
        text: wizard.titleHi.isNotEmpty ? wizard.titleHi : wizard.titleEn);
    final shortDescCtrl = TextEditingController(
        text: wizard.shortDescriptionHi.isNotEmpty
            ? wizard.shortDescriptionHi
            : wizard.shortDescriptionEn);
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
                decoration: const InputDecoration(
                    labelText: "शीर्षक", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: shortDescCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: "संक्षिप्त वर्णन", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: matCtrl,
                decoration: const InputDecoration(
                    labelText: "साहित्य", border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("रद्द करा")),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
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

  void _showPreviewDialog(
      BuildContext context, ProductWizardProvider wizard, AuthProvider auth) {
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
                      "उत्पादन पूर्वावलोकन",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.terracotta),
                    ),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx)),
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
                    child: Icon(Icons.palette_rounded,
                        size: 70, color: AppTheme.terracotta),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  wizard.titleHi.isNotEmpty ? wizard.titleHi : wizard.titleEn,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(wizard.titleEn,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                Text(
                  wizard.descriptionHi.isNotEmpty
                      ? wizard.descriptionHi
                      : wizard.descriptionEn,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textCharcoal, height: 1.3),
                ),
                const SizedBox(height: 12),
                Text(
                    "साहित्य: ${wizard.material.isNotEmpty ? wizard.material : 'उपलब्ध नाही'}",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                    "पद्धत: ${wizard.technique.isNotEmpty ? wizard.technique : 'उपलब्ध नाही'}",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.terracotta),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("ठीक आहे"),
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
  Widget _buildPricingStep(
      ProductWizardProvider wizard, AppLocalizations l10n, AuthProvider auth) {
    final isMr = auth.selectedLanguage == 'mr';
    final isHi = auth.selectedLanguage == 'hi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wizard.isPricingLoading) ...[
          const LinearProgressIndicator(color: AppTheme.terracotta),
          const SizedBox(height: 12),
        ],
        if (wizard.pricingError != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade700),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wizard.pricingError!,
                    style: TextStyle(color: Colors.brown.shade900)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: wizard.isPricingLoading
                      ? null
                      : () => wizard.loadPricingRecommendation(
                          token: auth.authToken ?? ''),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh storefront comparisons'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        // ── 1. Verification Status & Estimate Disclosure Banner ───────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: wizard.isVerifiedMarketPrice
                ? Colors.green.shade50
                : Colors.amber.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: wizard.isVerifiedMarketPrice
                  ? Colors.green.shade600
                  : Colors.amber.shade700,
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                wizard.isVerifiedMarketPrice
                    ? Icons.verified_rounded
                    : Icons.info_outline_rounded,
                color: wizard.isVerifiedMarketPrice
                    ? Colors.green.shade700
                    : Colors.amber.shade900,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wizard.isVerifiedMarketPrice
                          ? (isMr
                              ? "स्टोअरवरील प्रकाशित उत्पादनांची तुलना"
                              : (isHi
                                  ? "स्टोर पर प्रकाशित उत्पादों की तुलना"
                                  : "Published storefront comparisons"))
                          : (isMr
                              ? "पुरेशी तुलनात्मक माहिती नाही"
                              : (isHi
                                  ? "पर्याप्त तुलनात्मक जानकारी नहीं"
                                  : "Insufficient comparable evidence")),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: wizard.isVerifiedMarketPrice
                            ? Colors.green.shade900
                            : Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      wizard.isVerifiedMarketPrice
                          ? "${wizard.comparableProducts.length} current published KarigarAI listings were compared. This suggestion is advisory; you choose the final price."
                          : "No matching published listings were found. There is no market-based suggestion; you can still enter your own price.",
                      style: TextStyle(
                        fontSize: 12,
                        color: wizard.isVerifiedMarketPrice
                            ? Colors.green.shade900
                            : Colors.amber.shade900,
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
                icon: const Icon(Icons.volume_up_rounded,
                    color: AppTheme.turmericDark, size: 28),
                onPressed: () {
                  VoiceGuidanceService.speakPrompt(
                    context,
                    wizard.priceExplanation.isNotEmpty
                        ? wizard.priceExplanation
                        : 'No price recommendation has been loaded yet.',
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  wizard.priceExplanation.isNotEmpty
                      ? wizard.priceExplanation
                      : 'No price recommendation has been loaded yet.',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textCharcoal,
                      height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (wizard.previousPricingRecommendation != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.indigoLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.indigo.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recommendation recheck',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          'Before: ${wizard.previousPricingRecommendation!['suggested_price'] == null ? 'No suggestion' : '${wizard.currency} ${(wizard.previousPricingRecommendation!['suggested_price'] as num).toStringAsFixed(2)}'}'),
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'Now: ${wizard.hasSuggestedPrice ? '${wizard.currency} ${wizard.suggestedPrice.toStringAsFixed(2)}' : 'No suggestion'}'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(wizard.previousPricingRecommendation!['suggested_price'] ==
                        wizard.suggestedPrice
                    ? 'The refreshed storefront evidence produced the same recommendation.'
                    : wizard.priceExplanation),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── 3. Itemized Cost Breakdown Card ──────────────────────────────────
        if (wizard.hasArtisanCostInputs)
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
                        const Icon(Icons.receipt_long_rounded,
                            color: AppTheme.terracotta, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isMr
                              ? "खर्चाचा पारदर्शक तपशील"
                              : (isHi
                                  ? "पारदर्शी लागत विवरण"
                                  : "Cost Breakdown"),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppTheme.terracotta),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.tune_rounded,
                          size: 16, color: AppTheme.terracotta),
                      label: Text(
                        isMr
                            ? "खर्च बदला"
                            : (isHi ? "संपादित करें" : "Edit Costs"),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.terracotta),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.terracotta),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () =>
                          _showEditCostsDialog(context, wizard, auth),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                _buildCostRow(isMr ? "कच्चा माल" : "कच्चा माल",
                    "₹ ${wizard.materialCost.toStringAsFixed(0)}"),
                _buildCostRow(
                  isMr
                      ? "कारागीर श्रम (${wizard.laborHours} तास @ ₹${wizard.hourlyRate.toStringAsFixed(0)}/तास)"
                      : "श्रम (${wizard.laborHours} घंटे @ ₹${wizard.hourlyRate.toStringAsFixed(0)}/घं)",
                  "₹ ${(wizard.laborHours * wizard.hourlyRate).toStringAsFixed(0)}",
                ),
                _buildCostRow(isMr ? "पॅकेजिंग साहित्य" : "पैकेजिंग सामग्री",
                    "₹ ${wizard.packagingCost.toStringAsFixed(0)}"),
                _buildCostRow(isMr ? "वाहतूक / कुरिअर" : "परिवहन / डिलीवरी",
                    "₹ ${wizard.shippingCost.toStringAsFixed(0)}"),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderWarm),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    color: AppTheme.terracotta),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text(
                        'No costs have been supplied. Pricing uses storefront listings only.')),
                OutlinedButton(
                  onPressed: () => _showEditCostsDialog(context, wizard, auth),
                  child: const Text('Add costs'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // ── 4. Three Distinct Understandable Price Tiers ──────────────────────
        Text(
          isMr ? "किंमत निवडा:" : "मूल्य विकल्प चुनें:",
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppTheme.textCharcoal),
        ),
        const SizedBox(height: 10),

        if (wizard.hasSuggestedPrice)
          _buildPriceCard(
            title: l10n.translate('suggestedPrice'),
            subtitle:
                'Observed range: ${wizard.currency} ${wizard.priceRangeMin?.toStringAsFixed(2) ?? '—'} – ${wizard.priceRangeMax?.toStringAsFixed(2) ?? '—'}',
            price: wizard.suggestedPrice,
            isSelected: wizard.acceptedPrice == wizard.suggestedPrice,
            badge: 'Storefront median · ${wizard.pricingConfidence} confidence',
            badgeColor: AppTheme.terracotta,
            onTap: () => wizard.selectPrice(wizard.suggestedPrice),
          )
        else
          const Text(
              'No suggested price is available from the current storefront evidence. Enter your own price below.',
              style: TextStyle(color: AppTheme.textMuted)),
        const SizedBox(height: 18),

        // ── 5. Artisan Custom Price Override & Warning ────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: wizard.priceOverrideWarning != null
                  ? Colors.red.shade400
                  : AppTheme.borderWarm,
              width: wizard.priceOverrideWarning != null ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMr
                    ? "स्वतःची पसंतीची किंमत टाका"
                    : (isHi
                        ? "अपनी मनपसंद कीमत तय करें"
                        : "Custom Price Override"),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.textCharcoal),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText:
                            "उदा. ${wizard.acceptedPrice.toStringAsFixed(0)}",
                        prefixText: "₹ ",
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.terracotta,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onPressed: () async {
                      final val = double.tryParse(_customPriceCtrl.text.trim());
                      if (val == null || !val.isFinite || val <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Enter a valid positive price.')),
                        );
                        return;
                      }
                      await wizard.applyCustomPriceOverride(
                          val, auth.authToken ?? '');
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
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          wizard.priceOverrideWarning!,
                          style: TextStyle(
                              color: Colors.red.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
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
            isMr ? "सत्यापित बाजार संदर्भ:" : "तुलनात्मक बाज़ार संदर्भ:",
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppTheme.textCharcoal),
          ),
          const SizedBox(height: 8),
          ...wizard.comparableProducts.map((comp) {
            final pTitle = comp['title'] as String? ?? 'Storefront product';
            final pPrice = (comp['price'] as num?)?.toDouble() ?? 0.0;
            final pSource = 'KarigarAI storefront';
            final pDate = comp['category'] as String? ?? '';
            final pScore =
                (comp['similarity_score'] as num?)?.toDouble() ?? 0.0;
            final pUrl = comp['product_url'] as String? ?? '';

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
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "₹ ${pPrice.toStringAsFixed(0)}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.indigo),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Text(
                          pSource,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pDate,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade700),
                      ),
                      const Spacer(),
                      Text(
                        "${(pScore * 100).toStringAsFixed(0)}% ${isMr ? 'जुळणी' : 'समानता'}",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800),
                      ),
                    ],
                  ),
                  if (pUrl.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      pUrl,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade700,
                          decoration: TextDecoration.underline),
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
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.textCharcoal),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: wizard.influencingFactors.map((factor) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundSand,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderWarm),
                ),
                child: Text(
                  factor,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textCharcoal,
                      fontWeight: FontWeight.w500),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
        ],

        OutlinedButton.icon(
          icon: const Icon(Icons.rate_review_outlined),
          label: const Text('Challenge recommendation and recheck listings'),
          onPressed: wizard.pricingRevisionId == null || wizard.isPricingLoading
              ? null
              : () => _showPricingChallengeDialog(context, wizard, auth),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (wizard.hasSuggestedPrice)
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded),
                  label: Text(wizard.previousPricingRecommendation == null
                      ? 'Accept Suggested Price'
                      : 'Accept Revised Price'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.terracotta),
                  onPressed: wizard.isPricingLoading
                      ? null
                      : () async {
                          final saved = await wizard.savePriceSelection(
                            token: auth.authToken ?? '',
                            price: wizard.suggestedPrice,
                            source: wizard.previousPricingRecommendation == null
                                ? 'suggested'
                                : 'revised_suggestion',
                          );
                          if (saved) wizard.nextStep();
                        },
                ),
              ),
            if (wizard.customPriceOverride != null) ...[
              if (wizard.hasSuggestedPrice) const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(
                      'Set My Own Price (${wizard.currency} ${wizard.customPriceOverride!.toStringAsFixed(2)})'),
                  onPressed: wizard.isPricingLoading
                      ? null
                      : () async {
                          final saved = await wizard.savePriceSelection(
                            token: auth.authToken ?? '',
                            price: wizard.customPriceOverride!,
                            source: 'custom',
                          );
                          if (saved) wizard.nextStep();
                        },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _showPricingChallengeDialog(
      BuildContext context, ProductWizardProvider wizard, AuthProvider auth) {
    final contextController = TextEditingController();
    var reason = 'material_cost';
    const reasons = <String, String>{
      'material_cost': 'My material cost is higher',
      'labor': 'The craftsmanship requires more labor',
      'size_or_detail': 'My product is larger or more detailed',
      'market_difference': 'Similar products are priced differently',
      'other': 'Other reason',
    };
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Challenge price recommendation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: reason,
                items: reasons.entries
                    .map((entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => reason = value);
                },
                decoration: const InputDecoration(
                    labelText: 'Why do you disagree?',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contextController,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Additional details (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final detail = contextController.text.trim();
                Navigator.pop(dialogContext);
                await wizard.challengePricing(
                  token: auth.authToken ?? '',
                  reason: reason,
                  context: detail.isEmpty ? null : detail,
                );
              },
              child: const Text('Recheck current listings'),
            ),
          ],
        ),
      ),
    ).whenComplete(contextController.dispose);
  }

  Widget _buildCostRow(String title, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textCharcoal)),
          ),
          Text(amount,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textCharcoal)),
        ],
      ),
    );
  }

  void _showEditCostsDialog(
      BuildContext context, ProductWizardProvider wizard, AuthProvider auth) {
    final matCtrl = TextEditingController(
        text: wizard.hasArtisanCostInputs
            ? wizard.materialCost.toStringAsFixed(2)
            : '');
    final hoursCtrl = TextEditingController(
        text: wizard.hasArtisanCostInputs ? wizard.laborHours.toString() : '');
    final rateCtrl = TextEditingController(
        text: wizard.hasArtisanCostInputs
            ? wizard.hourlyRate.toStringAsFixed(2)
            : '');
    final packCtrl = TextEditingController(
        text: wizard.hasArtisanCostInputs
            ? wizard.packagingCost.toStringAsFixed(2)
            : '');
    final shipCtrl = TextEditingController(
        text: wizard.hasArtisanCostInputs
            ? wizard.shippingCost.toStringAsFixed(2)
            : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          auth.selectedLanguage == 'mr'
              ? "खर्चाचा तपशील बदला"
              : "लागत विवरण संपादित करें",
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: AppTheme.terracotta),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: matCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: auth.selectedLanguage == 'mr'
                      ? "कच्चा माल खर्च (₹)"
                      : "सामग्री लागत (₹)",
                  border: const OutlineInputBorder(),
                  prefixText: "₹ ",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hoursCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: auth.selectedLanguage == 'mr'
                      ? "कामाचे तास"
                      : "श्रम के घंटे",
                  border: const OutlineInputBorder(),
                  suffixText: "तास",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: auth.selectedLanguage == 'mr'
                      ? "दर तास मजुरी (Hourly Wage Rate ₹)"
                      : "प्रति घंटा दर (₹)",
                  border: const OutlineInputBorder(),
                  prefixText: "₹ ",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: packCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: auth.selectedLanguage == 'mr'
                      ? "पॅकेजिंग खर्च (₹)"
                      : "पैकेजिंग लागत (₹)",
                  border: const OutlineInputBorder(),
                  prefixText: "₹ ",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: shipCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: auth.selectedLanguage == 'mr'
                      ? "वाहतूक / डिलिव्हरी (₹)"
                      : "शिपिंग / परिवहन (₹)",
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
            child:
                Text(auth.selectedLanguage == 'mr' ? "रद्द करा" : "रद्द करें"),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.terracotta),
            onPressed: () async {
              final mCost = double.tryParse(matCtrl.text.trim()) ?? 0;
              final lHrs = double.tryParse(hoursCtrl.text.trim()) ?? 0;
              final hRate = double.tryParse(rateCtrl.text.trim()) ?? 0;
              final pCost = double.tryParse(packCtrl.text.trim()) ?? 0;
              final sCost = double.tryParse(shipCtrl.text.trim()) ?? 0;
              final values = [mCost, lHrs, hRate, pCost, sCost];
              if (values.any((value) => !value.isFinite || value < 0)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Costs must be valid non-negative amounts.')),
                );
                return;
              }
              final reason = mCost != wizard.materialCost
                  ? 'material_cost'
                  : (lHrs != wizard.laborHours || hRate != wizard.hourlyRate)
                      ? 'labor'
                      : 'other';
              wizard.setArtisanCosts(
                materialCost: mCost,
                laborHours: lHrs,
                hourlyRate: hRate,
                packagingCost: pCost,
                shippingCost: sCost,
              );
              Navigator.pop(ctx);
              await wizard.challengePricing(
                token: auth.authToken ?? '',
                reason: reason,
                context: 'Artisan updated cost information for this product.',
              );
            },
            child: Text(auth.selectedLanguage == 'mr'
                ? "पुन्हा मोजा"
                : "पुनर्गणना करें"),
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
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                              color: badgeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted)),
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
  Widget _buildPublishStep(
      ProductWizardProvider wizard, AppLocalizations l10n, AuthProvider auth) {
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
            child:
                const Icon(Icons.check_rounded, color: Colors.white, size: 54),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.translate('publishedSuccess'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textCharcoal),
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
                "उत्पादन क्रमांक: #${wizard.publishedProductId} (वेबसाइटवर थेट)",
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.indigo,
                    fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            "कलासाथी ई-कॉमर्स वेबसाइटवर उत्पादन क्षणात उपलब्ध झाले आहे! खरेदीदार आता हे उत्पादन पाहू व खरेदी करू शकतात.",
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.4),
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
            child: const Text("डॅशबोर्डवर परत जा"),
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
                const Icon(Icons.bookmark_added_rounded,
                    color: AppTheme.indigo, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isMr
                        ? "मसुदा सुरक्षित जतन केला आहे${wizard.draftProductId != null ? ' (#${wizard.draftProductId})' : ''}. आता अंतिम प्रसिद्धी करा."
                        : "ड्राफ़्ट सुरक्षित है। लाइव प्रकाशित करने के लिए नीचे टैप करें।",
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.indigo),
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
                                  base64Decode(
                                      primaryImgBase64.split(',').last),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.image,
                                      color: Colors.grey),
                                )
                              : Image.network(
                                  primaryImgBase64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.image,
                                      color: Colors.grey),
                                ))
                          : (wizard.photos.isNotEmpty
                              ? Image.memory(wizard.photos[0],
                                  fit: BoxFit.cover)
                              : const Icon(Icons.palette_rounded,
                                  size: 40, color: AppTheme.terracotta)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wizard.titleHi.isNotEmpty
                              ? wizard.titleHi
                              : wizard.titleEn,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (wizard.titleEn.isNotEmpty &&
                            wizard.titleHi.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            wizard.titleEn,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          "किंमत: ₹ ${wizard.acceptedPrice.toStringAsFixed(0)}",
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.terracotta),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // 3 Selected Variation Thumbnails row
              if (wizard.selectedVariations.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  isMr
                      ? "निवडलेले ३ व्यावसायिक फोटो (Live Photos):"
                      : "चयनित 3 व्यावसायिक फ़ोटो:",
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  children:
                      wizard.selectedVariations.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final v = entry.value;
                    return Expanded(
                      child: Container(
                        height: 72,
                        margin: EdgeInsets.only(right: idx < 2 ? 8 : 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: idx == 0
                                ? AppTheme.terracotta
                                : AppTheme.borderWarm,
                            width: idx == 0 ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildVariationThumbnail(v),
                              if (idx == 0)
                                Positioned(
                                  bottom: 2,
                                  left: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.terracotta,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      "मुख्य",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMr ? "साहित्य:" : "सामग्री:",
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textMuted),
                  ),
                  Text(
                    wizard.material.isNotEmpty
                        ? wizard.material
                        : "अस्सल पारंपारिक",
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMr ? "कला पद्धत:" : "तकनीक:",
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textMuted),
                  ),
                  Text(
                    wizard.technique.isNotEmpty
                        ? wizard.technique
                        : "हस्तनिर्मित",
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMr ? "विक्रीसाठी उपलब्ध नग:" : "शिल्लक साठा:",
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textMuted),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            size: 20, color: AppTheme.textMuted),
                        visualDensity: VisualDensity.compact,
                        onPressed: wizard.inventoryStock > 1
                            ? () => wizard
                                .setInventoryStock(wizard.inventoryStock - 1)
                            : null,
                      ),
                      Text(
                        "${wizard.inventoryStock} नग",
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.indigo),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline,
                            size: 20, color: AppTheme.indigo),
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            wizard.setInventoryStock(wizard.inventoryStock + 1),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.successGreenLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.translate_rounded,
                        color: AppTheme.successGreen, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isMr
                            ? "१२ भारतीय भाषांमध्ये सूची तयार आहे."
                            : "12 भारतीय भाषाओं में अनुवाद तैयार है।",
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.successGreen,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Final review confirmations required before the publish action is enabled.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderWarm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Final product review',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('Product name: ${wizard.titleEn}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Category: ${wizard.categorySlug}'),
              if (wizard.material.trim().isNotEmpty)
                Text('Material: ${wizard.material}'),
              if (wizard.technique.trim().isNotEmpty)
                Text('Technique: ${wizard.technique}'),
              if (wizard.careInstructions.trim().isNotEmpty)
                Text('Care: ${wizard.careInstructions}'),
              if (wizard.seoKeywords.isNotEmpty)
                Text('Keywords: ${wizard.seoKeywords.join(', ')}'),
              if (wizard.voiceTranscript.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Original-language transcript',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(wizard.voiceTranscript,
                    style: const TextStyle(color: AppTheme.textMuted)),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundSand,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(wizard.descriptionEn),
              ),
              TextButton.icon(
                onPressed:
                    wizard.isPublishing ? null : () => wizard.goToStep(1),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit product details'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: wizard.finalDescriptionConfirmed,
                onChanged: wizard.isPublishing
                    ? null
                    : (value) => wizard.confirmFinalDescription(value ?? false),
                title: const Text(
                    'I reviewed and approve this English description.'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 18),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 76,
                      height: 76,
                      color: AppTheme.backgroundSand,
                      child: wizard.originalImageUrl == null
                          ? const Icon(Icons.image_not_supported_outlined)
                          : Image.network(
                              wizard.originalImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image_outlined,
                                  color: AppTheme.textMuted),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(wizard.originalImageUrl == null
                        ? 'Original uploaded photo is unavailable.'
                        : 'Original uploaded photo kept for reference.'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Selected product images',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: wizard.selectedVariations.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final variant = wizard.selectedVariations[index];
                    final imageUrl =
                        (variant['image_url'] ?? variant['url'] ?? '')
                            .toString();
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 92,
                        color: AppTheme.backgroundSand,
                        child: imageUrl.startsWith('http')
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image_outlined,
                                  color: AppTheme.textMuted,
                                ),
                                loadingBuilder: (context, child, progress) =>
                                    progress == null
                                        ? child
                                        : const Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                              )
                            : const Icon(Icons.image_not_supported_outlined),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed:
                    wizard.isPublishing ? null : () => wizard.goToStep(2),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Change the three selected images'),
              ),
              const Divider(height: 18),
              TextField(
                controller: _finalPriceCtrl,
                focusNode: _finalPriceFocus,
                enabled: !wizard.isPublishing,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  final price = double.tryParse(value.trim());
                  wizard.acceptedPrice =
                      price != null && price.isFinite && price > 0 ? price : 0;
                },
                decoration: InputDecoration(
                  labelText: 'Final selling price (${wizard.currency})',
                  prefixText: '₹ ',
                  border: const OutlineInputBorder(),
                  helperText: wizard.hasSuggestedPrice
                      ? 'AI suggestion: ${wizard.currency} ${wizard.suggestedPrice.toStringAsFixed(2)} (advisory)'
                      : 'Set the price you want buyers to pay.',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: wizard.finalPriceConfirmed,
                onChanged: wizard.isPublishing
                    ? null
                    : (value) => wizard.confirmFinalPrice(value ?? false),
                title: const Text('I confirm this final selling price.'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (wizard.selectedVariations.length != 3 ||
                  wizard.imageJobStatus != 'completed' ||
                  wizard.imageProcessingMode == 'mock')
                Text(
                  wizard.imageJobError ??
                      'Three successfully processed, approved images are required.',
                  style: TextStyle(color: Colors.red.shade700),
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
                const Icon(Icons.error_outline_rounded,
                    color: Colors.red, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMr ? "प्रकाशन अयशस्वी" : "प्रकाशन विफल",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        wizard.publishError!,
                        style:
                            TextStyle(color: Colors.red.shade900, fontSize: 12),
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
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : const Icon(Icons.rocket_launch_rounded, size: 26),
          label: Text(
            wizard.isPublishing
                ? (isMr ? "वेबसाइटवर पाठवत आहे..." : "प्रकाशित हो रहा है...")
                : (wizard.publishError != null
                    ? (isMr ? "पुन्हा प्रयत्न करा" : "पुनः प्रयास करें")
                    : l10n.translate('publishNow')),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successGreen,
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
          onPressed: wizard.isPublishing || !wizard.canPublishProduct
              ? null
              : () => _confirmAndPublish(wizard, auth),
        ),
        const SizedBox(height: 12),

        if (!wizard.isPublishing) ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.save_as_rounded,
                size: 20, color: AppTheme.indigo),
            label: Text(
                isMr ? "मसुदा म्हणून जतन करा" : "ड्राफ़्ट के रूप में सहेजें"),
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

  Future<void> _confirmAndPublish(
      ProductWizardProvider wizard, AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Publish this product?'),
        content: Text(
          '${wizard.titleEn}\n${wizard.categorySlug}\n'
          '${wizard.currency} ${wizard.acceptedPrice.toStringAsFixed(2)}\n'
          'Three approved product images',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Review again'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm and publish'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await wizard.publishProduct(auth.authToken ?? '');
    }
  }
}
