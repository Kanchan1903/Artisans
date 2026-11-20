import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/services/api_service.dart';
import 'package:kalasathi_mobile/services/voice_guidance_service.dart';
import 'package:kalasathi_mobile/theme/app_theme.dart';
import 'package:kalasathi_mobile/widgets/voice_help_fab.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final prods = await ApiService.getMyProducts(auth.authToken ?? "mock_token");
    if (mounted) {
      setState(() {
        _products = prods;
        _isLoading = false;
      });
    }
  }

  /// Cleanly resolves image URL, translating local development hosts to reachable production endpoints
  String? _resolveImageUrl(Map<String, dynamic> prod) {
    String? rawUrl;

    if (prod['images'] != null && prod['images'] is List && (prod['images'] as List).isNotEmpty) {
      final first = (prod['images'] as List)[0];
      if (first is Map) {
        rawUrl = (first['url'] ?? first['image_url'] ?? first['secure_url']) as String?;
      } else if (first is String && first.isNotEmpty) {
        rawUrl = first;
      }
    }

    if (rawUrl == null || rawUrl.isEmpty) {
      for (final key in ['image_url', 'url', 'photo_url', 'primary_image']) {
        if (prod[key] is String && (prod[key] as String).isNotEmpty) {
          rawUrl = prod[key] as String;
          break;
        }
      }
    }

    if (rawUrl == null || rawUrl.isEmpty) return null;

    // Fix localhost URLs for mobile devices
    if (rawUrl.contains('localhost:8000') || rawUrl.contains('127.0.0.1:8000')) {
      rawUrl = rawUrl
          .replaceFirst('http://localhost:8000', 'https://kalasathi-api.onrender.com')
          .replaceFirst('http://127.0.0.1:8000', 'https://kalasathi-api.onrender.com');
    } else if (rawUrl.startsWith('/uploads')) {
      rawUrl = 'https://kalasathi-api.onrender.com$rawUrl';
    }

    return rawUrl;
  }

  /// Intelligently select a distinct high-resolution craft asset so products never look identical
  String _getFallbackAsset(Map<String, dynamic> prod, int index) {
    final title = (prod['title_en'] ?? prod['title'] ?? prod['title_hi'] ?? prod['title_mr'] ?? '').toString().toLowerCase();
    final cat = (prod['category_slug'] ?? prod['category']?['slug'] ?? prod['category']?['name'] ?? '').toString().toLowerCase();

    if (title.contains('jewel') ||
        title.contains('necklace') ||
        title.contains('ring') ||
        title.contains('earring') ||
        title.contains('cover') ||
        title.contains('mobile') ||
        title.contains('watch') ||
        title.contains('belt') ||
        cat.contains('jewel') ||
        cat.contains('fashion')) {
      return 'assets/images/prod_jewelry.jpg';
    }

    if (title.contains('wood') ||
        title.contains('elephant') ||
        title.contains('carv') ||
        title.contains('furniture') ||
        title.contains('decor') ||
        cat.contains('wood') ||
        cat.contains('decor')) {
      return 'assets/images/prod_woodcraft.jpg';
    }

    if (title.contains('saree') ||
        title.contains('shawl') ||
        title.contains('cotton') ||
        title.contains('silk') ||
        title.contains('fabric') ||
        title.contains('handloom') ||
        title.contains('dress') ||
        cat.contains('handloom') ||
        cat.contains('textile')) {
      return 'assets/images/prod_handloom.jpg';
    }

    if (title.contains('paint') ||
        title.contains('art') ||
        title.contains('folk') ||
        cat.contains('art')) {
      return 'assets/images/prod_folkart.jpg';
    }

    if (title.contains('pot') ||
        title.contains('clay') ||
        title.contains('terracotta') ||
        title.contains('vase') ||
        cat.contains('pottery')) {
      return 'assets/images/prod_pottery.jpg';
    }

    // Diverse rotation so products never share the exact same fallback
    final distinctAssets = [
      'assets/images/prod_jewelry.jpg',
      'assets/images/prod_woodcraft.jpg',
      'assets/images/prod_handloom.jpg',
      'assets/images/prod_folkart.jpg',
      'assets/images/prod_pottery.jpg',
    ];
    final id = prod['id'] is num ? (prod['id'] as num).toInt() : index;
    return distinctAssets[id.abs() % distinctAssets.length];
  }

  Widget _buildProductThumbnail(Map<String, dynamic> prod, int index) {
    final imgUrl = _resolveImageUrl(prod);
    final fallbackAsset = _getFallbackAsset(prod, index);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 80,
        height: 80,
        color: const Color(0xFFF7E6D7),
        child: imgUrl != null && imgUrl.startsWith('http')
            ? Image.network(
                imgUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  fallbackAsset,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              )
            : Image.asset(
                fallbackAsset,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final lang = auth.selectedLanguage;
    final isHindi = lang == 'hi';
    final isMarathi = lang == 'mr';

    // Strictly localized strings
    final emptyText = isMarathi
        ? 'अद्याप कोणतेही उत्पादन जोडलेले नाही'
        : isHindi
            ? 'अभी तक कोई उत्पाद नहीं जोड़ा गया है'
            : 'No products added yet';

    final voiceHelpPrompt = isMarathi
        ? 'येथे तुमची सर्व उत्पादने दिसत आहेत. साठा वाढवण्यासाठी किंवा कमी करण्यासाठी + किंवा - दाबा.'
        : isHindi
            ? 'यहाँ आपके सभी उत्पाद दिख रहे हैं। स्टॉक बढ़ाने या घटाने के लिए + या - दबाएं।'
            : 'Here are all your products. Tap + or - to increase or decrease available stock.';

    final stockLabel = isMarathi
        ? 'साठा'
        : isHindi
            ? 'स्टॉक'
            : 'Stock';

    return Scaffold(
      backgroundColor: AppTheme.backgroundSand,
      appBar: AppBar(
        title: Text(l10n.translate('myProducts')),
      ),
      floatingActionButton: VoiceHelpFab(
        customMessage: voiceHelpPrompt,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.terracotta))
            : _products.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 60, color: Color(0xFFC84B31)),
                          const SizedBox(height: 16),
                          Text(
                            emptyText,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final prod = _products[index];

                      // Strictly localized product title
                      String title;
                      if (isMarathi) {
                        title = prod['title_mr'] ?? prod['title_hi'] ?? prod['title_en'] ?? prod['title'] ?? 'उत्पादन';
                      } else if (isHindi) {
                        title = prod['title_hi'] ?? prod['title_en'] ?? prod['title'] ?? 'उत्पाद';
                      } else {
                        title = prod['title_en'] ?? prod['title'] ?? prod['title_hi'] ?? 'Handcrafted Product';
                      }

                      final price = (prod['price'] as num?)?.toDouble() ?? 0.0;
                      int stock = (prod['stock'] as num?)?.toInt() ?? 0;
                      final isPublished = prod['status'] == 'published';
                      final isAvailable = isPublished && stock > 0;

                      // Localized status badge
                      final statusBadgeText = isAvailable
                          ? (isMarathi ? 'लाईव्ह' : isHindi ? 'लाइव' : 'Live')
                          : (isMarathi ? 'अनुपलब्ध' : isHindi ? 'अनुपलब्ध' : 'Unavailable');

                      // Localized action button
                      final actionButtonText = isPublished
                          ? (isMarathi ? 'लपवा' : isHindi ? 'छिपाएं' : 'Hide')
                          : (isMarathi ? 'लाईव्ह करा' : isHindi ? 'लाइव करें' : 'Make Live');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.borderWarm),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Image with intelligent distinct fallback
                            _buildProductThumbnail(prod, index),
                            const SizedBox(width: 14),

                            // Product Details & Responsive Controls
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15.5,
                                      color: Color(0xFF261C1A),
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Price
                                  Text(
                                    "₹ ${price.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                      color: AppTheme.maroonPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Stock Stepper Row
                                  Row(
                                    children: [
                                      Text(
                                        "$stockLabel: ",
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF6B5854),
                                        ),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                        iconSize: 22,
                                        icon: const Icon(Icons.remove_circle_outline_rounded, color: AppTheme.indigo),
                                        onPressed: () async {
                                          if (stock > 0) {
                                            final newStock = stock - 1;
                                            setState(() {
                                              prod['stock'] = newStock;
                                            });

                                            final voiceMsg = isMarathi
                                                ? "साठा बदलून $newStock झाला आहे."
                                                : isHindi
                                                    ? "स्टॉक बदलकर $newStock हो गया है।"
                                                    : "Stock updated to $newStock.";
                                            VoiceGuidanceService.speakPrompt(context, voiceMsg);

                                            if (auth.authToken != null && prod['id'] != null) {
                                              await ApiService.updateStock(
                                                token: auth.authToken!,
                                                productId: prod['id'],
                                                newStock: newStock,
                                              );
                                            }
                                          }
                                        },
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(
                                          "$stock",
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF261C1A)),
                                        ),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                        iconSize: 22,
                                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.maroonPrimary),
                                        onPressed: () async {
                                          final newStock = stock + 1;
                                          setState(() {
                                            prod['stock'] = newStock;
                                          });

                                          final voiceMsg = isMarathi
                                              ? "साठा वाढवून $newStock झाला आहे."
                                              : isHindi
                                                  ? "स्टॉक बढ़ाकर $newStock हो गया है।"
                                                  : "Stock updated to $newStock.";
                                          VoiceGuidanceService.speakPrompt(context, voiceMsg);

                                          if (auth.authToken != null && prod['id'] != null) {
                                            await ApiService.updateStock(
                                              token: auth.authToken!,
                                              productId: prod['id'],
                                              newStock: newStock,
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Status Badge and Action - Wrap prevents any pixel overflow
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    alignment: WrapAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          statusBadgeText,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isAvailable ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () async {
                                          final currentStatus = prod['status'] as String? ?? 'published';
                                          final newStatus = currentStatus == 'published' ? 'hidden' : 'published';
                                          setState(() {
                                            prod['status'] = newStatus;
                                          });

                                          if (auth.authToken != null && prod['id'] != null) {
                                            await ApiService.updateProductAvailability(
                                              token: auth.authToken!,
                                              productId: prod['id'],
                                              status: newStatus,
                                            );
                                          }

                                          if (mounted) {
                                            final snackText = isMarathi
                                                ? (newStatus == 'published'
                                                    ? 'उत्पादन आता वेबसाईटवर उपलब्ध आहे'
                                                    : 'उत्पादन वेबसाईटवरून लपवले आहे')
                                                : isHindi
                                                    ? (newStatus == 'published'
                                                        ? 'उत्पाद अब वेबसाइट पर लाइव है'
                                                        : 'उत्पाद स्टोरफ्रंट से छिपा दिया गया है')
                                                    : (newStatus == 'published'
                                                        ? 'Product is now live on KalaSathi'
                                                        : 'Product is now hidden from storefront');

                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(snackText),
                                                duration: const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          child: Text(
                                            actionButtonText,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.maroonPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
