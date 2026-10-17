import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:kalasathi_mobile/services/api_service.dart';
import 'package:kalasathi_mobile/services/offline_storage_service.dart';

class ProductWizardProvider extends ChangeNotifier {
  int _currentStep = 0;
  bool _isProcessingAI = false;

  // Step 1: Photos
  final List<Uint8List> _photos = [];
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
  List<Uint8List> get photos => _photos;
  String get cameraGuidance => _cameraGuidance;
  String? get enhancedImageBase64 => _enhancedImageBase64;
  List<Map<String, dynamic>> get imageVariations => _imageVariations;
  Set<String> get selectedVariationIds => _selectedVariationIds;
  List<Map<String, dynamic>> get selectedVariations =>
      _imageVariations.where((v) => _selectedVariationIds.contains(v['id'])).toList();
  String get voiceTranscript => _voiceTranscript;
  bool get isRecording => _isRecording;
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

  // ─── AI Studio Step ────────────────────────────────────────────────────────
  Future<void> processPhotoInAIStudio() async {
    if (_photos.isEmpty) return;
    _isProcessingAI = true;
    notifyListeners();

    try {
      final vars = await ApiService.generateImageVariations(_photos[0], count: 12);
      _imageVariations = vars;
      if (_imageVariations.isNotEmpty) {
        // Select top 3 variations by default (satisfying 3-4 selected images)
        _selectedVariationIds = _imageVariations.take(3).map((v) => v['id'] as String).toSet();
        _enhancedImageBase64 = _imageVariations.first['image_url'] as String?;
      }
    } catch (_) {
      final b64 = base64Encode(_photos[0]);
      _enhancedImageBase64 = 'data:image/jpeg;base64,$b64';
      _imageVariations = [
        {
          'id': 'var_1',
          'style': 'white_studio',
          'title': 'Pristine White Studio',
          'title_mr': 'शुद्ध पांढरी स्टुडिओ',
          'image_url': _enhancedImageBase64,
          'is_primary': true
        }
      ];
      _selectedVariationIds = {'var_1'};
    }

    _isProcessingAI = false;
    notifyListeners();
  }

  void toggleVariationSelection(String variationId) {
    if (_selectedVariationIds.contains(variationId)) {
      if (_selectedVariationIds.length > 1) {
        _selectedVariationIds.remove(variationId);
      }
    } else {
      if (_selectedVariationIds.length < 4) {
        _selectedVariationIds.add(variationId);
      }
    }
    notifyListeners();
  }

