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
import 'package:kalasathi_mobile/widgets/big_action_tile.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.authToken != null) {
        Provider.of<OrderProvider>(context, listen: false).fetchOrders(auth.authToken!);
      }
      _checkPendingSync();
    });
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
    setState(() => _isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "ऑफलाइन सिंक पूर्ण: ${res['synced']} यशस्वी, ${res['failed']} प्रलंबित (Synced: ${res['synced']}, Failed: ${res['failed']})",
          ),
          backgroundColor: AppTheme.terracotta,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final orders = Provider.of<OrderProvider>(context);

    final artisanName = auth.artisanProfile?['name'] ?? 'कारीगर मित्र';
    final craftType = auth.artisanProfile?['craft_type'] ?? 'वारली चित्रकला';
    final village = auth.artisanProfile?['village'] ?? 'पालघर';

    return Scaffold(
      backgroundColor: AppTheme.backgroundSand,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppTheme.terracotta,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.palette_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.translate('appTitle'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
        actions: [
          // Language Switcher Pill
          ActionChip(
            avatar: const Icon(Icons.language_rounded, size: 18, color: AppTheme.indigo),
            label: Text(
              auth.selectedLanguage.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.indigo),
            ),
            backgroundColor: AppTheme.indigoLight,
            side: const BorderSide(color: AppTheme.indigo, width: 1),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LanguagePickerScreen(isModal: true)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: AppTheme.textCharcoal),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: const VoiceHelpFab(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (auth.authToken != null) {
              await orders.fetchOrders(auth.authToken!);
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Welcome Header ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "नमस्ते, $artisanName!",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textCharcoal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 16, color: AppTheme.terracotta),
                            const SizedBox(width: 4),
                            Text(
                              "$village | $craftType",
                              style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ─── Offline Sync Banner (if drafts waiting) ─────────────────
                if (_pendingSyncCount > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.turmericLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.turmeric, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_upload_rounded, color: AppTheme.terracotta, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "$_pendingSyncCount ऑफलाइन वस्तू सेव्ह आहेत",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textCharcoal),
                              ),
                              const Text(
                                "इंटरनेट सुरू झाल्यावर सर्व वस्तू प्रकाशित करा",
                                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isSyncing ? null : _triggerSync,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.terracotta,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: const Size(60, 36),
                          ),
                          child: _isSyncing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text("सिंक करा", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                // ─── Monthly Earnings Summary Card ───────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.indigoDark, AppTheme.indigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.indigo.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.translate('monthlySummary'),
                            style: const TextStyle(color: Colors.white70, fontSize: 15),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              "ऑक्टोबर 2026",
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "₹ 14,850",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("खात्यात जमा (Settled)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  const Text("₹ 11,400", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("प्रलंबित (Pending)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  const Text("₹ 3,450", style: TextStyle(color: AppTheme.turmeric, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Prominent Primary Action: Add Product ────────────────────
                BigActionTile(
                  isPrimary: true,
                  title: l10n.translate('addProduct'),
                  subtitle: l10n.translate('addProductSub'),
                  icon: Icons.add_a_photo_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddProductWizardScreen()),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // ─── Big Navigation Tiles ────────────────────────────────────
                BigActionTile(
                  title: l10n.translate('myProducts'),
                  subtitle: "साठा अद्ययावत करा / बदल करा",
                  icon: Icons.inventory_2_rounded,
                  color: AppTheme.indigo,
                  iconBgColor: AppTheme.indigoLight,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyProductsScreen()),
                    );
                  },
                ),
                const SizedBox(height: 14),

                BigActionTile(
                  title: l10n.translate('orders'),
                  subtitle: "नवीन ग्राहक ऑर्डर्स",
                  icon: Icons.shopping_bag_rounded,
                  color: AppTheme.terracotta,
                  iconBgColor: AppTheme.terracottaLight,
                  badgeText: orders.pendingOrdersCount > 0
                      ? "${orders.pendingOrdersCount} New"
                      : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OrdersScreen()),
                    );
                  },
                ),
                const SizedBox(height: 14),

                BigActionTile(
                  title: l10n.translate('earnings'),
                  subtitle: "उत्पन्न आणि बँक खात्याचा तपशील",
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppTheme.turmericDark,
                  iconBgColor: AppTheme.turmericLight,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EarningsLearnScreen(initialTab: 0)),
                    );
                  },
                ),
                const SizedBox(height: 14),

                BigActionTile(
                  title: l10n.translate('learn'),
                  subtitle: "फोटो काढणे व योग्य किमतीचे ऑडिओ धडे",
                  icon: Icons.school_rounded,
                  color: AppTheme.indigo,
                  iconBgColor: AppTheme.indigoLight,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EarningsLearnScreen(initialTab: 1)),
                    );
                  },
                ),
                const SizedBox(height: 80), // Padding for floating button
              ],
            ),
          ),
        ),
      ),
    );
  }
}
