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
                                        onPressed: () {
                                          if (stock > 0) {
                                            setState(() {
                                              prod['stock'] = stock - 1;
                                            });
                                            VoiceGuidanceService.speakPrompt(context, "साठा बदलून ${stock - 1} झाला आहे.");
                                          }
                                        },
                                      ),
                                      Text(
                                        "$stock",
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.terracotta),
                                        onPressed: () {
                                          setState(() {
                                            prod['stock'] = stock + 1;
                                          });
                                          VoiceGuidanceService.speakPrompt(context, "साठा वाढवून ${stock + 1} झाला आहे.");
                                        },
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
