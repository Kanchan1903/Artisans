import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/providers/order_provider.dart';
import 'package:kalasathi_mobile/screens/add_product/add_product_wizard_screen.dart';
import 'package:kalasathi_mobile/screens/my_products_screen.dart';
import 'package:kalasathi_mobile/screens/inquiries_screen.dart';
import 'package:kalasathi_mobile/screens/earnings_learn_screen.dart';
import 'package:kalasathi_mobile/screens/language_picker_screen.dart';
import 'package:kalasathi_mobile/screens/settings_screen.dart';
import 'package:kalasathi_mobile/theme/app_theme.dart';
import 'package:kalasathi_mobile/widgets/voice_help_fab.dart';
import 'package:kalasathi_mobile/services/offline_storage_service.dart';
import 'package:kalasathi_mobile/services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  int _pendingSyncCount = 0;
  bool _isSyncing = false;
  List<Map<String, dynamic>> _recentProducts = [];
  int _unreadInquiriesCount = 0;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    if (auth.authToken != null && auth.authToken!.isNotEmpty) {
      orderProvider.fetchOrders(auth.authToken!);
      try {
        final inquiries = await ApiService.getArtisanInquiries(auth.authToken!);
        final unread = inquiries.where((inq) => inq['is_read'] != true).length;
        if (mounted) {
          setState(() {
            _unreadInquiriesCount = unread;
          });
        }
      } catch (_) {}

      try {
        final prods = await ApiService.getMyProducts(auth.authToken!);
        if (mounted) {
          setState(() {
            _recentProducts = prods;
          });
        }
      } catch (_) {}
    }

    _checkPendingSync();
  }

  Future<void> _checkPendingSync() async {
    final count = await OfflineStorageService.getQueueCount();
    if (mounted) {
      setState(() {
        _pendingSyncCount = count;
      });
    }
  }

  Future<void> _triggerSync() async {
    setState(() => _isSyncing = true);
    final apiService = ApiService();
    final res = await OfflineStorageService.syncOfflineQueue(apiService);
    await _checkPendingSync();
    await _loadDashboardData();
    setState(() => _isSyncing = false);

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${l10n.translate('syncNow')}: ${res['synced']} ok, ${res['failed']} pending",
          ),
          backgroundColor: AppTheme.maroonPrimary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final orders = Provider.of<OrderProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundSand,
      floatingActionButton: VoiceHelpFab(
        customMessage: l10n.translate('helpHome'),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(l10n),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.maroonPrimary,
          onRefresh: () async {
            await _loadDashboardData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── 1. Header (Lotus Logo + KalaSathi + Bell + Avatar) ──────
                _buildHeader(context, auth, l10n),
                const SizedBox(height: 14),

                // ─── 2. Search Bar ───────────────────────────────────────────
                _buildSearchBar(l10n),
                const SizedBox(height: 16),

                // ─── 3. Offline Sync Alert if pending ────────────────────────
                if (_pendingSyncCount > 0) ...[
                  _buildSyncBanner(l10n),
                  const SizedBox(height: 14),
                ],

                // ─── 4. Hero Carousel Banner Card ────────────────────────────
                _buildHeroCard(context, l10n),
                const SizedBox(height: 20),

                // ─── 5. Category Quick Actions (5 Rounded Peach Tiles) ───────
                _buildCategoryTiles(context, l10n),
                const SizedBox(height: 22),

                // ─── 6. Featured Products Section ────────────────────────────
                _buildFeaturedProductsSection(context, l10n, auth),
                const SizedBox(height: 20),

                // ─── 7. Support Indian Artisans Promo Banner ──────────────────
                _buildSupportArtisansBanner(l10n),
                const SizedBox(height: 20),

                // ─── 8. Recent Activity Card ─────────────────────────────────
                _buildRecentActivitySection(context, l10n, orders),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header Widget ──────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, AuthProvider auth, AppLocalizations l10n) {
    final artisanInitial = (auth.artisanProfile?['name']?.toString().trim().isNotEmpty ?? false)
        ? auth.artisanProfile!['name'].toString().trim()[0].toUpperCase()
        : 'K';

    return Row(
      children: [
        // Stylized Lotus Logo Icon
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF7E6E2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8CEC6), width: 1.2),
          ),
          child: Center(
            child: Icon(
              Icons.spa_rounded,
              color: AppTheme.maroonPrimary,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Brand Name & Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.translate('appTitle'),
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.maroonPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Text(
                l10n.translate('createSellGrow'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF7A6864),
                ),
              ),
            ],
          ),
        ),

        // Language Pill
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LanguagePickerScreen(isModal: true)),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5DDD0), width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language_rounded, size: 16, color: AppTheme.maroonPrimary),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.getLanguageNative(auth.selectedLanguage),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.maroonPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Notification Bell with Red Badge
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InquiriesScreen()),
            ).then((_) => _loadDashboardData());
          },
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppTheme.textCharcoal,
                  size: 26,
                ),
              ),
              if (_unreadInquiriesCount > 0)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Artisan Profile Avatar with Initial
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          child: CircleAvatar(
            radius: 19,
            backgroundColor: AppTheme.maroonPrimary,
            child: Text(
              artisanInitial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6EE),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFEBE1D3), width: 1.2),
      ),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: l10n.translate('searchProductsHint'),
          hintStyle: const TextStyle(color: Color(0xFF9E8F88), fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF7A6864), size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onSubmitted: (query) {
          if (query.trim().isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyProductsScreen()),
            );
          }
        },
      ),
    );
  }

  // ─── Hero Carousel Banner Card ──────────────────────────────────────────────
  Widget _buildHeroCard(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 185),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFBE4D2),
                Color(0xFFF6D4BC),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEFC9AD), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7A2024).withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background ornamental subtle icon
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  Icons.local_florist_rounded,
                  size: 150,
                  color: Colors.white.withOpacity(0.2),
                ),
              ),

              // Content Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left Text & Button
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.translate('empoweringArtisans'),
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.maroonPrimary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.translate('turnCreativity'),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF6B5854),
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Start Selling Button
                          ElevatedButton(
                            onPressed: () => _onAddProductTap(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.maroonPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              minimumSize: const Size(0, 36),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n.translate('startSelling'),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Icon(Icons.arrow_forward_rounded, size: 13),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Right Artisan Photo
                    Expanded(
                      flex: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/artisan_hero.jpg',
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 140,
                            color: const Color(0xFFE8CEC6),
                            child: const Icon(
                              Icons.brush_rounded,
                              size: 40,
                              color: AppTheme.maroonPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Dots Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 14,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.maroonPrimary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD8C7BC),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD8C7BC),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Category Quick Actions (5 Rounded Peach Tiles) ─────────────────────────
  Widget _buildCategoryTiles(BuildContext context, AppLocalizations l10n) {
    final categories = [
      {'label': l10n.translate('handicrafts'), 'icon': Icons.palette_outlined},
      {'label': l10n.translate('homeDecor'), 'icon': Icons.chair_outlined},
      {'label': l10n.translate('fashion'), 'icon': Icons.checkroom_outlined},
      {'label': l10n.translate('jewellery'), 'icon': Icons.diamond_outlined},
      {'label': l10n.translate('more'), 'icon': Icons.grid_view_rounded},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: categories.map((cat) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyProductsScreen()),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7E6D7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEED1BE), width: 1),
                    ),
                    child: Center(
                      child: Icon(
                        cat['icon'] as IconData,
                        color: const Color(0xFF6A4A3C),
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat['label'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A3E3B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Featured Products Section (2-Column Cards) ─────────────────────────────
  Widget _buildFeaturedProductsSection(
      BuildContext context, AppLocalizations l10n, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.translate('featuredProducts'),
              style: const TextStyle(
                fontFamily: 'serif',
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppTheme.maroonPrimary,
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyProductsScreen()),
                );
              },
              child: Row(
                children: [
                  Text(
                    l10n.translate('viewAll'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.maroonPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.maroonPrimary),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2-Column Product Cards
        Row(
          children: [
            Expanded(
              child: _buildFeaturedProductCard(
                title: _recentProducts.isNotEmpty
                    ? (_recentProducts[0]['title_${auth.selectedLanguage}'] ??
                        _recentProducts[0]['title_hi'] ??
                        _recentProducts[0]['title_en'] ??
                        l10n.translate('handmadePot'))
                    : l10n.translate('handmadePot'),
                price: _recentProducts.isNotEmpty
                    ? "₹${((_recentProducts[0]['price'] as num?)?.toDouble() ?? 499.0).toStringAsFixed(0)}"
                    : "₹499",
                imageAsset: 'assets/images/prod_pottery.jpg',
                imageUrl: (_recentProducts.isNotEmpty &&
                        _recentProducts[0]['images'] != null &&
                        (_recentProducts[0]['images'] as List).isNotEmpty)
                    ? _recentProducts[0]['images'][0]['url']
                    : null,
                onTap: () => _onAddProductTap(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFeaturedProductCard(
                title: _recentProducts.length > 1
                    ? (_recentProducts[1]['title_${auth.selectedLanguage}'] ??
                        _recentProducts[1]['title_hi'] ??
                        _recentProducts[1]['title_en'] ??
                        l10n.translate('woodenElephant'))
                    : l10n.translate('woodenElephant'),
                price: _recentProducts.length > 1
                    ? "₹${((_recentProducts[1]['price'] as num?)?.toDouble() ?? 799.0).toStringAsFixed(0)}"
                    : "₹799",
                imageAsset: 'assets/images/prod_woodcraft.jpg',
                imageUrl: (_recentProducts.length > 1 &&
                        _recentProducts[1]['images'] != null &&
                        (_recentProducts[1]['images'] as List).isNotEmpty)
                    ? _recentProducts[1]['images'][0]['url']
                    : null,
                onTap: () => _onAddProductTap(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturedProductCard({
    required String title,
    required String price,
    required String imageAsset,
    String? imageUrl,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBE3D7), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image + Wishlist Heart Button
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                child: imageUrl != null && imageUrl.startsWith('http')
                    ? Image.network(
                        imageUrl,
                        height: 130,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          imageAsset,
                          height: 130,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        imageAsset,
                        height: 130,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    size: 18,
                    color: Color(0xFF6B5854),
                  ),
                ),
              ),
            ],
          ),

          // Title & Price Row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF261C1A),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.maroonPrimary,
                      ),
                    ),
                    InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppTheme.maroonPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.shopping_cart_outlined,
                          size: 15,
                          color: Colors.white,
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
  }

  // ─── Support Indian Artisans Promo Banner ───────────────────────────────────
  Widget _buildSupportArtisansBanner(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFBE4D2),
            Color(0xFFF7D5BC),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFC9AD), width: 1.2),
      ),
      child: Row(
        children: [
          // Leaves / Lotus Motif
          const Icon(
            Icons.eco_rounded,
            color: Color(0xFF2E7D32),
            size: 32,
          ),
          const SizedBox(width: 12),

          // Text Center
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('supportIndianArtisans'),
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.maroonPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.translate('shopHandmadeShopLocal'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B5854),
                  ),
                ),
              ],
            ),
          ),

          // Gift Box Icon / Ornament
          const Icon(
            Icons.card_giftcard_rounded,
            color: AppTheme.maroonPrimary,
            size: 34,
          ),
        ],
      ),
    );
  }

  // ─── Recent Activity Card ───────────────────────────────────────────────────
  Widget _buildRecentActivitySection(
      BuildContext context, AppLocalizations l10n, OrderProvider orders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.translate('recentActivity'),
              style: const TextStyle(
                fontFamily: 'serif',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.maroonPrimary,
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InquiriesScreen()),
                );
              },
              child: Row(
                children: [
                  Text(
                    l10n.translate('viewAll'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.maroonPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.maroonPrimary),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Activity Card
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InquiriesScreen()),
            );
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEBE3D7), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.maroonPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('newInquiryOnProduct'),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF261C1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.translate('hoursAgo'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF7A6864),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF7A6864),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Bottom Navigation Bar (5 Items) ────────────────────────────────────────
  Widget _buildBottomNavigationBar(AppLocalizations l10n) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFEBE3D7), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              index: 0,
              icon: Icons.home_rounded,
              label: l10n.translate('home'),
              isActive: _currentNavIndex == 0,
              onTap: () => setState(() => _currentNavIndex = 0),
            ),
            _buildNavItem(
              index: 1,
              icon: Icons.inventory_2_outlined,
              label: l10n.translate('myProducts'),
              isActive: _currentNavIndex == 1,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyProductsScreen()),
                );
              },
            ),
            _buildNavItem(
              index: 2,
              icon: Icons.trending_up_rounded,
              label: l10n.translate('analytics'),
              isActive: _currentNavIndex == 2,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EarningsLearnScreen(initialTab: 0)),
                );
              },
            ),
            _buildNavItem(
              index: 3,
              icon: Icons.chat_bubble_outline_rounded,
              label: l10n.translate('inquiriesTitle'),
              badgeCount: _unreadInquiriesCount > 0 ? _unreadInquiriesCount : null,
              isActive: _currentNavIndex == 3,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InquiriesScreen()),
                ).then((_) => _loadDashboardData());
              },
            ),
            _buildNavItem(
              index: 4,
              icon: Icons.person_outline_rounded,
              label: l10n.translate('profile'),
              isActive: _currentNavIndex == 4,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isActive,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: isActive ? AppTheme.maroonPrimary : const Color(0xFF7A6864),
                size: 24,
              ),
              if (badgeCount != null)
                Positioned(
                  top: -4,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "$badgeCount",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? AppTheme.maroonPrimary : const Color(0xFF7A6864),
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 18,
              height: 2.5,
              decoration: BoxDecoration(
                color: AppTheme.maroonPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSyncBanner(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2EB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFDDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppTheme.maroonPrimary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$_pendingSyncCount ${l10n.translate('offlineSaved')}",
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.maroonPrimary),
            ),
          ),
          ElevatedButton(
            onPressed: _isSyncing ? null : _triggerSync,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.maroonPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(54, 30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSyncing
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(l10n.translate('syncNow'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF7A6864)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Clear drafts',
            onPressed: () async {
              await OfflineStorageService.clearOfflineDrafts();
              await _checkPendingSync();
            },
          ),
        ],
      ),
    );
  }

  void _onAddProductTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddProductWizardScreen(initialStep: 0)),
    );
  }
}
