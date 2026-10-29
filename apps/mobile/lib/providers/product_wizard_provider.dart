import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:kalasathi_mobile/services/api_service.dart';
import 'package:kalasathi_mobile/services/offline_storage_service.dart';

class ProductWizardProvider extends ChangeNotifier {
  static const int maxProductPhotoBytes = 10 * 1024 * 1024;
  static const Set<String> _translationLanguages = {
    'en',
    'hi',
    'mr',
    'gu',
    'ta',
    'te',
    'bn',
    'kn',
    'ml',
    'pa',
    'or',
    'as'
  };

  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechInitialized = false;
  bool _speechAvailable = false;
  bool _isStartingSpeech = false;
  final List<stt.LocaleName> _speechLocales = [];
  String? _speechError;
  String _voiceLanguage = 'en';
  bool _descriptionNeedsReview = false;
  bool _descriptionManuallyEdited = false;
  bool _englishDescriptionConfirmed = false;
  int _currentStep = 0;
  bool _isProcessingAI = false;
  String? _imageJobId;
  int _imageJobAttempt = 0;
  String? _imageJobStatus;
  String? _imageJobError;
  String? _imageProcessingMode;

  // Step 1: Photos
  final List<Uint8List> _photos = [];
  bool _isUploadingPhoto = false;
  String? _photoUploadError;
  bool _photoUploadRequiresAuthentication = false;
  String? _photoUploadId;
  String? _attachedPhotoUploadId;
  String? _photoFileName;
  String? _photoContentType;
  String? _originalImageUrl;
  String _cameraGuidance = "Move closer to your craft";

  // Step 2: Studio Image Variations
  String? _enhancedImageBase64;
  List<Map<String, dynamic>> _imageVariations = [];
  Set<String> _selectedVariationIds = {};

  // Step 3: Voice & Catalog
  String _voiceTranscript = "";
  bool _isRecording = false;
  String _titleEn = "";
  String _titleHi = "";
  String _shortDescriptionEn = "";
  String _shortDescriptionHi = "";
  String _descriptionEn = "";
  String _descriptionHi = "";
  String _material = "";
  String _technique = "";
  String _categorySlug = "pottery";
  String _careInstructions = "";
  List<String> _seoKeywords = [];
  List<Map<String, dynamic>> _translations = [];
  List<String> _missingFields = [];
  String? _missingInfoPrompt;
  bool _isDraftSaved = false;

  // Step 4: Intelligent Pricing
  double _materialCost = 85.0;
  double _laborHours = 4.5;
  double _hourlyRate = 85.0;
  double _packagingCost = 30.0;
  double _shippingCost = 60.0;
  double _platformFeePercent = 8.0;

  double _costFloor = 480.0;
  double _suggestedPrice = 630.0;
  double _premiumPrice = 850.0;
  double _acceptedPrice = 630.0;
  double? _customPriceOverride;
  String? _priceOverrideWarning;

  bool _isVerifiedMarketPrice = false;
  String _pricingBasis = "cost_plus_estimate";
  String _statusLabel = "Unverified Cost-Based Estimate";
  Map<String, dynamic> _costBreakdown = {};
  List<Map<String, dynamic>> _comparableProducts = [];
  List<String> _influencingFactors = [];
  String _priceExplanation = "";

  // Step 5: Publish
  bool _isPublishing = false;
  bool _isPublished = false;
  int? _publishedProductId;
  int? _draftProductId;
  String? _publishError;
  int _inventoryStock = 5;

  // Getters
  int get currentStep => _currentStep;
  int? get draftProductId => _draftProductId;
  String? get publishError => _publishError;
  int get inventoryStock => _inventoryStock;
  bool get isProcessingAI => _isProcessingAI;
  String? get imageJobStatus => _imageJobStatus;
  String? get imageJobError => _imageJobError;
  String? get imageProcessingMode => _imageProcessingMode;
  List<Uint8List> get photos => _photos;
  String get cameraGuidance => _cameraGuidance;
  String? get enhancedImageBase64 => _enhancedImageBase64;
  List<Map<String, dynamic>> get imageVariations => _imageVariations;
  Set<String> get selectedVariationIds => _selectedVariationIds;
  List<Map<String, dynamic>> get selectedVariations => _imageVariations
      .where((v) => _selectedVariationIds.contains(v['id']))
      .toList();
  String get voiceTranscript => _voiceTranscript;
  bool get isRecording => _isRecording;
  bool get speechAvailable => _speechAvailable;
  String? get speechError => _speechError;
  String get voiceLanguage => _voiceLanguage;
  bool get descriptionNeedsReview => _descriptionNeedsReview;
  bool get englishDescriptionConfirmed => _englishDescriptionConfirmed;
  List<stt.LocaleName> get speechLocales => List.unmodifiable(_speechLocales);
  String get titleEn => _titleEn;
  String get titleHi => _titleHi;
  String get shortDescriptionEn => _shortDescriptionEn;
  String get shortDescriptionHi => _shortDescriptionHi;
  String get descriptionEn => _descriptionEn;
  String get descriptionHi => _descriptionHi;
  String get material => _material;
  String get technique => _technique;
  String get categorySlug => _categorySlug;
  String get careInstructions => _careInstructions;
  List<String> get seoKeywords => _seoKeywords;
  List<Map<String, dynamic>> get translations => _translations;
  List<String> get missingFields => _missingFields;
  String? get missingInfoPrompt => _missingInfoPrompt;
  bool get isDraftSaved => _isDraftSaved;
  bool get isUploadingPhoto => _isUploadingPhoto;
  String? get photoUploadError => _photoUploadError;
  bool get photoUploadRequiresAuthentication =>
      _photoUploadRequiresAuthentication;
  bool get canRetryPhotoUpload =>
      _photoUploadId != null && _photoContentType != null;
  bool get isCurrentPhotoUploaded =>
      _photoUploadId != null &&
      _photoUploadId == _attachedPhotoUploadId &&
      _originalImageUrl != null;
  String? get originalImageUrl => _originalImageUrl;

