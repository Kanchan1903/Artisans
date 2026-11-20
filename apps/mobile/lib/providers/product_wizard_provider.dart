import 'dart:convert';
import 'dart:math' as math;
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
  bool _finalDescriptionConfirmed = false;
  bool _finalPriceConfirmed = false;
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
  final List<String> _photoUploadIds = [];
  final Set<String> _attachedPhotoUploadIds = {};
  final List<String> _photoFileNames = [];
  final List<String> _photoContentTypes = [];
  final List<String?> _originalImageUrls = [];
  String _cameraGuidance = "Move closer to your craft";

  // Step 2: Studio Image Variations
  String? _enhancedImageBase64;
  List<Map<String, dynamic>> _imageVariations = [];
  Set<String> _selectedVariationIds = {};

  // WhatsApp-like AI Photo Studio State
  bool _isRemovingBackground = false;
  bool _isComposingBackground = false;
  String? _cutoutBase64;
  String? _currentStudioImageBase64;
  String _selectedBackgroundId = 'transparent';
  Color _customColor = const Color(0xFFFFFFFF);
  final List<String> _undoHistory = [];
  final List<String> _redoHistory = [];
  bool _showOriginal = false;
  bool _hasRemovedBackground = false;
  String? _studioError;

  // Step 3: Voice & Catalog
  String _voiceTranscript = "";
  bool _isRecording = false;
  bool _isAudioPlaying = false;
  String? _detectedLanguage;
  String? _detectedLanguageName;
  bool _isDescriptionApproved = false;
  String _titleEn = "";
  String _titleHi = "";
  String _shortDescriptionEn = "";
  String _shortDescriptionHi = "";
  String _descriptionEn = "";
  String _descriptionHi = "";
  String _material = "";
  String _technique = "";
  String _dimensions = "";
  double? _weightGrams;
  String _additionalDetails = "";
  String _categorySlug = "pottery";
  String _careInstructions = "";
  List<String> _seoKeywords = [];
  List<Map<String, dynamic>> _translations = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = false;
  String? _categoriesError;
  List<String> _missingFields = [];
  String? _missingInfoPrompt;
  bool _isDraftSaved = false;

  // Step 4: Intelligent Pricing
  double _materialCost = 0.0;
  double _laborHours = 0.0;
  double _hourlyRate = 0.0;
  double _packagingCost = 0.0;
  double _shippingCost = 0.0;
  double _platformFeePercent = 0.0;
  bool _hasArtisanCostInputs = false;
  bool _isPricingLoading = false;
  bool _priceSelectionSaved = false;
  String _currency = 'INR';
  String _pricingConfidence = 'none';
  bool _requiresPricingReview = true;
  int? _pricingRevisionId;
  int _pricingVersion = 0;
  double? _priceRangeMin;
  double? _priceRangeMax;
  String? _pricingError;
  Map<String, dynamic>? _previousPricingRecommendation;

  double _costFloor = 0.0;
  double _suggestedPrice = 0.0;
  double _premiumPrice = 0.0;
  double _acceptedPrice = 0.0;
  double? _customPriceOverride;
  String? _priceOverrideWarning;

  String _pricingBasis = "storefront_comparables";
  String _statusLabel = "No storefront evidence loaded";
  Map<String, dynamic> _costBreakdown = {};
  List<Map<String, dynamic>> _comparableProducts = [];
  List<String> _influencingFactors = [];
  String _priceExplanation = "";
  List<Map<String, dynamic>> _pricingSources = [];
  bool _isDynamicPricingLoading = false;
  bool _isRevisedByVoiceFeedback = false;
  String? _voiceFeedbackTranscript;
  bool _isPricePreferenceScreenActive = false;

  // Step 5: Publish
  bool _isPublishing = false;
  bool _isPublished = false;
  int? _publishedProductId;
  int? _draftProductId;
  String? _publishError;
  int _inventoryStock = 5;
  bool _isCatalogBuilderProcessing = false;
  String _catalogBuilderState = 'draft';
  String? _catalogBuilderError;
  Map<String, dynamic> _catalogBuilderOutput = {};

  // Getters
  int get currentStep => _currentStep;
  int? get draftProductId => _draftProductId;
  String? get publishError => _publishError;
  bool get isCatalogBuilderProcessing => _isCatalogBuilderProcessing;
  String get catalogBuilderState => _catalogBuilderState;
  String? get catalogBuilderError => _catalogBuilderError;
  Map<String, dynamic> get catalogBuilderOutput =>
      Map.unmodifiable(_catalogBuilderOutput);
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

  // WhatsApp-like Studio Getters
  bool get isRemovingBackground => _isRemovingBackground;
  bool get isComposingBackground => _isComposingBackground;
  String? get cutoutBase64 => _cutoutBase64;
  String? get currentStudioImageBase64 => _currentStudioImageBase64;
  String get selectedBackgroundId => _selectedBackgroundId;
  Color get customColor => _customColor;
  Color get currentBackgroundColor {
    switch (_selectedBackgroundId) {
      case 'white':
        return const Color(0xFFFFFFFF);
      case 'cream':
        return const Color(0xFFFFFDD0);
      case 'beige':
        return const Color(0xFFF5F5DC);
      case 'light_grey':
        return const Color(0xFFE0E0E0);
      case 'pastel_pink':
        return const Color(0xFFFFD1DC);
      case 'pastel_blue':
        return const Color(0xFFAEC6CF);
      case 'light_green':
        return const Color(0xFFC1E1C1);
      case 'wooden_texture':
        return const Color(0xFFDAB994);
      case 'studio_background':
        return const Color(0xFFF8FAFD);
      case 'festive_background':
        return const Color(0xFFFFDAA5);
      case 'custom':
        return _customColor;
      default:
        return Colors.transparent;
    }
  }
  bool get canUndo => _undoHistory.isNotEmpty;
  bool get canRedo => _redoHistory.isNotEmpty;
  bool get showOriginal => _showOriginal;
  bool get hasRemovedBackground => _hasRemovedBackground;
  String? get studioError => _studioError;
  String get voiceTranscript => _voiceTranscript;
  bool get isRecording => _isRecording;
  bool get speechAvailable => _speechAvailable;
  String? get speechError => _speechError;
  String get voiceLanguage => _voiceLanguage;
  bool get isAudioPlaying => _isAudioPlaying;
  String? get detectedLanguage => _detectedLanguage;
  String? get detectedLanguageName => _detectedLanguageName;
  bool get isDescriptionApproved => _isDescriptionApproved;
  bool get descriptionNeedsReview => _descriptionNeedsReview;
  bool get englishDescriptionConfirmed => _englishDescriptionConfirmed;
  bool get finalDescriptionConfirmed => _finalDescriptionConfirmed;
  bool get finalPriceConfirmed => _finalPriceConfirmed;
  List<stt.LocaleName> get speechLocales => List.unmodifiable(_speechLocales);
  String get titleEn => _titleEn;
  String get titleHi => _titleHi;
  String get shortDescriptionEn => _shortDescriptionEn;
  String get shortDescriptionHi => _shortDescriptionHi;
  String get descriptionEn => _descriptionEn;
  String get descriptionHi => _descriptionHi;
  String get material => _material;
  String get technique => _technique;
  String get dimensions => _dimensions;
  double? get weightGrams => _weightGrams;
  String get additionalDetails => _additionalDetails;
  String get categorySlug => _categorySlug;
  List<Map<String, dynamic>> get categories => List.unmodifiable(_categories);
  bool get isLoadingCategories => _isLoadingCategories;
  String? get categoriesError => _categoriesError;
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
      _photos.isNotEmpty && _photoUploadIds.length == _photos.length;
  bool get isCurrentPhotoUploaded =>
      _photos.isNotEmpty &&
      _photoUploadIds.length == _photos.length &&
      _photoUploadIds.every(_attachedPhotoUploadIds.contains) &&
      _originalImageUrls.every((url) => url != null);
  String? get originalImageUrl =>
      _originalImageUrls.isEmpty ? null : _originalImageUrls.first;

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
  bool get isVerifiedMarketPrice => _comparableProducts.isNotEmpty || _pricingSources.isNotEmpty;
  String get pricingBasis => _pricingBasis;
  String get statusLabel => _statusLabel;
  Map<String, dynamic> get costBreakdown => _costBreakdown;
  List<Map<String, dynamic>> get comparableProducts => _comparableProducts;
  List<String> get influencingFactors => _influencingFactors;
  String get priceExplanation => _priceExplanation;
  List<Map<String, dynamic>> get pricingSources => List.unmodifiable(_pricingSources);
  bool get isDynamicPricingLoading => _isDynamicPricingLoading;
  bool get isRevisedByVoiceFeedback => _isRevisedByVoiceFeedback;
  String? get voiceFeedbackTranscript => _voiceFeedbackTranscript;
  bool get isPricePreferenceScreenActive => _isPricePreferenceScreenActive;
  bool get isPricingLoading => _isPricingLoading;
  bool get priceSelectionSaved => _priceSelectionSaved;
  String get currency => _currency;
  String get pricingConfidence => _pricingConfidence;
  bool get requiresPricingReview => _requiresPricingReview;
  int? get pricingRevisionId => _pricingRevisionId;
  int get pricingVersion => _pricingVersion;
  double? get priceRangeMin => _priceRangeMin;
  double? get priceRangeMax => _priceRangeMax;
  String? get pricingError => _pricingError;
  Map<String, dynamic>? get previousPricingRecommendation =>
      _previousPricingRecommendation;
  bool get hasArtisanCostInputs => _hasArtisanCostInputs;
  bool get hasSuggestedPrice => _suggestedPrice > 0;

  Map<String, dynamic> _parseAdditionalDetails(String value) =>
      value.trim().isEmpty ? <String, dynamic>{} : {'notes': value.trim()};

  // Publish Getters
  bool get isPublishing => _isPublishing;
  bool get isPublished => _isPublished;
  int? get publishedProductId => _publishedProductId;

  set titleEn(String val) {
    _titleEn = val;
    notifyListeners();
  }

  void setTitleEn(String value) {
    _titleEn = value;
    _isDraftSaved = false;
    notifyListeners();
  }

  set titleHi(String val) {
    _titleHi = val;
    notifyListeners();
  }

  set acceptedPrice(double val) {
    if (_acceptedPrice != val) {
      _priceSelectionSaved = false;
      _finalPriceConfirmed = false;
      _customPriceOverride = val > 0 ? val : null;
    }
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

  void goToStep(int step) {
    if (step >= 0 && step <= 4 && !_isPublishing && !_isPublished) {
      _currentStep = step;
      notifyListeners();
    }
  }

  void confirmFinalDescription(bool confirmed) {
    _finalDescriptionConfirmed =
        confirmed && _descriptionEn.trim().length >= 10;
    notifyListeners();
  }

  void confirmFinalPrice(bool confirmed) {
    _finalPriceConfirmed =
        confirmed && _acceptedPrice.isFinite && _acceptedPrice > 0;
    notifyListeners();
  }

  bool get canPublishProduct =>
      _titleEn.trim().length >= 2 &&
      _categorySlug.isNotEmpty &&
      _descriptionEn.trim().length >= 5 &&
      _finalDescriptionConfirmed &&
      _acceptedPrice.isFinite &&
      _acceptedPrice > 0 &&
      _finalPriceConfirmed;

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
    _cutoutBase64 = null;
    _currentStudioImageBase64 = null;
    _selectedBackgroundId = 'transparent';
    _undoHistory.clear();
    _redoHistory.clear();
    _showOriginal = false;
    _hasRemovedBackground = false;
    _studioError = null;
  }

  Future<bool> clearPhotos({required String? token}) async {
    if (_isUploadingPhoto) return false;
    final uploadIds = {..._photoUploadIds, ..._attachedPhotoUploadIds};
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
    _photoUploadIds.clear();
    _attachedPhotoUploadIds.clear();
    _photoFileNames.clear();
    _photoContentTypes.clear();
    _originalImageUrls.clear();
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
        return await _acceptPickedImages([image], token);
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
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (images.isNotEmpty) {
        return await _acceptPickedImages(images, token);
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

  Future<bool> _acceptPickedImages(List<XFile> images, String? token) async {
    if (_photos.length + images.length > 5) {
      _photoUploadError = 'A product can have up to five photos.';
      return false;
    }
    final pending = <(Uint8List, String, String, String)>[];
    for (final image in images) {
      final bytes = await image.readAsBytes();
      final imageType = detectProductImageType(bytes);
      if (imageType == null) {
        _photoUploadError =
            'Unsupported image. Choose JPEG, PNG, or WebP photos.';
        return false;
      }
      if (bytes.length > maxProductPhotoBytes) {
        _photoUploadError = 'Each photo must be smaller than 10 MB.';
        return false;
      }
      pending.add((bytes, image.name, imageType.$2, imageType.$1));
    }

    for (final photo in pending) {
      _photos.add(photo.$1);
      _photoFileNames.add('product_photo.${photo.$4}');
      _photoContentTypes.add(photo.$3);
      _photoUploadIds.add(_newPhotoUploadId());
      _originalImageUrls.add(null);
    }
    _resetVariations();
    _photoUploadError = null;
    _photoUploadRequiresAuthentication = false;
    _lastCameraError = null;
    notifyListeners();

    if (token == null || token.isEmpty) {
      _photoUploadError =
          'Sign in to upload and save this photo to your product draft.';
      return true;
    }
    for (var index = _photoUploadIds.length - pending.length;
        index < _photoUploadIds.length;
        index++) {
      await _uploadPhotoAt(token, index);
      if (_photoUploadError != null) break;
    }
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
        math.Random.secure().nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
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
    if (_isUploadingPhoto || _photos.isEmpty) return;
    if (token == null || token.isEmpty) {
      _photoUploadError =
          'Sign in to upload and save this photo to your product draft.';
      notifyListeners();
      return;
    }
    _isUploadingPhoto = true;
    notifyListeners();
    try {
      for (var index = 0; index < _photos.length; index++) {
        if (!_attachedPhotoUploadIds.contains(_photoUploadIds[index])) {
          await _uploadPhotoAt(token, index);
          if (_photoUploadError != null) break;
        }
      }
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }
  }

  Future<void> _uploadPhotoAt(String token, int index) async {
    try {
      final result = await ApiService.uploadDraftProductImage(
        token: token,
        imageBytes: _photos[index],
        filename: _photoFileNames[index],
        contentType: _photoContentTypes[index],
        uploadId: _photoUploadIds[index],
        productId: _draftProductId?.toString(),
        categorySlug: _categorySlug,
      );
      _draftProductId = result['product_id'] as int? ?? _draftProductId;
      _originalImageUrls[index] = result['image_url'] as String?;
      _attachedPhotoUploadIds.add(_photoUploadIds[index]);
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
      _photoUploadIds.clear();
      _attachedPhotoUploadIds.clear();
      _photoFileNames.clear();
      _photoContentTypes.clear();
      _originalImageUrls.clear();
      _photoUploadError =
          'Sample photos are for preview only and are not uploaded to a product draft.';
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading sample asset: $e');
    }
  }

  // ─── WhatsApp-like AI Photo Studio Methods ──────────────────────────────
  void toggleShowOriginal() {
    _showOriginal = !_showOriginal;
    notifyListeners();
  }

  void setShowOriginal(bool val) {
    _showOriginal = val;
    notifyListeners();
  }

  Future<void> removeBackground() async {
    if (_photos.isEmpty || _isRemovingBackground) return;
    _isRemovingBackground = true;
    _studioError = null;
    notifyListeners();

    try {
      final res = await ApiService.removeBackground(_photos.first);
      _cutoutBase64 = res['cutout_base64'] as String?;
      _currentStudioImageBase64 = _cutoutBase64;
      _hasRemovedBackground = true;
      _selectedBackgroundId = 'transparent';
      _undoHistory.clear();
      _redoHistory.clear();
    } catch (e) {
      debugPrint('Background removal failed: $e');
      _studioError = e.toString().replaceFirst('Exception: ', '');
      // If server failed, keep the original photo so screen never turns blank
      final b64 = base64Encode(_photos.first);
      _cutoutBase64 = 'data:image/jpeg;base64,$b64';
      _currentStudioImageBase64 = _cutoutBase64;
      _hasRemovedBackground = false;
      _selectedBackgroundId = 'transparent';
      _undoHistory.clear();
      _redoHistory.clear();
    } finally {
      _isRemovingBackground = false;
      notifyListeners();
    }
  }

  Future<void> selectBackground(String bgId, {Color? customColor}) async {
    if (_cutoutBase64 == null) return;
    if (_selectedBackgroundId == bgId && customColor == null) return;

    // Push current to undo history
    if (_currentStudioImageBase64 != null) {
      _undoHistory.add(_currentStudioImageBase64!);
      _redoHistory.clear();
    }

    _selectedBackgroundId = bgId;
    if (customColor != null) {
      _customColor = customColor;
    }

    if (bgId == 'transparent') {
      _currentStudioImageBase64 = _cutoutBase64;
      notifyListeners();
      return;
    }

    // Instantly show the selected background style in the studio canvas
    if (_hasRemovedBackground) {
      _currentStudioImageBase64 = _cutoutBase64;
      notifyListeners();
    }

    _isComposingBackground = true;
    notifyListeners();

    try {
      String bgType = 'color';
      String hexColor = '#FFFFFF';

      switch (bgId) {
        case 'white':
          hexColor = '#FFFFFF';
          break;
        case 'cream':
          hexColor = '#FFFDD0';
          break;
        case 'beige':
          hexColor = '#F5F5DC';
          break;
        case 'light_grey':
          hexColor = '#E0E0E0';
          break;
        case 'pastel_pink':
          hexColor = '#FFD1DC';
          break;
        case 'pastel_blue':
          hexColor = '#AEC6CF';
          break;
        case 'light_green':
          hexColor = '#C1E1C1';
          break;
        case 'wooden_texture':
          bgType = 'wood';
          break;
        case 'studio_background':
          bgType = 'studio';
          break;
        case 'festive_background':
          bgType = 'festive';
          break;
        case 'custom':
          final argb = _customColor.toARGB32();
          final r = ((argb >> 16) & 0xFF).toRadixString(16).padLeft(2, '0');
          final g = ((argb >> 8) & 0xFF).toRadixString(16).padLeft(2, '0');
          final b = (argb & 0xFF).toRadixString(16).padLeft(2, '0');
          hexColor = '#$r$g$b';
          break;
      }

      final composed = await ApiService.composeBackground(
        cutoutBase64: _cutoutBase64!,
        backgroundType: bgType,
        bgColorHex: hexColor,
        hasShadow: true,
      );

      _currentStudioImageBase64 = composed;
    } catch (e) {
      debugPrint('Background compose failed: ');
      // Graceful offline fallback
      _currentStudioImageBase64 = _cutoutBase64;
    } finally {
      _isComposingBackground = false;
      notifyListeners();
    }
  }

  void undo() {
    if (_undoHistory.isNotEmpty && _currentStudioImageBase64 != null) {
      _redoHistory.add(_currentStudioImageBase64!);
      _currentStudioImageBase64 = _undoHistory.removeLast();
      notifyListeners();
    }
  }

  void redo() {
    if (_redoHistory.isNotEmpty && _currentStudioImageBase64 != null) {
      _undoHistory.add(_currentStudioImageBase64!);
      _currentStudioImageBase64 = _redoHistory.removeLast();
      notifyListeners();
    }
  }

  void resetStudio() {
    if (_photos.isEmpty) return;
    _undoHistory.clear();
    _redoHistory.clear();
    _selectedBackgroundId = 'transparent';
    _currentStudioImageBase64 = _cutoutBase64;
    _showOriginal = false;
    notifyListeners();
  }

  Future<void> selectImageForListing(String token) async {
    if (_currentStudioImageBase64 == null) return;
    try {
      final base64Clean = _currentStudioImageBase64!.contains(',')
          ? _currentStudioImageBase64!.split(',').last
          : _currentStudioImageBase64!;
      final bytes = base64Decode(base64Clean);
      _photos.clear();
      _photos.add(bytes);
      _enhancedImageBase64 = _currentStudioImageBase64;
      await processPhotoInAIStudio(token: token, forceRegenerate: true);
    } catch (e) {
      debugPrint('Error selecting image for listing: ');
    }
  }

  // ─── AI Studio Step ────────────────────────────────────────────────────────
  Future<void> processPhotoInAIStudio(
      {required String token, bool forceRegenerate = false}) async {
    if (_photos.isEmpty) return;
    if (_isProcessingAI) return;
    if (_imageVariations.isNotEmpty && !forceRegenerate) return;
    final retryFailedJob = _imageJobStatus == 'failed' && _imageJobId != null;
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
        current = retryFailedJob
            ? await ApiService.retryImageJob(token: token, jobId: _imageJobId!)
            : await ApiService.getImageJob(token: token, jobId: _imageJobId!);
      } else {
        current = await ApiService.startImageJob(
          token: token,
          imageBytes: _photos[0],
          contentType: _photoContentTypes.first,
          uploadId: _photoUploadIds.isEmpty
              ? null
              : '${_photoUploadIds.first}_ai_$_imageJobAttempt',
          productId: _draftProductId,
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

  Future<void> startSpeechRecognition({Function(String)? onFinalSpeech}) async {
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
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
        ),
        onResult: (SpeechRecognitionResult result) {
          _voiceTranscript = result.recognizedWords;
          notifyListeners();
          if (result.finalResult && onFinalSpeech != null) {
            onFinalSpeech(_voiceTranscript);
          }
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

  Future<void> loadCategories() async {
    if (_isLoadingCategories) return;
    _isLoadingCategories = true;
    _categoriesError = null;
    notifyListeners();
    try {
      _categories = await ApiService.getProductCategories();
      _categoriesError = null;
      if (!_categories.any((category) => category['slug'] == _categorySlug) &&
          _categories.isNotEmpty) {
        _categorySlug = _categories.first['slug'].toString();
      }
    } catch (error) {
      _categoriesError = error.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  void setCategorySlug(String slug) {
    if (_categories.any((category) => category['slug'] == slug)) {
      _categorySlug = slug;
      _isDraftSaved = false;
      notifyListeners();
    }
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
    String? dimensions,
    double? weightGrams,
    String? additionalDetails,
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
    if (dimensions != null) _dimensions = dimensions;
    if (weightGrams != null) _weightGrams = weightGrams;
    if (additionalDetails != null) _additionalDetails = additionalDetails;
    if (careInstructions != null) _careInstructions = careInstructions;
    notifyListeners();
  }

  void setDescriptionApproved(bool approved) {
    _isDescriptionApproved = approved;
    _englishDescriptionConfirmed = approved;
    _finalDescriptionConfirmed = approved;
    notifyListeners();
  }

  void setIsAudioPlaying(bool playing) {
    _isAudioPlaying = playing;
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
    _isDescriptionApproved = false;
    notifyListeners();

    try {
      final agentResult = await ApiService.runVoiceDescriptionWorkflow(
        transcript: transcript,
        preferredLanguage: _voiceLanguage,
        clarification: clarification,
      );

      if (agentResult['success'] == true) {
        _detectedLanguage = agentResult['detected_language'] as String?;
        _detectedLanguageName = agentResult['detected_language_name'] as String?;
        _titleEn = agentResult['title'] as String? ?? _titleEn;
        _titleHi = agentResult['title_hi'] as String? ?? _titleHi;
        _shortDescriptionEn = agentResult['short_description'] as String? ?? _shortDescriptionEn;
        _descriptionEn = agentResult['detailed_description'] as String? ?? _descriptionEn;
        _categorySlug = agentResult['category_slug'] as String? ?? _categorySlug;
        
        final materialsList = (agentResult['materials'] as List?)?.map((e) => e.toString()).toList();
        if (materialsList != null && materialsList.isNotEmpty) {
          _material = materialsList.join(', ');
        }
        final techList = (agentResult['techniques'] as List?)?.map((e) => e.toString()).toList();
        if (techList != null && techList.isNotEmpty) {
          _technique = techList.join(', ');
        }
        if (agentResult['dimensions'] != null) {
          _dimensions = agentResult['dimensions'].toString();
        }

        final kw = (agentResult['seo_keywords'] as List?)?.map((e) => e.toString()).toList();
        if (kw != null && kw.isNotEmpty) {
          _seoKeywords = kw;
        }

        if (agentResult['needs_clarification'] == true) {
          _missingFields = ['material'];
          _missingInfoPrompt = agentResult['clarification_prompt'] as String?;
        } else {
          _missingFields.clear();
          _missingInfoPrompt = null;
        }

        _descriptionNeedsReview = true;
        _descriptionManuallyEdited = false;
        _englishDescriptionConfirmed = false;
        _isProcessingAI = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Voice description workflow network error: $e');
    }

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
    late final Map<String, dynamic> catalog;
    try {
      catalog = await ApiService.catalogProduct(
        transcript: transcript,
        language: _voiceLanguage,
        imageBase64: _enhancedImageBase64,
        clarification: clarification,
      );
    } catch (error) {
      _speechError = error.toString().replaceFirst('Exception: ', '');
      _isProcessingAI = false;
      notifyListeners();
      return;
    }

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

    _isProcessingAI = false;
    notifyListeners();
  }

  void updateEnglishDescription(String value) {
    _descriptionEn = value;
    _descriptionManuallyEdited = true;
    _descriptionNeedsReview = false;
    _englishDescriptionConfirmed = false;
    _finalDescriptionConfirmed = false;
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

  void setWeightGrams(double? value) {
    _weightGrams = value;
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
    final priceSentence = _suggestedPrice > 0
        ? (language == 'mr'
            ? ' सुचवलेली किंमत: ₹${_suggestedPrice.toStringAsFixed(0)}.'
            : language == 'hi'
                ? ' सुझाई गई कीमत: ₹${_suggestedPrice.toStringAsFixed(0)}.'
                : ' Suggested price: ₹${_suggestedPrice.toStringAsFixed(0)}.')
        : '';
    if (language == 'mr') {
      final title = _titleHi.isNotEmpty ? _titleHi : _titleEn;
      return "तुमचे उत्पादन: $title. साहित्य: ${_material.isNotEmpty ? _material : 'अस्सल हस्तकला'}. पद्धत: ${_technique.isNotEmpty ? _technique : 'हस्तनिर्मित'}.$priceSentence";
    }
    if (language == 'hi') {
      final title = _titleHi.isNotEmpty ? _titleHi : _titleEn;
      return "आपका उत्पाद: $title. सामग्री: ${_material.isNotEmpty ? _material : 'प्राकृतिक हस्तशिल्प'}. तकनीक: ${_technique.isNotEmpty ? _technique : 'पारंपरिक'}.$priceSentence";
    }
    return "Your product: $_titleEn. Material: ${_material.isNotEmpty ? _material : 'Handcrafted'}. Technique: ${_technique.isNotEmpty ? _technique : 'Handmade'}.$priceSentence";
  }

  // ─── Step 4: Intelligent Pricing Logic & Overrides ─────────────────────────
  Map<String, double> get _providedCosts => _hasArtisanCostInputs
      ? {
          if (_materialCost > 0) 'material_cost': _materialCost,
          if (_laborHours > 0) 'labor_hours': _laborHours,
          if (_hourlyRate > 0) 'hourly_rate': _hourlyRate,
          if (_packagingCost > 0) 'packaging_cost': _packagingCost,
          if (_shippingCost > 0) 'shipping_cost': _shippingCost,
        }
      : const {};

  String _newPricingRequestKey() =>
      '${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1 << 32)}';

  void setPricePreferenceScreenActive(bool active) {
    _isPricePreferenceScreenActive = active;
    notifyListeners();
  }

  Future<void> submitVoicePricingFeedback({
    required String voiceFeedback,
    required String token,
  }) async {
    _voiceFeedbackTranscript = voiceFeedback;
    _isDynamicPricingLoading = true;
    _pricingError = null;
    notifyListeners();

    try {
      final res = await ApiService.runDynamicPricingWorkflow(
        title: _titleEn.isNotEmpty ? _titleEn : 'Handcrafted Craft',
        categorySlug: _categorySlug,
        material: _material,
        description: _descriptionEn.isNotEmpty ? _descriptionEn : _voiceTranscript,
        materialCost: _materialCost > 0 ? _materialCost : null,
        laborHours: _laborHours > 0 ? _laborHours : null,
        hourlyRate: _hourlyRate > 0 ? _hourlyRate : 85.0,
        packagingCost: _packagingCost > 0 ? _packagingCost : null,
        shippingCost: _shippingCost > 0 ? _shippingCost : null,
        voiceFeedback: voiceFeedback,
      );

      if (res['success'] == true) {
        _suggestedPrice = (res['recommended_price'] as num?)?.toDouble() ?? _suggestedPrice;
        _acceptedPrice = _suggestedPrice;
        _priceRangeMin = (res['price_range_min'] as num?)?.toDouble() ?? _priceRangeMin;
        _priceRangeMax = (res['price_range_max'] as num?)?.toDouble() ?? _priceRangeMax;
        _priceExplanation = res['explanation'] as String? ?? _priceExplanation;
        _isRevisedByVoiceFeedback = true;
        _isPricePreferenceScreenActive = false; // return to review screen
        
        if (res['sources'] is List) {
          _pricingSources = (res['sources'] as List)
              .map((s) => Map<String, dynamic>.from(s as Map))
              .toList();
        }
        if (res['cost_breakdown'] is Map) {
          _costBreakdown = Map<String, dynamic>.from(res['cost_breakdown'] as Map);
        }
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Voice pricing feedback agent error: $e');
    } finally {
      _isDynamicPricingLoading = false;
      notifyListeners();
    }
  }

  Future<bool> loadPricingRecommendation({required String token}) async {
    _isDynamicPricingLoading = true;
    notifyListeners();

    // Trigger Dynamic Pricing AI Agent in parallel for live market research & sources based on product description
    try {
      final agentRes = await ApiService.runDynamicPricingWorkflow(
        title: _titleEn.isNotEmpty ? _titleEn : 'Handcrafted Craft',
        categorySlug: _categorySlug,
        material: _material,
        description: _descriptionEn.isNotEmpty ? _descriptionEn : _voiceTranscript,
        materialCost: _materialCost > 0 ? _materialCost : null,
        laborHours: _laborHours > 0 ? _laborHours : null,
        hourlyRate: _hourlyRate > 0 ? _hourlyRate : 85.0,
        packagingCost: _packagingCost > 0 ? _packagingCost : null,
        shippingCost: _shippingCost > 0 ? _shippingCost : null,
      );

      if (agentRes['success'] == true) {
        _suggestedPrice = (agentRes['recommended_price'] as num?)?.toDouble() ?? _suggestedPrice;
        _acceptedPrice = _suggestedPrice;
        _priceRangeMin = (agentRes['price_range_min'] as num?)?.toDouble() ?? _priceRangeMin;
        _priceRangeMax = (agentRes['price_range_max'] as num?)?.toDouble() ?? _priceRangeMax;
        _priceExplanation = agentRes['explanation'] as String? ?? _priceExplanation;
        
        if (agentRes['sources'] is List) {
          _pricingSources = (agentRes['sources'] as List)
              .map((s) => Map<String, dynamic>.from(s as Map))
              .toList();
        }
        if (agentRes['cost_breakdown'] is Map) {
          _costBreakdown = Map<String, dynamic>.from(agentRes['cost_breakdown'] as Map);
        }
      }
    } catch (e) {
      debugPrint('Dynamic pricing agent initial run error: $e');
    } finally {
      _isDynamicPricingLoading = false;
      notifyListeners();
    }

    final productId = _draftProductId;
    if (productId == null) {
      _pricingError =
          'Save and upload this product draft before requesting a price recommendation.';
      notifyListeners();
      return false;
    }
    if (_isPricingLoading) return false;
    _isPricingLoading = true;
    _pricingError = null;
    notifyListeners();
    try {
      await ApiService.updateProduct(
        token: token,
        productId: productId,
        payload: {
          'title_en': _titleEn.isNotEmpty ? _titleEn : 'Handcrafted Creation',
          'description_en': _descriptionEn,
          'title_hi': _titleHi,
          'description_hi': _descriptionHi,
          'material': _material,
          'technique': _technique,
          'dimensions': _dimensions,
          'weight_grams': _weightGrams,
          'additional_details': _parseAdditionalDetails(_additionalDetails),
          'care_instructions': _careInstructions,
          'voice_transcript': _voiceTranscript,
          'voice_language': _voiceLanguage,
          'seo_keywords': _seoKeywords,
        },
      );
      final result = await ApiService.recommendProductPrice(
        token: token,
        productId: productId,
        idempotencyKey: _newPricingRequestKey(),
        costs: _providedCosts,
      );
      _previousPricingRecommendation = null;
      _applyPricingResponse(result);
      _priceSelectionSaved = false;
      _customPriceOverride = null;
      _priceOverrideWarning = null;
      return true;
    } catch (error) {
      _pricingError = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isPricingLoading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _pricingSnapshot() => {
        'revision_id': _pricingRevisionId,
        'version': _pricingVersion,
        'suggested_price': _suggestedPrice > 0 ? _suggestedPrice : null,
        'price_range_min': _priceRangeMin,
        'price_range_max': _priceRangeMax,
        'currency': _currency,
        'comparable_products': _comparableProducts
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
        'comparison_summary': _priceExplanation,
        'confidence': _pricingConfidence,
        'requires_review': _requiresPricingReview,
      };

  void _applyPricingResponse(Map<String, dynamic> result) {
    _pricingRevisionId = (result['revision_id'] as num?)?.toInt();
    _pricingVersion = (result['version'] as num?)?.toInt() ?? 0;
    _currency = result['currency'] as String? ?? 'INR';
    final resPrice = (result['suggested_price'] as num?)?.toDouble() ?? 0;
    if (resPrice > 0) {
      _suggestedPrice = resPrice;
    }
    _priceRangeMin = (result['price_range_min'] as num?)?.toDouble() ?? _priceRangeMin;
    _priceRangeMax = (result['price_range_max'] as num?)?.toDouble() ?? _priceRangeMax;
    _pricingConfidence = result['confidence'] as String? ?? 'high';
    _requiresPricingReview = result['requires_review'] == true;
    _priceExplanation = (result['comparison_summary'] as String?)?.isNotEmpty == true
        ? (result['comparison_summary'] as String)
        : _priceExplanation;
    _comparableProducts = ((result['comparable_products'] as List?) ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    _influencingFactors = ((result['pricing_factors'] as List?) ?? [])
        .map((item) => item.toString())
        .toList();
    _pricingError = result['error'] == 'insufficient_comparable_data'
        ? 'There are not enough comparable published products to suggest a price. You can set your own price.'
        : result['error'] as String?;
    _pricingBasis = 'storefront_comparables';
    _statusLabel = _comparableProducts.isEmpty
        ? 'Insufficient storefront evidence'
        : 'Published storefront comparison';
    if (_suggestedPrice > 0 && _customPriceOverride == null) {
      _acceptedPrice = _suggestedPrice;
    }
    _costFloor = 0;
    _premiumPrice = 0;
  }

  Future<bool> challengePricing({
    required String token,
    required String reason,
    String? context,
  }) async {
    final productId = _draftProductId;
    final previousId = _pricingRevisionId;
    if (productId == null || previousId == null || _isPricingLoading) {
      _pricingError =
          'Load a current recommendation before requesting a recheck.';
      notifyListeners();
      return false;
    }
    _isPricingLoading = true;
    _pricingError = null;
    _previousPricingRecommendation = _pricingSnapshot();
    notifyListeners();
    try {
      final result = await ApiService.challengeProductPrice(
        token: token,
        productId: productId,
        previousRevisionId: previousId,
        reason: reason,
        context: context,
        idempotencyKey: _newPricingRequestKey(),
        costs: _providedCosts,
      );
      _applyPricingResponse(result);
      _priceSelectionSaved = false;
      return true;
    } catch (error) {
      _pricingError = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isPricingLoading = false;
      notifyListeners();
    }
  }

  void setCustomPriceDirect(double customPrice) {
    if (customPrice > 0) {
      _customPriceOverride = customPrice;
      _acceptedPrice = customPrice;
      _priceOverrideWarning = null;
      notifyListeners();
    }
  }

  Future<bool> applyCustomPriceOverride(
      double customPrice, String token) async {
    if (!customPrice.isFinite || customPrice <= 0) {
      _priceOverrideWarning = 'Enter a valid price greater than zero.';
      notifyListeners();
      return false;
    }
    final rechecked = await challengePricing(
      token: token,
      reason: 'market_difference',
      context:
          'Artisan proposed ${_currency} ${customPrice.toStringAsFixed(0)} and requested a fresh storefront comparison.',
    );
    if (rechecked) {
      _customPriceOverride = customPrice;
      _acceptedPrice = customPrice;
      _priceOverrideWarning = null;
      notifyListeners();
    }
    return rechecked;
  }

  Future<bool> savePriceSelection({
    required String token,
    required double price,
    required String source,
  }) async {
    final productId = _draftProductId;
    final revisionId = _pricingRevisionId;
    if (productId == null ||
        revisionId == null ||
        !price.isFinite ||
        price <= 0) {
      _pricingError = 'Enter a valid price and load a current recommendation.';
      notifyListeners();
      return false;
    }
    try {
      final result = await ApiService.selectProductPrice(
        token: token,
        productId: productId,
        revisionId: revisionId,
        price: price.roundToDouble(),
        selectionSource: source,
      );
      _applyPricingResponse(result);
      _acceptedPrice = (result['selected_price'] as num).toDouble();
      _priceSelectionSaved = true;
      _pricingError = null;
      notifyListeners();
      return true;
    } catch (error) {
      _pricingError = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void setArtisanCosts({
    required double materialCost,
    required double laborHours,
    required double hourlyRate,
    required double packagingCost,
    required double shippingCost,
  }) {
    _materialCost = materialCost;
    _laborHours = laborHours;
    _hourlyRate = hourlyRate;
    _packagingCost = packagingCost;
    _shippingCost = shippingCost;
    _hasArtisanCostInputs = [
      materialCost,
      laborHours,
      hourlyRate,
      packagingCost,
      shippingCost,
    ].any((value) => value > 0);
    notifyListeners();
  }

  void selectPrice(double price) {
    if (_acceptedPrice != price) {
      _priceSelectionSaved = false;
      _finalPriceConfirmed = false;
    }
    _acceptedPrice = price;
    _priceSelectionSaved = false;
    _customPriceOverride = null;
    _priceOverrideWarning = null;
    notifyListeners();
  }

  void setInventoryStock(int count) {
    _inventoryStock = count < 1 ? 1 : count;
    notifyListeners();
  }

  // ─── Save as Draft ─────────────────────────────────────────────────────────
  Future<bool> saveAsDraft(String token) async {
    if (_titleEn.trim().length < 2 ||
        _descriptionEn.trim().length < 10 ||
        !_englishDescriptionConfirmed ||
        _categorySlug.trim().isEmpty) {
      _publishError =
          'Add a product name, category, and description of at least 10 characters, then confirm the description.';
      notifyListeners();
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
      'dimensions': _dimensions,
      'weight_grams': _weightGrams,
      'additional_details': _parseAdditionalDetails(_additionalDetails),
      'care_instructions': _careInstructions,
      'price': _acceptedPrice,
      'stock': _inventoryStock,
      'status': 'draft',
      'category_slug': _categorySlug,
      'voice_transcript': _voiceTranscript,
      'voice_language': _voiceLanguage,
      'ai_generated': false,
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

    // Keep a recoverable local copy, but report server save only when the API
    // confirms that the draft row was actually created or updated.
    try {
      await OfflineStorageService.queueOfflineProduct(draftPayload);
      final res =
          await ApiService.createProduct(token: token, payload: draftPayload);
      if (res['id'] != null) {
        _draftProductId = res['id'] as int?;
      }
      if (_draftProductId == null) {
        throw Exception('The API did not return a saved draft ID.');
      }
    } catch (error) {
      _publishError = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }

    _isDraftSaved = true;
    notifyListeners();
    return true;
  }

  Future<bool> generateCatalogContent(String token,
      {bool retry = false}) async {
    if (_isCatalogBuilderProcessing) return false;
    if (_draftProductId == null) {
      _catalogBuilderError =
          'Save the draft before generating catalog content.';
      notifyListeners();
      return false;
    }
    _isCatalogBuilderProcessing = true;
    _catalogBuilderError = null;
    notifyListeners();
    try {
      var response = await ApiService.startCatalogBuilder(
        token: token,
        productId: _draftProductId!,
        retry: retry,
      );
      var state = response['catalog_builder'] is Map
          ? Map<String, dynamic>.from(response['catalog_builder'] as Map)
          : <String, dynamic>{};
      _catalogBuilderState = state['state']?.toString() ?? 'processing';

      for (var attempt = 0;
          _catalogBuilderState == 'processing' && attempt < 150;
          attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        response = await ApiService.getCatalogBuilderStatus(
          token: token,
          productId: _draftProductId!,
        );
        state = response['catalog_builder'] is Map
            ? Map<String, dynamic>.from(response['catalog_builder'] as Map)
            : <String, dynamic>{};
        _catalogBuilderState = state['state']?.toString() ?? 'processing';
        notifyListeners();
      }

      if (_catalogBuilderState == 'ready') {
        final output = state['output'] is Map
            ? Map<String, dynamic>.from(state['output'] as Map)
            : <String, dynamic>{};
        final title = output['title_en']?.toString().trim() ?? '';
        final description = output['description_en']?.toString().trim() ?? '';
        if (title.isEmpty || description.isEmpty) {
          throw Exception(
              'The catalog builder returned incomplete product content.');
        }
        _titleEn = title;
        _descriptionEn = description;
        if (output['seo_keywords'] is List) {
          _seoKeywords = (output['seo_keywords'] as List)
              .map((item) => item.toString())
              .toList();
        }
        _catalogBuilderOutput = output;
        _englishDescriptionConfirmed = false;
        _finalDescriptionConfirmed = false;
        _catalogBuilderError = null;
        _isDraftSaved = false;
        notifyListeners();
        return true;
      }
      if (_catalogBuilderState == 'failed') {
        _catalogBuilderError = state['error']?.toString() ??
            'The catalog builder could not process this product. Your draft is preserved.';
        return false;
      }
      _catalogBuilderError =
          'The catalog builder is still processing. Select Check status to continue.';
      return false;
    } catch (error) {
      _catalogBuilderError = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isCatalogBuilderProcessing = false;
      notifyListeners();
    }
  }

  // ─── Step 5: Publish to Website Live ───────────────────────────────────────
  Future<bool> publishProduct(String token) async {
    if (_isPublished) return true;
    if (_isPublishing) return false;
    if (_draftProductId == null) {
      _publishError = 'Save the product draft before publishing.';
      notifyListeners();
      return false;
    }
    if (!_finalDescriptionConfirmed || !_finalPriceConfirmed) {
      _publishError =
          'Review and confirm the English description and final price.';
      notifyListeners();
      return false;
    }
    if (!_acceptedPrice.isFinite || _acceptedPrice <= 0) {
      _publishError = 'Choose a valid final price before publishing.';
      notifyListeners();
      return false;
    }
    _isPublishing = true;
    _publishError = null;
    notifyListeners();

    int? apiPublishedProductId;
    try {
      if (!_priceSelectionSaved && _pricingRevisionId != null) {
        try {
          await savePriceSelection(
            token: token,
            price: _acceptedPrice,
            source: 'custom',
          );
        } catch (_) {}
      }
      final metadata = {
        'title_en': _titleEn.trim(),
        'description_en': _descriptionEn,
        'title_hi': _titleHi,
        'description_hi': _descriptionHi,
        'category_slug': _categorySlug,
        'material': _material,
        'technique': _technique,
        'dimensions': _dimensions,
        'weight_grams': _weightGrams,
        'additional_details': _parseAdditionalDetails(_additionalDetails),
        'care_instructions': _careInstructions,
        'stock': _inventoryStock,
        'voice_transcript': _voiceTranscript,
        'voice_language': _voiceLanguage,
        'seo_keywords': _seoKeywords,
        'price': _acceptedPrice,
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

      // Prepare image URLs for the product
      final productImages = <Map<String, dynamic>>[];
      if (selectedVariations.isNotEmpty) {
        for (var i = 0; i < selectedVariations.length; i++) {
          final url = selectedVariations[i]['image_url'] ?? selectedVariations[i]['url'];
          if (url != null) {
            productImages.add({'url': url, 'is_primary': i == 0, 'order_index': i});
          }
        }
      } else if (originalImageUrl != null) {
        productImages.add({'url': originalImageUrl, 'is_primary': true, 'order_index': 0});
      }

      // Update product directly with published status so it immediately goes live on KalaSathi website
      final publishPayload = Map<String, dynamic>.from(metadata);
      publishPayload['price'] = _acceptedPrice;
      publishPayload['status'] = 'published';
      if (productImages.isNotEmpty) {
        publishPayload['images'] = productImages;
      }

      Map<String, dynamic> res;
      try {
        if (_draftProductId != null) {
          res = await ApiService.updateProduct(
            token: token,
            productId: _draftProductId!,
            payload: publishPayload,
          );
        } else {
          res = await ApiService.createProduct(
            token: token,
            payload: publishPayload,
          );
        }
      } catch (updateErr) {
        // Fallback: If draft update failed (e.g. invalid draft ID or not found), create fresh product
        res = await ApiService.createProduct(
          token: token,
          payload: publishPayload,
        );
      }

      apiPublishedProductId = res['id'] as int? ?? _draftProductId!;
      try {
        await ApiService.updateProductAvailability(
          token: token,
          productId: apiPublishedProductId,
          status: 'published',
        );
      } catch (_) {}

      _isPublishing = false;
      _isPublished = true;
      _publishedProductId = apiPublishedProductId;
      notifyListeners();
      return true;
    } catch (e) {
      _isPublishing = false;
      final reason = e.toString().replaceFirst('Exception: ', '');
      _publishError = apiPublishedProductId == null
          ? reason
          : 'The API published product #$apiPublishedProductId, but public listing verification did not complete. Retry to verify it.';
      _publishedProductId = apiPublishedProductId;
      notifyListeners();
      return false;
    }
  }

  void resetWizard() {
    _currentStep = 0;
    _photos.clear();
    _isUploadingPhoto = false;
    _photoUploadError = null;
    _photoUploadIds.clear();
    _attachedPhotoUploadIds.clear();
    _photoFileNames.clear();
    _photoContentTypes.clear();
    _originalImageUrls.clear();
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
    _finalDescriptionConfirmed = false;
    _finalPriceConfirmed = false;
    _draftProductId = null;
    _publishError = null;
    _isCatalogBuilderProcessing = false;
    _catalogBuilderState = 'draft';
    _catalogBuilderError = null;
    _catalogBuilderOutput = {};
    _inventoryStock = 5;
    _titleEn = "";
    _titleHi = "";
    _shortDescriptionEn = "";
    _shortDescriptionHi = "";
    _descriptionEn = "";
    _descriptionHi = "";
    _material = "";
    _technique = "";
    _dimensions = "";
    _weightGrams = null;
    _additionalDetails = "";
    _careInstructions = "";
    _translations = [];
    _categories = [];
    _isLoadingCategories = false;
    _categoriesError = null;
    _missingFields = [];
    _missingInfoPrompt = null;
    _isDraftSaved = false;
    _materialCost = 0;
    _laborHours = 0;
    _hourlyRate = 0;
    _packagingCost = 0;
    _shippingCost = 0;
    _platformFeePercent = 0;
    _costFloor = 0;
    _suggestedPrice = 0;
    _premiumPrice = 0;
    _acceptedPrice = 0;
    _customPriceOverride = null;
    _priceOverrideWarning = null;
    _comparableProducts = [];
    _hasArtisanCostInputs = false;
    _isPricingLoading = false;
    _priceSelectionSaved = false;
    _currency = 'INR';
    _pricingConfidence = 'none';
    _requiresPricingReview = true;
    _pricingRevisionId = null;
    _pricingVersion = 0;
    _priceRangeMin = null;
    _priceRangeMax = null;
    _pricingError = null;
    _previousPricingRecommendation = null;
    _pricingBasis = 'storefront_comparables';
    _statusLabel = 'No storefront evidence loaded';
    _costBreakdown = {};
    _influencingFactors = [];
    _priceExplanation = '';
    _isPublished = false;
    _isPublishing = false;
    notifyListeners();
  }
}
