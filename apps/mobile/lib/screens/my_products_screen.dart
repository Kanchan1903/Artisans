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
    setState(() {
      _products = prods;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundSand,
      appBar: AppBar(
        title: Text(l10n.translate('myProducts')),
      ),
      floatingActionButton: VoiceHelpFab(
        customMessage: "येथे तुमची सर्व उत्पादने दिसत आहेत. साठा वाढवण्यासाठी किंवा कमी करण्यासाठी + किंवा - दाबा.",
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
                            l10n.translate('noProductsYet'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final prod = _products[index];
                      final title = prod['title_${Provider.of<AuthProvider>(context, listen: false).selectedLanguage}'] ??
                          prod['title_hi'] ??
                          prod['title_en'] ??
                          'उत्पादन';
                      final price = (prod['price'] as num?)?.toDouble() ?? 0.0;
                      int stock = (prod['stock'] as num?)?.toInt() ?? 1;
                      final imgUrl = prod['images'] != null && (prod['images'] as List).isNotEmpty
                          ? prod['images'][0]['url'] as String?
                          : null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.borderWarm),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: imgUrl != null && imgUrl.startsWith('http')
                                  ? Image.network(
                                      imgUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Image.asset(
                                        'assets/images/prod_pottery.jpg',
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/images/prod_pottery.jpg',
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "₹ ${price.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: AppTheme.terracotta,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Stock Counter (+ / -) with voice confirmation
                                  Row(
                                    children: [
                                      Text(
                                        "${l10n.translate('stock')}: ",
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline_rounded, color: AppTheme.indigo),
                                        onPressed: () async {
                                          if (stock > 0) {
                                            final newStock = stock - 1;
                                            setState(() {
                                              prod['stock'] = newStock;
                                            });
                                            VoiceGuidanceService.speakPrompt(context, "साठा बदलून $newStock झाला आहे.");
                                            final auth = Provider.of<AuthProvider>(context, listen: false);
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
                                      Text(
                                        "$stock",
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.terracotta),
                                        onPressed: () async {
                                          final newStock = stock + 1;
                                          setState(() {
                                            prod['stock'] = newStock;
                                          });
                                          VoiceGuidanceService.speakPrompt(context, "साठा वाढवून $newStock झाला आहे.");
                                          final auth = Provider.of<AuthProvider>(context, listen: false);
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
                                  // Product Availability / Status Toggle
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: prod['status'] == 'published' && stock > 0
                                              ? const Color(0xFFDCFCE7)
                                              : const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          prod['status'] == 'published' && stock > 0
                                              ? 'विक्रीसाठी उपलब्ध (Live)'
                                              : 'अनुपलब्ध / संपले (Unavailable)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: prod['status'] == 'published' && stock > 0
                                                ? const Color(0xFF16A34A)
                                                : const Color(0xFFDC2626),
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () async {
                                          final currentStatus = prod['status'] as String? ?? 'published';
                                          final newStatus = currentStatus == 'published' ? 'hidden' : 'published';
                                          setState(() {
                                            prod['status'] = newStatus;
                                          });
                                          final auth = Provider.of<AuthProvider>(context, listen: false);
                                          if (auth.authToken != null && prod['id'] != null) {
                                            await ApiService.updateProductAvailability(
                                              token: auth.authToken!,
                                              productId: prod['id'],
                                              status: newStatus,
                                            );
                                          }
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  newStatus == 'published'
                                                      ? 'उत्पादन वेबसाईटवर उपलब्ध केले (Product Live)'
                                                      : 'उत्पादन वेबसाईटवरून लपवले (Product Hidden)',
                                                ),
                                                duration: const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                        child: Text(
                                          prod['status'] == 'published' ? 'लपवा (Hide)' : 'लाईव्ह करा (Make Live)',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.terracotta),
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