  // Pricing Getters
  double get materialCost => _materialCost;
  double get laborHours => _laborHours;
  double get hourlyRate => _hourlyRate;
  double get packagingCost => _packagingCost;
  double get shippingCost => _shippingCost;
  double get platformFeePercent => _platformFeePercent;
  double get costFloor => _costFloor;
  double get suggestedPrice => _suggestedPrice;
  double get premiumPrice => _premiumPrice;
  double get acceptedPrice => _acceptedPrice;
  double? get customPriceOverride => _customPriceOverride;
  String? get priceOverrideWarning => _priceOverrideWarning;
  bool get isVerifiedMarketPrice => _isVerifiedMarketPrice;
  String get pricingBasis => _pricingBasis;
  String get statusLabel => _statusLabel;
  Map<String, dynamic> get costBreakdown => _costBreakdown;
  List<Map<String, dynamic>> get comparableProducts => _comparableProducts;
  List<String> get influencingFactors => _influencingFactors;
  String get priceExplanation => _priceExplanation;

  // Publish Getters
  bool get isPublishing => _isPublishing;
  bool get isPublished => _isPublished;
  int? get publishedProductId => _publishedProductId;

  set titleEn(String val) {
    _titleEn = val;
    notifyListeners();
  }

  set titleHi(String val) {
    _titleHi = val;
    notifyListeners();
  }

  set acceptedPrice(double val) {
    _acceptedPrice = val;
    notifyListeners();
  }

  set draftProductId(int? val) {
    _draftProductId = val;
    notifyListeners();
  }