  // ─── Voice Recording & Catalog Step ────────────────────────────────────────
  void toggleRecording() {
    _isRecording = !_isRecording;
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

  Future<void> processVoiceNote(String language, {String? clarification}) async {
    _isProcessingAI = true;
    notifyListeners();

    // 1. Transcribe voice note if not already provided
    if (_voiceTranscript.isEmpty) {
      _voiceTranscript = await ApiService.transcribeVoice(language: language);
    }

    // 2. Generate structured catalog + 12-language translations with strict missing specs detection
    final catalog = await ApiService.catalogProduct(
      transcript: _voiceTranscript,
      language: language,
      imageBase64: _enhancedImageBase64,
      clarification: clarification,
    );

    _titleEn = catalog['title_en'] ?? 'Handmade Craft';
    _titleHi = catalog['title_hi'] ?? 'हस्तशिल्प';
    _shortDescriptionEn = catalog['short_description_en'] ?? '';
    _shortDescriptionHi = catalog['short_description_hi'] ?? '';
    _descriptionEn = catalog['description_en'] ?? '';
    _descriptionHi = catalog['description_hi'] ?? '';
    _material = catalog['material'] ?? '';
    _technique = catalog['technique'] ?? '';
    _categorySlug = catalog['category_slug'] ?? 'pottery';
    _careInstructions = catalog['care_instructions'] ?? 'Handle with care';
    _seoKeywords = (catalog['seo_keywords'] as List?)?.map((e) => e.toString()).toList() ?? [];

    if (catalog['translations'] != null) {
      _translations = (catalog['translations'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }

    _missingFields = (catalog['missing_fields'] as List?)?.map((e) => e.toString()).toList() ?? [];
    _missingInfoPrompt = catalog['missing_info_prompt'] as String?;

    // Seed costs from catalog extraction
    _materialCost = (catalog['estimated_material_cost'] as num?)?.toDouble() ?? 85.0;
    _laborHours = (catalog['estimated_labor_hours'] as num?)?.toDouble() ?? 4.5;

    // 3. Compute fair pricing tiers with breakdown & comparables
    await recalculatePricing(language: language);

    _isProcessingAI = false;
    notifyListeners();
  }

  Future<void> resolveMissingSpecification({
    required String field,
    required String value,
    required String language,
  }) async {
    if (field == 'material') _material = value;
    if (field == 'technique') _technique = value;
    _missingFields.remove(field);
    if (_missingFields.isEmpty) {
      _missingInfoPrompt = null;
    }

    // Re-catalog with updated clarification
    await processVoiceNote(language, clarification: '$field: $value');
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
    _statusLabel = pricing['status_label'] as String? ?? 'Unverified Cost-Based Estimate';

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

  Future<void> applyCustomPriceOverride(double customPrice, String language) async {
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
    final selectedImgs = selectedVariations.isNotEmpty
        ? selectedVariations.asMap().entries.map((entry) => {
            'url': entry.value['image_url'],
            'is_primary': entry.key == 0,
            'order_index': entry.key,
          }).toList()
        : [
            {
              'url': _enhancedImageBase64 ?? 'https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=600',
              'is_primary': true,
              'order_index': 0,
            }
          ];

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
      'voice_transcript': _voiceTranscript,
      'ai_generated': true,
      'draft_product_id': _draftProductId,
      'idempotency_key': _draftProductId != null ? 'draft_$_draftProductId' : null,
      'images': selectedImgs,
      'translations': _translations.isNotEmpty
          ? _translations
          : [
              {'language': 'en', 'title': _titleEn, 'description': _descriptionEn},
              {'language': 'hi', 'title': _titleHi, 'description': _descriptionHi},
            ],
    };

    // Save to local SQLite / offline queue
    await OfflineStorageService.queueOfflineProduct(draftPayload);

    // Save to backend API
    try {
      final res = await ApiService.createProduct(token: token, payload: draftPayload);
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
    _isPublishing = true;
    _publishError = null;
    notifyListeners();

    try {
      final selectedImgs = selectedVariations.isNotEmpty
          ? selectedVariations.asMap().entries.map((entry) => {
              'url': entry.value['image_url'],
              'is_primary': entry.key == 0,
              'order_index': entry.key,
            }).toList()
          : [
              {
                'url': _enhancedImageBase64 ?? 'https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=600',
                'is_primary': true,
                'order_index': 0,
              }
            ];

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
        'voice_transcript': _voiceTranscript,
        'ai_generated': true,
        'draft_product_id': _draftProductId,
        'idempotency_key': 'pub_${_draftProductId ?? _voiceTranscript.hashCode}_${_acceptedPrice.toInt()}',
        'images': selectedImgs,
        'translations': _translations.isNotEmpty
            ? _translations
            : [
                {'language': 'en', 'title': _titleEn, 'description': _descriptionEn},
                {'language': 'hi', 'title': _titleHi, 'description': _descriptionHi},
              ],
      };

      final res = await ApiService.createProduct(token: token, payload: payload);
      _isPublishing = false;
      _isPublished = true;
      _publishedProductId = res['id'] as int?;
      notifyListeners();
      return true;
    } catch (e) {
      _isPublishing = false;
      _publishError = "प्रकाशन अयशस्वी झाले. कृपया इंटरनेट तपासून पुन्हा प्रयत्न करा.";
      notifyListeners();
      return false;
    }
  }

  void resetWizard() {
    _currentStep = 0;
    _photos.clear();
    _enhancedImageBase64 = null;
    _imageVariations.clear();
    _selectedVariationIds.clear();
    _voiceTranscript = "";
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
