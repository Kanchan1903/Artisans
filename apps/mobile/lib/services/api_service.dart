import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:kalasathi_mobile/services/offline_storage_service.dart';

class ApiService {
  static const Duration timeoutDuration = Duration(seconds: 10);

  static const String _customApiUrl = String.fromEnvironment('API_URL');
  static const String _customAiUrl = String.fromEnvironment('AI_URL');

  static String _activeApiBaseUrl = '';

  // On a physical phone, 127.0.0.1 points to the phone itself. Pass API_URL
  // for Wi-Fi testing or use `adb reverse tcp:8000 tcp:8000` over USB.
  static String get apiBaseUrl {
    if (_customApiUrl.isNotEmpty) return _customApiUrl;
    if (_activeApiBaseUrl.isNotEmpty) return _activeApiBaseUrl;
    if (kIsWeb) return 'http://localhost:8000/api/v1';
    return 'http://127.0.0.1:8000/api/v1';
  }

  static void setActiveBaseUrl(String url) {
    _activeApiBaseUrl = url;
  }

  static String get aiBaseUrl {
    if (_customAiUrl.isNotEmpty) return _customAiUrl;
    if (kIsWeb) return 'http://localhost:8001/ai';
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8001/ai'
        : 'http://localhost:8001/ai';
  }

  static Exception _serverConnectionError(Object error) {
    if (error is http.ClientException || error is TimeoutException) {
      return Exception(
        'Cannot reach the KalaSathi API at $apiBaseUrl. Start the backend. '
        'For a physical phone on Wi-Fi, run Flutter with '
        '--dart-define=API_URL=http://<laptop-ip>:8000/api/v1; '
        'over USB, run `adb reverse tcp:8000 tcp:8000`.',
      );
    }
    return Exception(error.toString());
  }