  void nextStep() {
    if (_currentStep < 4) {
      _currentStep++;
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  bool get hasSelectedExact3 => _selectedVariationIds.length == 3;
  bool get canProceedFromStudio => _selectedVariationIds.length == 3;

  void addPhoto(Uint8List bytes) {
    if (_photos.length < 4) {
      _photos.add(bytes);
      notifyListeners();
    }
  }

  void removePhoto(int index) {
    if (index >= 0 && index < _photos.length) {
      _photos.removeAt(index);
      notifyListeners();
    }
  }

  String? _lastCameraError;
  String? get lastCameraError => _lastCameraError;

  void _resetVariations() {
    _imageVariations.clear();
    _selectedVariationIds.clear();
    _enhancedImageBase64 = null;
    _imageJobId = null;
    _imageJobStatus = null;
    _imageJobError = null;
    _imageProcessingMode = null;
  }

  Future<bool> clearPhotos({required String? token}) async {
    if (_isUploadingPhoto) return false;
    final uploadIds = {
      if (_photoUploadId != null) _photoUploadId!,
      if (_attachedPhotoUploadId != null) _attachedPhotoUploadId!,
    };
    if (uploadIds.isNotEmpty) {
      if (token == null || token.isEmpty) {
        _photoUploadError = 'Sign in to remove this uploaded photo.';
        notifyListeners();
        return false;
      }
      _isUploadingPhoto = true;
      _photoUploadError = null;
      _photoUploadRequiresAuthentication = false;
      notifyListeners();
      try {
        for (final uploadId in uploadIds) {
          await ApiService.removeDraftProductImage(
              token: token, uploadId: uploadId);
        }
      } catch (error) {
        _photoUploadError = error.toString().replaceFirst('Exception: ', '');
        _isUploadingPhoto = false;
        notifyListeners();
        return false;
      }
      _isUploadingPhoto = false;
    }
    _photos.clear();
    _resetVariations();
    _lastCameraError = null;
    _photoUploadError = null;
    _photoUploadId = null;
    _attachedPhotoUploadId = null;
    _photoFileName = null;
    _photoContentType = null;
    _originalImageUrl = null;
    notifyListeners();
    return true;
  }

  Future<bool> pickImageFromCamera({required String? token}) async {
    if (_isUploadingPhoto) return false;
    _lastCameraError = null;
    _photoUploadError = null;
    _isUploadingPhoto = true;
    notifyListeners();
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (image != null) {
        return await _acceptPickedImage(image, token);
      }
    } catch (e) {
      debugPrint('Error picking camera image: $e');
      _lastCameraError = _permissionError(e, camera: true);
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> pickImageFromGallery({required String? token}) async {
    if (_isUploadingPhoto) return false;
    _lastCameraError = null;
    _photoUploadError = null;
    _isUploadingPhoto = true;
    notifyListeners();
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (image != null) {
        return await _acceptPickedImage(image, token);
      }
    } catch (e) {
      debugPrint('Error picking gallery image: $e');
      _lastCameraError = _permissionError(e, camera: false);
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> _acceptPickedImage(XFile image, String? token) async {
    final bytes = await image.readAsBytes();
    final imageType = detectProductImageType(bytes);
    if (imageType == null) {
      _photoUploadError =
          'Unsupported image. Choose a valid JPEG, PNG, or WebP photo.';
      return false;
    }
    if (bytes.length > maxProductPhotoBytes) {
      _photoUploadError =
          'Image is too large. Choose a photo smaller than 10 MB.';
      return false;
    }

    _photos
      ..clear()
      ..add(bytes);
    _resetVariations();
    _photoFileName = 'product_photo.${imageType.$1}';
    _photoContentType = imageType.$2;
    _photoUploadId = _newPhotoUploadId();
    _photoUploadError = null;
    _photoUploadRequiresAuthentication = false;
    _lastCameraError = null;
    notifyListeners();

    if (token == null || token.isEmpty) {
      _photoUploadError =
          'Sign in to upload and save this photo to your product draft.';
      return true;
    }
    await _uploadCurrentPhoto(token);
    return true;
  }

  static (String, String)? detectProductImageType(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return ('jpg', 'image/jpeg');
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return ('png', 'image/png');
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return ('webp', 'image/webp');
    }
    return null;
  }

  String _newPhotoUploadId() {
    final randomPart =
        Random.secure().nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'photo_${DateTime.now().microsecondsSinceEpoch}_$randomPart';
  }

  String _permissionError(Object error, {required bool camera}) {
    final value = error.toString().toLowerCase();
    if (value.contains('denied') || value.contains('permission')) {
      return camera
          ? 'Camera permission was denied. Allow camera access in your device settings or choose a photo from your gallery.'
          : 'Photo access was denied. Allow photo access in your device settings.';
    }
    return camera
        ? 'Could not open the camera. Please try again or choose a gallery photo.'
        : 'Could not open the photo gallery. Please try again.';
  }

  Future<void> retryPhotoUpload(String? token) async {
    if (_isUploadingPhoto || _photos.isEmpty || _photoUploadId == null) return;
    if (token == null || token.isEmpty) {
      _photoUploadError =
          'Sign in to upload and save this photo to your product draft.';
      notifyListeners();
      return;
    }
    _isUploadingPhoto = true;
    notifyListeners();
    try {
      await _uploadCurrentPhoto(token);
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }
  }

  Future<void> _uploadCurrentPhoto(String token) async {
    try {
      final result = await ApiService.uploadDraftProductImage(
        token: token,
        imageBytes: _photos.first,
        filename: _photoFileName!,
        contentType: _photoContentType!,
        uploadId: _photoUploadId!,
        productId: _draftProductId?.toString(),
        categorySlug: _categorySlug,
      );
      _draftProductId = result['product_id'] as int? ?? _draftProductId;
      _originalImageUrl = result['image_url'] as String?;
      _attachedPhotoUploadId = _photoUploadId;
      _photoUploadError = null;
    } catch (error) {
      _photoUploadRequiresAuthentication = error is ApiAuthenticationException;
      _photoUploadError = error.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> loadSamplePhoto(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      _photos.clear();
      _photos.add(bytes);
      _resetVariations();
      _photoUploadId = null;
      _attachedPhotoUploadId = null;
      _photoFileName = null;
      _photoContentType = null;
      _originalImageUrl = null;
      _photoUploadError =
          'Sample photos are for preview only and are not uploaded to a product draft.';
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading sample asset: $e');
    }
  }

  // ─── AI Studio Step ────────────────────────────────────────────────────────
  Future<void> processPhotoInAIStudio(
      {required String token, bool forceRegenerate = false}) async {
    if (_photos.isEmpty) return;
    if (_isProcessingAI) return;
    if (_imageVariations.isNotEmpty && !forceRegenerate) return;
    if (forceRegenerate) {
      _imageVariations.clear();
      _selectedVariationIds.clear();
      _imageJobId = null;
      _imageJobAttempt++;
    }

    _isProcessingAI = true;
    _imageJobStatus = 'uploading';
    _imageJobError = null;
    _imageProcessingMode = null;
    notifyListeners();

    try {
      var current = <String, dynamic>{};
      if (_imageJobId != null) {
        current =
            await ApiService.getImageJob(token: token, jobId: _imageJobId!);
      } else {
        current = await ApiService.startImageJob(
          token: token,
          imageBytes: _photos[0],
          uploadId: _photoUploadId == null
              ? null
              : '${_photoUploadId}_${_imageJobAttempt}',
          productName: _titleEn.isNotEmpty ? _titleEn : 'Handcrafted product',
          productCategory: _categorySlug,
        );
        _imageJobId = current['job_id'] as String?;
      }
      for (var attempt = 0; attempt < 120; attempt++) {
        final status = current['status'] as String? ?? 'failed';
        _imageJobStatus = status;
        if (status == 'completed' ||
            status == 'awaiting_review' ||
            status == 'failed' ||
            status == 'retake_required') break;
        await Future<void>.delayed(const Duration(seconds: 3));
        current =
            await ApiService.getImageJob(token: token, jobId: _imageJobId!);
        notifyListeners();
      }
      _imageJobStatus = current['status'] as String?;
      _imageProcessingMode = current['processing_mode'] as String? ?? 'real';
      _imageJobError = current['error'] as String?;
      if (_imageJobStatus == 'completed' ||
          _imageJobStatus == 'awaiting_review') {
        _imageVariations = ((current['variants'] as List?) ?? [])
            .map((v) => Map<String, dynamic>.from(v as Map))
            .where((v) =>
                v['image_url'] is String &&
                (v['image_url'] as String).isNotEmpty)
            .toList();
      }
      if (_imageJobStatus == 'awaiting_review') {
        _imageJobError = _imageProcessingMode == 'mock'
            ? 'Mock mode is enabled; no image processing was performed. Configure CrewAI to process real photos.'
            : 'Processing needs human review. These images cannot be published yet.';
      } else if (_imageJobStatus == 'retake_required') {
        _imageJobError =
            'The product could not be separated confidently. Please take another photo.';
      } else if (_imageJobStatus == 'failed') {
        _imageJobError ??= 'Image processing failed. Please retry.';
      } else if (_imageJobStatus != 'completed') {
        _imageJobError = 'Image processing timed out. You can retry.';
      }
      if (_imageVariations.isNotEmpty) {
        // Select exactly top 3 variations by default to start with a valid state
        _selectedVariationIds =
            _imageVariations.take(3).map((v) => v['id'] as String).toSet();
        _enhancedImageBase64 = _imageVariations.first['image_url'] as String? ??
            _imageVariations.first['data_uri'] as String?;
      }
    } catch (e) {
      _imageJobError = e.toString();
      debugPrint('AI Studio error: $e');
    }

    _isProcessingAI = false;
    notifyListeners();
  }

  Future<void> retryImageJob(String token) async {
    if (_imageJobStatus == 'failed') {
      _imageJobId = null;
      _imageJobAttempt++;
    }
    if (_imageJobStatus == 'retake_required') return;
    await processPhotoInAIStudio(token: token);
  }

  Future<void> approveImageReview(String token) async {
    if (_imageJobId == null) return;
    try {
      final reviewed = await ApiService.reviewImageJob(
          token: token, jobId: _imageJobId!, approved: true);
      _imageJobStatus = reviewed['status'] as String?;
      _imageJobError = null;
      _imageVariations = ((reviewed['variants'] as List?) ?? [])
          .map((v) => Map<String, dynamic>.from(v as Map))
          .where((v) =>
              v['image_url'] is String && (v['image_url'] as String).isNotEmpty)
          .toList();
      _selectedVariationIds = _imageVariations
          .take(3)
          .map((v) => (v['id'] ?? v['variant_id']).toString())
          .toSet();
    } catch (e) {
      _imageJobError = e.toString();
    }
    notifyListeners();
  }

  Future<bool> saveImageSelection(String token) async {
    if (_imageJobId == null || !hasSelectedExact3) return false;
    try {
      await ApiService.selectImageVariants(
        token: token,
        jobId: _imageJobId!,
        variantIds: selectedVariations
            .map((v) => (v['id'] ?? v['variant_id']).toString())
            .toList(),
      );
      return true;
    } catch (e) {
      _imageJobError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Toggles variation selection adhering to the strict rule:
  /// Exactly 3 must be selected; attempts to select a 4th return false.
  bool toggleVariationSelection(String variationId) {
    if (_selectedVariationIds.contains(variationId)) {
      _selectedVariationIds.remove(variationId);
      notifyListeners();
      return true;
    } else {
      if (_selectedVariationIds.length >= 3) {
        // Disallow selecting 4th image
        return false;
      }
      _selectedVariationIds.add(variationId);
      notifyListeners();
      return true;
    }
  }

  // ─── Voice Recording & Catalog Step ────────────────────────────────────────
  Future<void> loadSpeechLocales({String? preferredLanguage}) async {
    _speechError = null;
    try {
      if (!_speechInitialized) {
        _speechAvailable = await _speech.initialize(
          onStatus: (status) {
            _isRecording = status == 'listening';
            notifyListeners();
          },
          onError: (error) {
            _isRecording = false;
            _speechError = error.errorMsg;
            notifyListeners();
          },
        );
        _speechInitialized = true;
      }
      final installed =
          _speechAvailable ? await _speech.locales() : const <stt.LocaleName>[];
      final availableCodes = <String>{};
      _speechLocales
        ..clear()
        ..addAll(installed.where((locale) {
          final code =
              locale.localeId.toLowerCase().split(RegExp('[-_]')).first;
          return _translationLanguages.contains(code) &&
              availableCodes.add(code);
        }));
      if (preferredLanguage != null) {
        if (_translationLanguages.contains(preferredLanguage.toLowerCase())) {
          _voiceLanguage = preferredLanguage.toLowerCase();
        }
        final match = _speechLocales.where((locale) =>
            locale.localeId.toLowerCase().split(RegExp('[-_]')).first ==
            preferredLanguage.toLowerCase());
        if (match.isNotEmpty) _voiceLanguage = preferredLanguage;
      }
      if (_speechLocales.isNotEmpty &&
          !_speechLocales.any((locale) =>
              locale.localeId.toLowerCase().split(RegExp('[-_]')).first ==
              _voiceLanguage)) {
        _voiceLanguage = _speechLocales.first.localeId
            .toLowerCase()
            .split(RegExp('[-_]'))
            .first;
      }
      if (!_speechAvailable) {
        _speechError = 'Speech recognition is unavailable on this device.';
      } else if (_speechLocales.isEmpty) {
        _speechError = 'No speech languages are installed on this device.';
      }
    } catch (_) {
      _speechAvailable = false;
      _speechError = 'Microphone or speech recognition permission was denied.';
    }
    notifyListeners();
  }

  void setVoiceLanguage(String language) {
    _voiceLanguage = language;
    notifyListeners();
  }

  Future<void> startSpeechRecognition() async {
    if (_isStartingSpeech || _isRecording || _isProcessingAI) return;
    if (!_speechInitialized) await loadSpeechLocales();
    if (!_speechAvailable) return;
    final locale = _speechLocales.where((item) =>
        item.localeId.toLowerCase().split(RegExp('[-_]')).first ==
        _voiceLanguage);
    if (locale.isEmpty) {
      _speechError = 'That language is not available for speech recognition.';
      notifyListeners();
      return;
    }
    _speechError = null;
    _voiceTranscript = '';
    _isStartingSpeech = true;
    notifyListeners();
    try {
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: locale.first.localeId,
          partialResults: true,
        ),
        onResult: (SpeechRecognitionResult result) {
          _voiceTranscript = result.recognizedWords;
          notifyListeners();
        },
      );
      _isRecording = _speech.isListening;
    } catch (_) {
      _speechError =
          'Microphone permission was denied or speech recognition failed.';
      _isRecording = false;
    } finally {
      _isStartingSpeech = false;
      notifyListeners();
    }
  }

  Future<void> stopSpeechRecognition() async {
    await _speech.stop();
    _isRecording = false;
    notifyListeners();
  }

  Future<void> cancelSpeechRecognition() async {
    await _speech.cancel();
    _isRecording = false;
    notifyListeners();
  }

  void updateVoiceTranscript(String newTranscript) {
    _voiceTranscript = newTranscript;
    notifyListeners();
  }

  void updateField({
    String? titleEn,
    String? titleHi,
    String? shortDescriptionEn,
    String? shortDescriptionHi,
    String? descriptionEn,
    String? descriptionHi,
    String? material,
    String? technique,
    String? careInstructions,
  }) {
    if (titleEn != null) _titleEn = titleEn;
    if (titleHi != null) _titleHi = titleHi;
    if (shortDescriptionEn != null) _shortDescriptionEn = shortDescriptionEn;
    if (shortDescriptionHi != null) _shortDescriptionHi = shortDescriptionHi;
    if (descriptionEn != null) _descriptionEn = descriptionEn;
    if (descriptionHi != null) _descriptionHi = descriptionHi;
    if (material != null) _material = material;
    if (technique != null) _technique = technique;
    if (careInstructions != null) _careInstructions = careInstructions;
    notifyListeners();
  }

  Future<void> processVoiceNote(String language,
      {required String token, String? clarification}) async {
    if (_isProcessingAI) return;
    final transcript = _voiceTranscript.trim();
    if (transcript.isEmpty) {
      _speechError =
          'No speech was recognized. Please try again or edit the transcript.';
      notifyListeners();
      return;
    }
    _isProcessingAI = true;
    _speechError = null;
    notifyListeners();

    try {
      final translated = await ApiService.translateProductDescription(
        token: token,
        transcript: transcript,
        sourceLanguage: _voiceLanguage,
        productId: _draftProductId,
      );
      _descriptionEn = translated['english_description'] as String? ?? '';
      _descriptionNeedsReview = translated['requires_review'] == true;
      _descriptionManuallyEdited = false;
      _englishDescriptionConfirmed = false;
    } catch (error) {
      _speechError = error.toString().replaceFirst('Exception: ', '');
      _isProcessingAI = false;
      notifyListeners();
      return;
    }

    // Existing catalog enrichment can populate structured fields. Its fallback
    // text is never allowed to replace the faithfully translated description.
    final translatedDescription = _descriptionEn;
    final catalog = await ApiService.catalogProduct(
      transcript: transcript,
      language: _voiceLanguage,
      imageBase64: _enhancedImageBase64,
      clarification: clarification,
    );

    _titleEn = catalog['title_en'] ?? 'Handmade Craft';
    _titleHi = catalog['title_hi'] ?? 'हस्तशिल्प';
    _shortDescriptionEn = catalog['short_description_en'] ?? '';
    _shortDescriptionHi = catalog['short_description_hi'] ?? '';
    _descriptionEn = translatedDescription;
    _descriptionHi = catalog['description_hi'] ?? '';
    _material = catalog['material'] ?? '';
    _technique = catalog['technique'] ?? '';
    _categorySlug = catalog['category_slug'] ?? 'pottery';
    _careInstructions = catalog['care_instructions'] ?? 'Handle with care';
    _seoKeywords =
        (catalog['seo_keywords'] as List?)?.map((e) => e.toString()).toList() ??
            [];

    if (catalog['translations'] != null) {
      _translations = (catalog['translations'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    final englishTranslation =
        _translations.indexWhere((item) => item['language'] == 'en');
    final englishRow = <String, dynamic>{
      'language': 'en',
      'title': _titleEn,
      'description': translatedDescription,
    };
    if (englishTranslation >= 0) {
      _translations[englishTranslation] = {
        ..._translations[englishTranslation],
        ...englishRow,
      };
    } else {
      _translations.add(englishRow);
    }

    _missingFields = (catalog['missing_fields'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    _missingInfoPrompt = catalog['missing_info_prompt'] as String?;

    // Seed costs from catalog extraction
    _materialCost =
        (catalog['estimated_material_cost'] as num?)?.toDouble() ?? 85.0;
    _laborHours = (catalog['estimated_labor_hours'] as num?)?.toDouble() ?? 4.5;

    // 3. Compute fair pricing tiers with breakdown & comparables
    await recalculatePricing(language: language);

    _isProcessingAI = false;
    notifyListeners();
  }

  void updateEnglishDescription(String value) {
    _descriptionEn = value;
    _descriptionManuallyEdited = true;
    _descriptionNeedsReview = false;
    _englishDescriptionConfirmed = false;
    final english =
        _translations.indexWhere((item) => item['language'] == 'en');
    if (english >= 0) {
      _translations[english] = {
        ..._translations[english],
        'description': value,
      };
    }
    notifyListeners();
  }

  void confirmEnglishDescription(bool confirmed) {
    _englishDescriptionConfirmed =
        confirmed && _descriptionEn.trim().isNotEmpty;
    notifyListeners();
  }

  bool get descriptionManuallyEdited => _descriptionManuallyEdited;

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> resolveMissingSpecification({
    required String field,
    required String value,
    required String language,
    required String token,
  }) async {
    if (field == 'material') _material = value;
    if (field == 'technique') _technique = value;
    _missingFields.remove(field);
    if (_missingFields.isEmpty) {
      _missingInfoPrompt = null;
    }

    // Re-catalog with updated clarification
    await processVoiceNote(language,
        token: token, clarification: '$field: $value');
  }

  String getListingSummaryForSpeech(String language) {
    if (language == 'mr') {
      final title = _titleHi.isNotEmpty ? _titleHi : _titleEn;
      return "तुमचे उत्पादन: $title. साहित्य: ${_material.isNotEmpty ? _material : 'अस्सल हस्तकला'}. पद्धत: ${_technique.isNotEmpty ? _technique : 'हस्तनिर्मित'}. सुचवलेली किंमत: ₹${_suggestedPrice.toStringAsFixed(0)}.";
    }
    if (language == 'hi') {
      final title = _titleHi.isNotEmpty ? _titleHi : _titleEn;
      return "आपका उत्पाद: $title. सामग्री: ${_material.isNotEmpty ? _material : 'प्राकृतिक हस्तशिल्प'}. तकनीक: ${_technique.isNotEmpty ? _technique : 'पारंपरिक'}. सुझाई गई कीमत: ₹${_suggestedPrice.toStringAsFixed(0)}.";
    }
    return "Your product: $_titleEn. Material: ${_material.isNotEmpty ? _material : 'Handcrafted'}. Technique: ${_technique.isNotEmpty ? _technique : 'Handmade'}. Suggested Price: ₹${_suggestedPrice.toStringAsFixed(0)}.";
  }

  // ─── Step 4: Intelligent Pricing Logic & Overrides ─────────────────────────
  Future<void> recalculatePricing({
    double? materialCost,
    double? laborHours,
    double? hourlyRate,
    double? packagingCost,
    double? shippingCost,
    required String language,
  }) async {
    if (materialCost != null) _materialCost = materialCost;
    if (laborHours != null) _laborHours = laborHours;
    if (hourlyRate != null) _hourlyRate = hourlyRate;
    if (packagingCost != null) _packagingCost = packagingCost;
    if (shippingCost != null) _shippingCost = shippingCost;

    final pricing = await ApiService.recommendPrice(
      category: _categorySlug,
      materialCost: _materialCost,
      laborHours: _laborHours,
      hourlyRate: _hourlyRate,
      packagingCost: _packagingCost,
      shippingCost: _shippingCost,
      platformFeePercent: _platformFeePercent,
      material: _material,
      technique: _technique,
      language: language,
    );

    _costFloor = (pricing['cost_floor'] as num).toDouble();
    _suggestedPrice = (pricing['suggested_price'] as num).toDouble();
    _premiumPrice = (pricing['premium_price'] as num).toDouble();
    _acceptedPrice = _suggestedPrice;
    _priceExplanation = pricing['explanation'] as String? ?? '';
    _isVerifiedMarketPrice = pricing['is_verified_market_price'] == true;
    _pricingBasis = pricing['pricing_basis'] as String? ?? 'cost_plus_estimate';
    _statusLabel =
        pricing['status_label'] as String? ?? 'Unverified Cost-Based Estimate';

    if (pricing['cost_breakdown'] != null) {
      _costBreakdown = Map<String, dynamic>.from(pricing['cost_breakdown']);
    }
    if (pricing['comparable_products'] != null) {
      _comparableProducts = (pricing['comparable_products'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (pricing['influencing_factors'] != null) {
      _influencingFactors = (pricing['influencing_factors'] as List)
          .map((e) => e.toString())
          .toList();
    }

    _customPriceOverride = null;
    _priceOverrideWarning = null;
    notifyListeners();
  }

  void selectPrice(double price) {
    _acceptedPrice = price;
    _customPriceOverride = null;
    _priceOverrideWarning = null;
    notifyListeners();
  }

  Future<void> applyCustomPriceOverride(
      double customPrice, String language) async {
    _customPriceOverride = customPrice;
    _acceptedPrice = customPrice;

    final valRes = await ApiService.validatePriceOverride(
      overridePrice: customPrice,
      costFloor: _costFloor,
      language: language,
    );

    _priceOverrideWarning = valRes['warning'] as String?;
    notifyListeners();
  }

  void setInventoryStock(int count) {
    _inventoryStock = count < 1 ? 1 : count;
    notifyListeners();
  }

  // ─── Save as Draft ─────────────────────────────────────────────────────────
  Future<bool> saveAsDraft(String token) async {
    if (_voiceTranscript.trim().isNotEmpty &&
        (!_englishDescriptionConfirmed || _descriptionEn.trim().isEmpty)) {
      return false;
    }
    final selectedImgs = selectedVariations.isNotEmpty
        ? selectedVariations
            .asMap()
            .entries
            .map((entry) => {
                  'url': entry.value['image_url'],
                  'is_primary': entry.key == 0,
                  'order_index': entry.key,
                })
            .toList()
        : <Map<String, dynamic>>[];

    final draftPayload = {
      'title_en': _titleEn.isNotEmpty ? _titleEn : 'Handcrafted Product Draft',
      'description_en': _descriptionEn,
      'title_hi': _titleHi,
      'description_hi': _descriptionHi,
      'material': _material,
      'technique': _technique,
      'care_instructions': _careInstructions,
      'price': _acceptedPrice,
      'stock': _inventoryStock,
      'status': 'draft',
      'category_slug': _categorySlug,
      'voice_transcript': _voiceTranscript,
      'voice_language': _voiceLanguage,
      'ai_generated': true,
      'draft_product_id': _draftProductId,
      'idempotency_key':
          _draftProductId != null ? 'draft_$_draftProductId' : null,
      'images': selectedImgs,
      'translations': _translations.isNotEmpty
          ? _translations
          : [
              {
                'language': 'en',
                'title': _titleEn,
                'description': _descriptionEn
              },
              {
                'language': 'hi',
                'title': _titleHi,
                'description': _descriptionHi
              },
            ],
    };

    // Save to local SQLite / offline queue
    await OfflineStorageService.queueOfflineProduct(draftPayload);

    // Save to backend API
    try {
      final res =
          await ApiService.createProduct(token: token, payload: draftPayload);
      if (res['id'] != null) {
        _draftProductId = res['id'] as int?;
      }
    } catch (_) {}

    _isDraftSaved = true;
    notifyListeners();
    return true;
  }

  // ─── Step 5: Publish to Website Live ───────────────────────────────────────
  Future<bool> publishProduct(String token) async {
    if (_isPublishing || _isPublished) return true;
    if (_imageJobId == null ||
        _imageJobStatus != 'completed' ||
        !hasSelectedExact3) {
      _publishError = _imageJobError ??
          'Wait for image processing and select exactly three approved images.';
      notifyListeners();
      return false;
    }
    _isPublishing = true;
    _publishError = null;
    notifyListeners();

    try {
      final selectedImgs = selectedVariations.isNotEmpty
          ? selectedVariations
              .asMap()
              .entries
              .map((entry) => {
                    'url': entry.value['image_url'],
                    'is_primary': entry.key == 0,
                    'order_index': entry.key,
                  })
              .toList()
          : <Map<String, dynamic>>[];

      final publishIdempotencyKey = _imageJobId != null
          ? 'pub_$_imageJobId'
          : 'pub_${_draftProductId ?? _voiceTranscript.hashCode}_${_acceptedPrice.toInt()}';
      final payload = {
        'title_en': _titleEn.isNotEmpty ? _titleEn : 'Handcrafted Creation',
        'description_en': _descriptionEn,
        'title_hi': _titleHi,
        'description_hi': _descriptionHi,
        'material': _material,
        'technique': _technique,
        'care_instructions': _careInstructions,
        'price': _acceptedPrice,
        'stock': _inventoryStock,
        'status': 'published',
        'category_slug': _categorySlug,
        'voice_transcript': _voiceTranscript,
        'voice_language': _voiceLanguage,
        'ai_generated': true,
        'image_job_id': _imageJobId,
        'selected_variant_ids': selectedVariations
            .map((v) => (v['id'] ?? v['variant_id']).toString())
            .toList(),
        'draft_product_id': _draftProductId,
        'idempotency_key': publishIdempotencyKey,
        'images': selectedImgs,
        'translations': _translations.isNotEmpty
            ? _translations
            : [
                {
                  'language': 'en',
                  'title': _titleEn,
                  'description': _descriptionEn
                },
                {
                  'language': 'hi',
                  'title': _titleHi,
                  'description': _descriptionHi
                },
              ],
      };

      final res =
          await ApiService.createProduct(token: token, payload: payload);
      _isPublishing = false;
      _isPublished = true;
      _publishedProductId = res['id'] as int?;
      notifyListeners();
      return true;
    } catch (e) {
      _isPublishing = false;
      _publishError =
          "प्रकाशन अयशस्वी झाले. कृपया इंटरनेट तपासून पुन्हा प्रयत्न करा.";
      notifyListeners();
      return false;
    }
  }

  void resetWizard() {
    _currentStep = 0;
    _photos.clear();
    _isUploadingPhoto = false;
    _photoUploadError = null;
    _photoUploadId = null;
    _attachedPhotoUploadId = null;
    _photoFileName = null;
    _photoContentType = null;
    _originalImageUrl = null;
    _enhancedImageBase64 = null;
    _imageVariations.clear();
    _imageJobId = null;
    _imageJobAttempt = 0;
    _imageJobStatus = null;
    _imageJobError = null;
    _imageProcessingMode = null;
    _selectedVariationIds.clear();
    _voiceTranscript = "";
    _voiceLanguage = 'en';
    _speechError = null;
    _descriptionNeedsReview = false;
    _descriptionManuallyEdited = false;
    _englishDescriptionConfirmed = false;
    _draftProductId = null;
    _publishError = null;
    _inventoryStock = 5;
    _titleEn = "";
    _titleHi = "";
    _shortDescriptionEn = "";
    _shortDescriptionHi = "";
    _descriptionEn = "";
    _descriptionHi = "";
    _material = "";
    _technique = "";
    _careInstructions = "";
    _translations = [];
    _missingFields = [];
    _missingInfoPrompt = null;
    _isDraftSaved = false;
    _materialCost = 85.0;
    _laborHours = 4.5;
    _costFloor = 480.0;
    _suggestedPrice = 630.0;
    _premiumPrice = 850.0;
    _acceptedPrice = 630.0;
    _customPriceOverride = null;
    _priceOverrideWarning = null;
    _comparableProducts = [];
    _isVerifiedMarketPrice = false;
    _isPublished = false;
    _isPublishing = false;
    notifyListeners();
  }
}
