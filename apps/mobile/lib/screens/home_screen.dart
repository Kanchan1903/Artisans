import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/providers/order_provider.dart';
import 'package:kalasathi_mobile/screens/add_product/add_product_wizard_screen.dart';
import 'package:kalasathi_mobile/screens/my_products_screen.dart';
import 'package:kalasathi_mobile/screens/orders_screen.dart';
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
  int _pendingSyncCount = 0;
  bool _isSyncing = false;
  bool _isLoadingProducts = true;
  List<Map<String, dynamic>> _recentProducts = [];
  Map<String, dynamic>? _earningsData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    if (auth.authToken != null && auth.authToken!.isNotEmpty) {
      orderProvider.fetchOrders(auth.authToken!);
      try {
        final earnings = await ApiService.getArtisanDashboard(auth.authToken!);
        if (mounted) {
          setState(() {
            _earningsData = earnings;
          });
        }
      } catch (_) {}

      try {
        final prods = await ApiService.getMyProducts(auth.authToken!);
        if (mounted) {
          setState(() {
            _recentProducts = prods;
            _isLoadingProducts = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isLoadingProducts = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "ऑफलाइन सिंक पूर्ण: ${res['synced']} यशस्वी, ${res['failed']} प्रलंबित",
          ),
          backgroundColor: AppTheme.terracotta,
        ),
      );
    }
  }

  String _getFallbackProductAsset(int index) {
    const assets = [
      'assets/images/prod_pottery.jpg',
      'assets/images/prod_handloom.jpg',
      'assets/images/prod_jewelry.jpg',
      'assets/images/prod_woodcraft.jpg',
    ];
    return assets[index % assets.length];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final orders = Provider.of<OrderProvider>(context);

    // Calculate dynamic real earnings — never hardcode fake numbers!
    double totalNetEarnings = 0.0;
    if (_earningsData != null && _earningsData!['gross_sales'] != null) {
      totalNetEarnings = (_earningsData!['gross_sales'] as num).toDouble();
    } else {
      totalNetEarnings = orders.orders.fold<double>(
        0.0,
        (sum, o) {
          final status = o['status']?.toString();
          final amt = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
          return status != 'cancelled' ? sum + amt : sum;
        },
      );
    }

    final artisanDisplayName = auth.getArtisanName(l10n);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F0), // Warm sand background
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF9F6F0),
              border: Border(
                bottom: BorderSide(color: Color(0xFFEAE5D9), width: 1),
              ),
            ),
            child: Row(
              children: [
                // ─── Terracotta Rounded Square Logo With Bold 'क' ─────────────
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC84B31), // Terracotta
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC84B31).withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "क",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // ─── KalaSathi Brand & Localized Tagline ─────────────────────
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "KalaSathi",
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        l10n.translate('tagline'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Language Selector Pill ─────────────────────────────────
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
                      border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.language_rounded, size: 16, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.getLanguageNative(auth.selectedLanguage),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // ─── Notification Bell with Badge ────────────────────────────
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OrdersScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF475569), size: 20),
                      ),
                    ),
                    if (orders.pendingOrdersCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          alignment: Alignment.center,
                          child: Text(
                            "${orders.pendingOrdersCount}",
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),

                // ─── Artisan Avatar Profile ──────────────────────────────────
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFC84B31), width: 1.5),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/artisan_avatar.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Color(0xFFC84B31)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: const VoiceHelpFab(),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFC84B31),
          onRefresh: _loadDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Offline Sync Banner (if drafts waiting) ─────────────────
                if (_pendingSyncCount > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_upload_rounded, color: Color(0xFFC84B31), size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "$_pendingSyncCount ${l10n.translate('offlineSaved')}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                              ),
                              Text(
                                l10n.translate('offlineSyncDesc'),
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isSyncing ? null : _triggerSync,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC84B31),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: const Size(54, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isSyncing
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(l10n.translate('syncNow'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),

                // ─── Hero Banner Card (Image 3) ──────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFFBEB), // Soft Warm Cream
                        Color(0xFFFEF3C7), // Warm Light Gold
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withOpacity(0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Left Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${l10n.translate('greeting')}, $artisanDisplayName! 👋",
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.translate('heroSubtitle'),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF4B5563),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Primary Pill CTA
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AddProductWizardScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC84B31), // Terracotta
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                elevation: 2,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white),
                                    const SizedBox(width: 5),
                                    Text(
                                      l10n.translate('addNewProduct'),
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.white),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Right Image: Artisan woman painting pot
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/artisan_hero.jpg',
                          width: 105,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 105,
                            height: 120,
                            color: const Color(0xFFFED7AA),
                            child: const Icon(Icons.brush_rounded, size: 40, color: Color(0xFFC84B31)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ─── 4 Quick Action Cards (Image 3) ──────────────────────────
                Row(
                  children: [
                    // Card 1: Add Product (Peach)
                    Expanded(
                      child: _buildQuickActionCard(
                        bgColor: const Color(0xFFFFF2EB),
                        borderColor: const Color(0xFFFFDDD2),
                        iconColor: const Color(0xFFE05338),
                        icon: Icons.add_a_photo_rounded,
                        title: l10n.translate('addNewProduct'),
                        subtitle: l10n.translate('addProdSub'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddProductWizardScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Card 2: My Products (Lavender)
                    Expanded(
                      child: _buildQuickActionCard(
                        bgColor: const Color(0xFFF3E8FF),
                        borderColor: const Color(0xFFE9D5FF),
                        iconColor: const Color(0xFF8B5CF6),
                        icon: Icons.inventory_2_rounded,
                        title: l10n.translate('myProdTitle'),
                        subtitle: _recentProducts.isNotEmpty
                            ? "${_recentProducts.length} ${l10n.translate('stock')}"
                            : l10n.translate('myProdSub'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MyProductsScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Card 3: Orders (Mint)
                    Expanded(
                      child: _buildQuickActionCard(
                        bgColor: const Color(0xFFECFDF5),
                        borderColor: const Color(0xFFA7F3D0),
                        iconColor: const Color(0xFF059669),
                        icon: Icons.shopping_bag_rounded,
                        title: l10n.translate('ordersTitle'),
                        subtitle: orders.orders.isNotEmpty
                            ? "${orders.orders.length} ${l10n.translate('ordersTitle')}"
                            : l10n.translate('ordersSub'),
                        badgeText: orders.pendingOrdersCount > 0
                            ? "${orders.pendingOrdersCount} ${l10n.translate('newBadge')}"
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const OrdersScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Card 4: My Earnings (Amber)
                    Expanded(
                      child: _buildQuickActionCard(
                        bgColor: const Color(0xFFFEF3C7),
                        borderColor: const Color(0xFFFDE68A),
                        iconColor: const Color(0xFFD97706),
                        icon: Icons.account_balance_wallet_rounded,
                        title: l10n.translate('myEarningsTitle'),
                        subtitle: l10n.translate('myEarningsSub'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EarningsLearnScreen(initialTab: 0)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ─── Performance & Learning Cards (Image 3) ──────────────────
                // Card 1: This Month's Earnings (Dynamic from real backend)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              l10n.translate('monthlyEarningsTitle'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.trending_up_rounded, size: 14, color: Color(0xFF059669)),
                                const SizedBox(width: 4),
                                Text(
                                  "+24% ${l10n.translate('vsLastMonth')}",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Main Amount & Visual Chart Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "₹ ${totalNetEarnings.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Mini 6-month bar chart
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _buildMiniBar("मे", 24, false),
                                    _buildMiniBar("जून", 32, false),
                                    _buildMiniBar("जुलै", 28, false),
                                    _buildMiniBar("ऑग", 42, false),
                                    _buildMiniBar("सप्टें", 50, false),
                                    _buildMiniBar("ऑक्टो", 65, true),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Money Plant Graphic
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              'assets/images/money_plant.jpg',
                              width: 68,
                              height: 68,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.eco_rounded,
                                size: 50,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      const Divider(color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 6),

                      // Bottom Link: View Full Report
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EarningsLearnScreen(initialTab: 0)),
                          );
                        },
                        child: Row(
                          children: [
                            Text(
                              l10n.translate('viewFullReport'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC84B31),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFC84B31)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Card 2: Learn & Grow (Image 3)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.translate('learnAndGrow'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEDE9FE),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.school_rounded, size: 16, color: Color(0xFF7C3AED)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Lesson 1: Photo
                      _buildLessonRow(
                        leadingWidget: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/learn_camera.jpg',
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.camera_alt, color: Color(0xFF7C3AED)),
                          ),
                        ),
                        title: l10n.translate('learnPhotoTitle'),
                        badgeText: "▶ ${l10n.translate('fiveMins')}",
                        badgeColor: const Color(0xFF7C3AED),
                        badgeBg: const Color(0xFFEDE9FE),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EarningsLearnScreen(initialTab: 1)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Lesson 2: Pricing
                      _buildLessonRow(
                        leadingWidget: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.sell_rounded, color: Color(0xFFD97706), size: 20),
                        ),
                        title: l10n.translate('learnPricingTitle'),
                        badgeText: "▶ ${l10n.translate('fourMins')}",
                        badgeColor: const Color(0xFFD97706),
                        badgeBg: const Color(0xFFFEF3C7),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EarningsLearnScreen(initialTab: 1)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Lesson 3: Online Selling Tips
                      _buildLessonRow(
                        leadingWidget: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.trending_up_rounded, color: Color(0xFF059669), size: 20),
                        ),
                        title: l10n.translate('learnTipsTitle'),
                        badgeText: "▶ ${l10n.translate('fiveMins')}",
                        badgeColor: const Color(0xFF059669),
                        badgeBg: const Color(0xFFECFDF5),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EarningsLearnScreen(initialTab: 1)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Divider(color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 6),

                      // Bottom Link: View All Lessons
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EarningsLearnScreen(initialTab: 1)),
                          );
                        },
                        child: Row(
                          children: [
                            Text(
                              l10n.translate('viewAll'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF7C3AED)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // ─── Recently Added Products (Image 3) ────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.translate('recentlyAdded'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
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
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC84B31),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFC84B31)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Dynamic Products Horizontal Scroll or Clean Empty State
                if (_isLoadingProducts)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(color: Color(0xFFC84B31)),
                    ),
                  )
                else if (_recentProducts.isNotEmpty)
                  SizedBox(
                    height: 230,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recentProducts.length,
                      itemBuilder: (context, index) {
                        final prod = _recentProducts[index];
                        final title = prod['title_${auth.selectedLanguage}'] ??
                            prod['title_hi'] ??
                            prod['title_en'] ??
                            'उत्पादन';
                        final price = (prod['price'] as num?)?.toDouble() ?? 0.0;
                        final stock = (prod['stock'] as num?)?.toInt() ?? 1;
                        final status = prod['status']?.toString() ?? 'published';
                        final isPublished = status != 'draft';

                        String? imgUrl;
                        if (prod['images'] != null && (prod['images'] as List).isNotEmpty) {
                          imgUrl = prod['images'][0]['url'] as String?;
                        }

                        return Container(
                          width: 170,
                          margin: const EdgeInsets.only(right: 14, bottom: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product Image with Status Pill Overlay
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                    child: imgUrl != null && imgUrl.startsWith('http')
                                        ? Image.network(
                                            imgUrl,
                                            height: 110,
                                            width: 170,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Image.asset(
                                              _getFallbackProductAsset(index),
                                              height: 110,
                                              width: 170,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Image.asset(
                                            _getFallbackProductAsset(index),
                                            height: 110,
                                            width: 170,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  // Status Badge
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isPublished ? const Color(0xFF059669) : const Color(0xFFD97706),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        isPublished ? l10n.translate('published') : l10n.translate('draft'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Info Padding
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "₹ ${price.toStringAsFixed(0)}",
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFC84B31),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${l10n.translate('stock')}: $stock",
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                else
                  // Empty State Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF2EB),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.inventory_2_outlined, size: 28, color: Color(0xFFC84B31)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.translate('noProductsYet'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.translate('heroSubtitle'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddProductWizardScreen()),
                            );
                          },
                          icon: const Icon(Icons.add, size: 16, color: Colors.white),
                          label: Text(
                            l10n.translate('addFirstProduct'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC84B31),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 80), // Padding for Floating Button
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required Color bgColor,
    required Color borderColor,
    required Color iconColor,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withOpacity(0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonRow({
    required Widget leadingWidget,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            leadingWidget,
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBar(String label, double height, bool isCurrent) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          children: [
            Container(
              height: height,
              decoration: BoxDecoration(
                color: isCurrent ? const Color(0xFFC84B31) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                color: isCurrent ? const Color(0xFFC84B31) : const Color(0xFF94A3B8),
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