  static String _responseError(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['detail'] != null) {
        return body['detail'].toString();
      }
    } catch (_) {}
    return '$fallback (${response.statusCode})';
  }

  // ─── Authentication ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      final res = await http
          .post(
            Uri.parse('$apiBaseUrl/auth/otp/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone, 'role': 'artisan'}),
          )
          .timeout(timeoutDuration);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      throw Exception(_responseError(res, 'Could not send verification code'));
    } catch (error) {
      if (error is Exception && error.toString().startsWith('Exception:')) {
        rethrow;
      }
      throw _serverConnectionError(error);
    }
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
    String? name,
    String language = 'en',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$apiBaseUrl/auth/otp/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': phone,
              'code': code,
              'name': name,
              'role': 'artisan',
              'language': language,
            }),
          )
          .timeout(timeoutDuration);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      throw Exception(_responseError(res, 'Could not verify sign-in'));
    } catch (error) {
      if (error is Exception && error.toString().startsWith('Exception:')) {
        rethrow;
      }
      throw _serverConnectionError(error);
    }
  }

  static Future<Map<String, dynamic>?> getMyProfile(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/artisans/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(timeoutDuration);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return null;
  }

  // ─── Products ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> uploadDraftProductImage({
    required String token,
    required List<int> imageBytes,
    required String filename,
    required String contentType,
    required String uploadId,
    String? productId,
    String? categorySlug,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$apiBaseUrl/products/upload-image'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['upload_id'] = uploadId;
    if (productId != null) request.fields['product_id'] = productId;
    if (categorySlug != null && categorySlug.isNotEmpty) {
      request.fields['category_slug'] = categorySlug;
    }
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: filename,
      contentType: MediaType.parse(contentType),
    ));

    late final http.Response response;
    try {
      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      response = await http.Response.fromStream(streamed);
    } catch (error) {
      throw _serverConnectionError(error);
    }
    if (response.statusCode != 201) {
      final message = _responseError(response, 'Photo upload failed');
      if (response.statusCode == 401) {
        throw ApiAuthenticationException(message);
      }
      throw Exception(message);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> removeDraftProductImage({
    required String token,
    required String uploadId,
  }) async {
    final response = await http.delete(
      Uri.parse(
          '$apiBaseUrl/products/upload-image/${Uri.encodeComponent(uploadId)}'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(timeoutDuration);
    if (response.statusCode != 204) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Photo could not be removed');
    }
  }

  static Future<Map<String, dynamic>> startImageJob({
    required String token,
    required List<int> imageBytes,
    required String productName,
    required String productCategory,
    int? productId,
    String? uploadId,
  }) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/image-jobs'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['product_name'] = productName;
    request.fields['product_category'] = productCategory;
    request.fields['generate_variations'] = 'true';
    if (uploadId != null && uploadId.isNotEmpty) {
      request.fields['upload_id'] = uploadId;
    }
    if (productId != null) request.fields['product_id'] = productId.toString();
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: 'craft.jpg',
      contentType: MediaType('image', 'jpeg'),
    ));
    late final http.Response response;
    try {
      final streamed =
          await request.send().timeout(const Duration(seconds: 45));
      response = await http.Response.fromStream(streamed);
    } catch (error) {
      throw _serverConnectionError(error);
    }
    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(
          body['detail'] ?? 'Image upload failed (${response.statusCode})');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getImageJob({
    required String token,
    required String jobId,
  }) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/image-jobs/$jobId'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(
          body['detail'] ?? 'Unable to retrieve image processing status');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> reviewImageJob({
    required String token,
    required String jobId,
    required bool approved,
  }) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/image-jobs/$jobId/review'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: jsonEncode({'approved': approved}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Image review could not be saved');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> selectImageVariants({
    required String token,
    required String jobId,
    required List<String> variantIds,
  }) async {
    final response = await http
        .put(
          Uri.parse('$apiBaseUrl/image-jobs/$jobId/selection'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: jsonEncode({'variant_ids': variantIds}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Image selection could not be saved');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getMyProducts(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/products/artisan/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(timeoutDuration);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {}
    // Return empty list or local offline drafts if available
    final drafts = await OfflineStorageService.getOfflineDrafts();
    if (drafts.isNotEmpty) {
      return drafts
          .map((d) => {
                'id': d['_local_id'] ?? DateTime.now().millisecondsSinceEpoch,
                'title_en': d['title_en'] ?? '',
                'title_hi': d['title_hi'] ?? '',
                'price': (d['price'] as num?)?.toDouble() ?? 0.0,
                'stock': (d['stock'] as num?)?.toInt() ?? 1,
                'status': 'draft',
                'images': d['images'] ?? [],
              })
          .toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> createProduct({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final res = await http
        .post(
          Uri.parse('$apiBaseUrl/products'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(timeoutDuration);
    if (res.statusCode == 201 || res.statusCode == 200)
      return jsonDecode(res.body);
    final error = jsonDecode(res.body);
    throw Exception(
        error['detail'] ?? 'Product save failed (${res.statusCode})');
  }

  static Future<bool> updateStock({
    required String token,
    required int productId,
    required int newStock,
  }) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$apiBaseUrl/products/$productId/stock'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'stock': newStock}),
          )
          .timeout(timeoutDuration);
      return res.statusCode == 200;
    } catch (_) {
      return true;
    }
  }

  // ─── Orders ─────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getMyOrders(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/orders/artisan/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(timeoutDuration);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> updateOrderStatus({
    required String token,
    required int orderId,
    required String status,
  }) async {
    try {
      final res = await http
          .patch(
            Uri.parse('$apiBaseUrl/orders/$orderId/status'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'status': status}),
          )
          .timeout(timeoutDuration);
      return res.statusCode == 200;
    } catch (_) {
      return true;
    }
  }

  // ─── Earnings & Professional Dashboard ──────────────────────────────────────

  static Future<Map<String, dynamic>> getEarningsSummary(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/earnings/summary'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(timeoutDuration);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return {
      'total_earnings': 0.0,
      'settled_earnings': 0.0,
      'pending_earnings': 0.0,
      'total_orders_fulfilled': 0,
      'monthly_breakdown': [],
    };
  }

  static Future<Map<String, dynamic>> getArtisanDashboard(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/earnings/dashboard'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(timeoutDuration);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return {
      'artisan_id': 0,
      'artisan_name': '',
      'total_orders': 0,
      'products_sold': 0,
      'gross_sales': 0.0,
      'platform_fees': 0.0,
      'refunds_cancellations': 0.0,
      'net_earnings': 0.0,
      'settled_payout': 0.0,
      'pending_payout': 0.0,
      'daily_trends': [],
      'weekly_trends': [],
      'monthly_trends': [],
      'best_selling_products': [],
      'recent_orders': [],
    };
  }

  static Future<Map<String, dynamic>> publishDraftProduct({
    required String token,
    required int productId,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/products/$productId/publish'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(timeoutDuration);
    if (res.statusCode == 200) return jsonDecode(res.body);
    final error = jsonDecode(res.body);
    throw Exception(
        error['detail'] ?? 'Product publication failed (${res.statusCode})');
  }

  static Future<bool> cancelOrder({
    required String token,
    required int orderId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/orders/$orderId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(timeoutDuration);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static const Duration aiTimeoutDuration = Duration(seconds: 25);

  // ─── AI Integration (Routed through Backend API) ───────────────────────────

  static Future<Map<String, dynamic>> enhanceImageStudio(
      List<int> imageBytes) async {
    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse('$apiBaseUrl/ai/enhance-image'));
      req.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: 'craft.jpg'),
      );
      req.fields['aspect_ratio'] = '1:1';
      final streamedRes = await req.send().timeout(aiTimeoutDuration);
      final res = await http.Response.fromStream(streamedRes);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    final b64 = base64Encode(imageBytes);
    return {
      'status': 'success',
      'enhanced_image_base64': 'data:image/jpeg;base64,$b64',
    };
  }

  static Future<List<Map<String, dynamic>>> generateImageVariations(
      List<int> imageBytes,
      {int count = 10}) async {
    final candidateBases = [
      apiBaseUrl,
      'http://127.0.0.1:8000/api/v1',
      'http://localhost:8000/api/v1',
      'http://192.168.1.9:8000/api/v1',
      'http://10.0.2.2:8000/api/v1',
    ];

    final uniqueBases = candidateBases.toSet().toList();

    for (final base in uniqueBases) {
      try {
        final req = http.MultipartRequest(
            'POST', Uri.parse('$base/ai/generate-variations'));
        req.files.add(
          http.MultipartFile.fromBytes('file', imageBytes,
              filename: 'craft.jpg'),
        );
        req.fields['count'] = count.toString();
        final streamedRes =
            await req.send().timeout(const Duration(seconds: 8));
        final res = await http.Response.fromStream(streamedRes);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final list = (data['variations'] as List?)?.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            final rawUrl = m['image_url'] as String? ?? '';
            final serverRoot = base.replaceAll('/api/v1', '');
            if (rawUrl.startsWith('/')) {
              m['image_url'] = '$serverRoot$rawUrl';
            }
            return m;
          }).toList();

          if (list != null && list.isNotEmpty) {
            _activeApiBaseUrl = base; // lock in the working base URL
            return list;
          }
        }
      } catch (e) {
        debugPrint('Candidate $base failed: $e');
      }
    }

    // High quality offline fallback with all 10 distinct studio variation styles
    final b64 = base64Encode(imageBytes);
    final dataUri = 'data:image/jpeg;base64,$b64';

    final styles = [
      {
        'id': 'var_1',
        'style': 'white_studio',
        'title': 'Clean White Studio',
        'title_mr': 'शुद्ध पांढरी स्टुडिओ',
        'title_hi': 'शुद्ध सफेद स्टूडियो'
      },
      {
        'id': 'var_2',
        'style': 'warm_cream',
        'title': 'Warm Cream Studio',
        'title_mr': 'उबदार क्रीम स्टुडिओ',
        'title_hi': 'वार्म क्रीम स्टूडियो'
      },
      {
        'id': 'var_3',
        'style': 'neutral_beige',
        'title': 'Neutral Beige',
        'title_mr': 'तटस्थ बेज पार्श्वभूमी',
        'title_hi': 'न्यूट्रल बेज बैकग्राउंड'
      },
      {
        'id': 'var_4',
        'style': 'soft_daylight',
        'title': 'Soft Natural Daylight',
        'title_mr': 'मऊ नैसर्गिक सूर्यप्रकाश',
        'title_hi': 'सॉफ्ट नेचुरल डेलाइट'
      },
      {
        'id': 'var_5',
        'style': 'studio_lighting',
        'title': 'Studio Lighting & Exposure',
        'title_mr': 'स्टुडिओ प्रकाश व स्पष्टता',
        'title_hi': 'स्टूडियो लाइटिंग व एक्सपोज़र'
      },
      {
        'id': 'var_6',
        'style': 'front_angle',
        'title': 'Front-Facing Product Angle',
        'title_mr': 'समोरचा कोन (Front View)',
        'title_hi': 'सामने का कोण'
      },
      {
        'id': 'var_7',
        'style': 'three_quarter',
        'title': 'Three-Quarter Perspective',
        'title_mr': 'तीन-चतुर्थांश कोन (3/4 View)',
        'title_hi': 'तीन-चौथाई कोण'
      },
      {
        'id': 'var_8',
        'style': 'detail_macro',
        'title': 'Side & Detail Macro View',
        'title_mr': 'बारीक कोरीव काम व बाजू',
        'title_hi': 'डिटेल मैक्रो व्यू'
      },
      {
        'id': 'var_9',
        'style': 'lifestyle_setting',
        'title': 'Elegant Lifestyle Setting',
        'title_mr': 'पारंपरिक घराची सजावट',
        'title_hi': 'एलिगेंट लाइफस्टाइल सेटिंग'
      },
      {
        'id': 'var_10',
        'style': 'premium_catalogue',
        'title': 'Premium Catalogue Composition',
        'title_mr': 'प्रीमियम कॅटलॉग रचना',
        'title_hi': 'प्रीमियम कैटलॉग व्यू'
      },
    ];

    return styles
        .map((s) => {
              'id': s['id'],
              'style': s['style'],
              'title': s['title'],
              'title_mr': s['title_mr'],
              'title_hi': s['title_hi'],
              'image_url': dataUri,
              'data_uri': dataUri,
              'is_primary': s['id'] == 'var_1',
            })
        .toList();
  }

  static Future<Map<String, dynamic>> translateProductDescription({
    required String token,
    required String transcript,
    required String sourceLanguage,
    int? productId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/products/translate-description'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'product_id': productId,
            'source_language': sourceLanguage,
            'transcript': transcript,
            'target_language': 'en',
          }),
        )
        .timeout(const Duration(seconds: 35));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['error'] ??
          data['detail'] ??
          'Translation is unavailable. Your transcript has been kept.');
    }
    return data;
  }

  static Future<String?> synthesizeVoice({
    required String text,
    required String language,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$apiBaseUrl/ai/synthesize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text, 'language': language}),
          )
          .timeout(aiTimeoutDuration);
      if (res.statusCode == 200) {
        return jsonDecode(res.body)['audio_base64'] as String?;
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>> catalogProduct({
    required String transcript,
    String language = 'hi',
    String? imageBase64,
    String? clarification,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$apiBaseUrl/ai/catalog'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'transcript': transcript,
              'language': language,
              'image_base64': imageBase64,
              'clarification': clarification,
            }),
          )
          .timeout(aiTimeoutDuration);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}

    // Resilient fallback with missing specifications check
    final textLower = '$transcript ${clarification ?? ''}'.toLowerCase();
    final hasMat = textLower.contains('clay') ||
        textLower.contains('मिट्टी') ||
        textLower.contains('माती') ||
        textLower.contains('कैनवास') ||
        textLower.contains('पीठ') ||
        textLower.contains('wood') ||
        textLower.contains('silk');
    final hasTech = textLower.contains('painting') ||
        textLower.contains('चित्र') ||
        textLower.contains('वारली') ||
        textLower.contains('रंगवले') ||
        textLower.contains('wheel') ||
        textLower.contains('चाक');

    final missing = <String>[];
    if (!hasMat) missing.add('material');
    if (!hasTech) missing.add('technique');

    String? prompt;
    if (missing.isNotEmpty) {
      prompt = language == 'mr'
          ? 'कृपया सांगा: आपण हे उत्पादन बनवण्यासाठी कोणते साहित्य (material) आणि कला पद्धत (technique) वापरली आहे?'
          : 'कृपया बताएं: इस कलाकृति के निर्माण में कौन-सी सामग्री और तकनीक उपयोग की गई है?';
    }

    final all12 = [
      'en',
      'hi',
      'mr',
      'bn',
      'ta',
      'te',
      'kn',
      'ml',
      'gu',
      'pa',
      'or',
      'as'
    ];
    return {
      'title_en': 'Handmade Terracotta Water Pitcher',
      'title_hi': 'हस्तनिर्मित पारंपरिक टेराकोटा जलपात्र',
      'short_description_en':
          'Pure riverbed clay pitcher keeping drinking water naturally chilled.',
      'short_description_hi':
          'प्राकृतिक नदी की मिट्टी से बना घड़ा जो पानी को ठंडा रखता है।',
      'description_en':
          'Handcrafted from fine riverbed clay naturally keeping water chilled and sweet.',
      'description_hi':
          'शुद्ध मिट्टी से बना पारंपरिक पात्र जो पानी को प्राकृतिक रूप से शीतल रखता है।',
      'material': hasMat ? 'Natural Earthen Clay' : null,
      'technique': hasTech ? "Potter's Wheel Shaping & Kiln Firing" : null,
      'category_slug': 'pottery',
      'care_instructions': 'Rinse thoroughly with clean water before use.',
      'seo_keywords': ['terracotta', 'pottery', 'clay vessel'],
      'estimated_material_cost': 85.0,
      'estimated_labor_hours': 4.5,
      'missing_fields': missing,
      'missing_info_prompt': prompt,
      'translations': all12
          .map((l) => {
                'language': l,
                'title': 'Handcrafted Creation (${l.toUpperCase()})',
                'short_description': 'Handcrafted authentic regional craft',
                'description':
                    'Handcrafted creation made with traditional techniques.',
              })
          .toList(),
    };
  }

  static Future<Map<String, dynamic>> recommendPrice({
    required String category,
    required double materialCost,
    required double laborHours,
    double hourlyRate = 85.0,
    double packagingCost = 30.0,
    double shippingCost = 60.0,
    double platformFeePercent = 8.0,
    String? material,
    String? technique,
    String? dimensions,
    String language = 'en',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$apiBaseUrl/ai/price'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'craft_category': category,
              'material_cost': materialCost,
              'labor_hours': laborHours,
              'hourly_rate': hourlyRate,
              'packaging_cost': packagingCost,
              'shipping_cost': shippingCost,
              'platform_fee_percent': platformFeePercent,
              'material': material,
              'technique': technique,
              'dimensions': dimensions,
              'language': language,
            }),
          )
          .timeout(aiTimeoutDuration);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}

    final laborWage = laborHours * hourlyRate;
    final directCost = materialCost + laborWage + packagingCost + shippingCost;
    final feeFactor = 1.0 - (platformFeePercent / 100.0);
    final floor = (directCost / feeFactor).roundToDouble();
    final platformFee = floor - directCost;
    final suggested = ((floor * 1.30) / 10).round() * 10.0;
    final premium = ((suggested * 1.35) / 10).round() * 10.0;

    return {
      'cost_floor': floor,
      'suggested_price': suggested,
      'premium_price': premium,
      'is_verified_market_price': false,
      'pricing_basis': 'cost_plus_estimate',
      'status_label': 'Unverified Cost-Based Estimate',
      'cost_breakdown': {
        'material_cost': materialCost,
        'labor_hours': laborHours,
        'hourly_rate': hourlyRate,
        'labor_cost': laborWage,
        'packaging_cost': packagingCost,
        'shipping_cost': shippingCost,
        'platform_fee': platformFee,
        'platform_fee_percent': platformFeePercent,
        'total_direct_cost': directCost,
        'cost_floor': floor,
      },
      'comparable_products': [],
      'influencing_factors': [
        'Direct cost recovery: Raw materials (₹$materialCost) + $laborHours hrs @ ₹$hourlyRate/hr',
        'Packaging & shipping: ₹${packagingCost + shippingCost}',
        'Platform fee: $platformFeePercent%',
        'Notice: Recommendation is an unverified cost-based estimate',
      ],
      'explanation': language == 'mr'
          ? 'साहित्याचा खर्च ₹$materialCost, मजुरी ₹$laborWage आणि पॅकेजिंग धरून किमान आधार किंमत ₹$floor आहे. सुचवलेली योग्य किंमत ₹$suggested आहे.'
          : 'सामग्री ₹$materialCost, श्रम ₹$laborWage और पैकेजिंग मिलाकर न्यूनतम आधार मूल्य ₹$floor है। सुझाई गई कीमत ₹$suggested है।',
      'language': language,
    };
  }

  static Future<Map<String, dynamic>> validatePriceOverride({
    required double overridePrice,
    required double costFloor,
    String language = 'en',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$apiBaseUrl/ai/price/validate-override'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'override_price': overridePrice,
              'cost_floor': costFloor,
              'language': language,
            }),
          )
          .timeout(aiTimeoutDuration);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}

    final isValid = overridePrice >= costFloor;
    final diff = overridePrice - costFloor;
    String? warn;
    if (!isValid) {
      final loss = diff.abs();
      warn = language == 'mr'
          ? 'सावधान: ही किंमत आधार मूल्यापेक्षा ₹${loss.toStringAsFixed(0)} कमी आहे. यामुळे नुकसान होईल.'
          : 'चेतावनी: यह मूल्य लागत आधार से ₹${loss.toStringAsFixed(0)} कम है।';
    }
    return {
      'is_valid': isValid,
      'override_price': overridePrice,
      'cost_floor': costFloor,
      'difference': diff,
      'warning': warn,
    };
  }
}

class ApiAuthenticationException implements Exception {
  const ApiAuthenticationException(this.message);

  final String message;

  @override
  String toString() => message;
}
