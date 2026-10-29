import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/services/api_service.dart';
import 'package:kalasathi_mobile/services/voice_guidance_service.dart';
import 'package:kalasathi_mobile/theme/app_theme.dart';
import 'package:kalasathi_mobile/widgets/voice_help_fab.dart';

class EarningsLearnScreen extends StatefulWidget {
  final int initialTab;

  const EarningsLearnScreen({super.key, this.initialTab = 0});

  @override
  State<EarningsLearnScreen> createState() => _EarningsLearnScreenState();
}

class _EarningsLearnScreenState extends State<EarningsLearnScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Future<Map<String, dynamic>>? _dashboardFuture;
  String _selectedTrendPeriod = 'monthly'; // 'daily', 'weekly', 'monthly'

  final List<Map<String, String>> _lessons = [
    {
      'title': '१. स्मार्टफोन फोटोग्राफी',
      'duration': '२ मिनिटे ऑडिओ धडा',
      'icon': 'camera',
      'content': 'शिल्पाचा फोटो काढताना नैसर्गिक सूर्यप्रकाशात बसा. पाठीमागे साधी भिंत ठेवा. परछाई येऊ देऊ नका. आमचे एआय आपोआप पांढरी पार्श्वभूमी तयार करेल.',
    },
    {
      'title': '२. रास्त किंमत आणि नफा',
      'duration': '३ मिनिटे ऑडिओ धडा',
      'icon': 'price',
      'content': 'कच्च्या मालाच्या खर्चात तुमचे दर तासाचे किमान ₹८५ मजुरी जोडा. कलासाथी हमी देते की तुम्ही कधीही तोट्यात विकणार नाही.',
    },
    {
      'title': '३. डिजिटल विक्री आणि संवाद',
      'duration': '२ मिनिटे ऑडिओ धडा',
      'icon': 'store',
      'content': 'ग्राहकांना हस्तकलेची कहाणी आवडते. तुम्ही वस्तू कशी बनवली हे आवाजात सांगा. वेबसाइटवर जगभरातील खरेदीदार ती वाचू शकतात.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboard();
    });
  }

  void _loadDashboard() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.authToken != null && auth.authToken!.isNotEmpty) {
      setState(() {
        _dashboardFuture = ApiService.getArtisanDashboard(auth.authToken!);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundSand,
      appBar: AppBar(
        title: Text(l10n.translate('earnings')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "ताजे करा",
            onPressed: _loadDashboard,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.terracotta,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: AppTheme.terracotta,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: [
            Tab(text: l10n.translate('earnings'), icon: const Icon(Icons.account_balance_wallet_rounded)),
            Tab(text: l10n.translate('learn'), icon: const Icon(Icons.school_rounded)),
          ],
        ),
      ),
      floatingActionButton: const VoiceHelpFab(
        customMessage: "कमाईच्या भागात थेट डेटाबेसमधील विक्री व उत्पन्न दिसते, आणि धड्यांच्या भागात विक्री वाढवणारे ऑडिओ आहेत.",
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEarningsTab(l10n),
          _buildLearnTab(l10n),
        ],
      ),
    );
  }

  Widget _buildEarningsTab(AppLocalizations l10n) {
    final auth = Provider.of<AuthProvider>(context);
    final token = auth.authToken;

    if (token == null || token.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text("कृपया कमाई पाहण्यासाठी लॉग इन करा.", style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
              child: const Text("लॉग इन करा"),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardFuture ?? ApiService.getArtisanDashboard(token),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.terracotta));
        }

        final data = snapshot.data ?? {};
        final grossSales = (data['gross_sales'] as num?)?.toDouble() ?? 0.0;
        final platformFees = (data['platform_fees'] as num?)?.toDouble() ?? 0.0;
        final refundsCancellations = (data['refunds_cancellations'] as num?)?.toDouble() ?? 0.0;
        final netEarnings = (data['net_earnings'] as num?)?.toDouble() ?? 0.0;
        final settledPayout = (data['settled_payout'] as num?)?.toDouble() ?? 0.0;
        final pendingPayout = (data['pending_payout'] as num?)?.toDouble() ?? 0.0;
        final totalOrders = (data['total_orders'] as num?)?.toInt() ?? 0;
        final productsSold = (data['products_sold'] as num?)?.toInt() ?? 0;

        final dailyTrends = (data['daily_trends'] as List<dynamic>?) ?? [];
        final weeklyTrends = (data['weekly_trends'] as List<dynamic>?) ?? [];
        final monthlyTrends = (data['monthly_trends'] as List<dynamic>?) ?? [];
        final bestSellers = (data['best_selling_products'] as List<dynamic>?) ?? [];
        final recentOrders = (data['recent_orders'] as List<dynamic>?) ?? [];

        return RefreshIndicator(
          color: AppTheme.terracotta,
          onRefresh: () async {
            _loadDashboard();
            await _dashboardFuture;
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Artisan Profile Banner
                if ((data['artisan_name'] as String?)?.isNotEmpty == true) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.terracotta.withOpacity(0.15),
                        child: const Icon(Icons.person, color: AppTheme.terracotta),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['artisan_name'],
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            "सत्यापित कारागीर",
                            style: TextStyle(fontSize: 12, color: AppTheme.successGreen, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Core Net Earnings Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.borderWarm),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "निव्वळ कमाई",
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreenLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text("Verified", style: TextStyle(color: AppTheme.successGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "₹ ${netEarnings.toStringAsFixed(0)}",
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: AppTheme.terracotta),
                      ),
                      const Divider(height: 24),

                      // Platform Breakdown: Gross - 8% Fee - Refunds
                      const Text(
                        "रक्कमेचा हिशोब:",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 10),
                      _buildBreakdownRow("एकूण विक्री:", "₹ ${grossSales.toStringAsFixed(0)}", AppTheme.textCharcoal),
                      const SizedBox(height: 6),
                      _buildBreakdownRow("कलासाथी फी (८%):", "- ₹ ${platformFees.toStringAsFixed(0)}", Colors.red.shade700),
                      if (refundsCancellations > 0) ...[
                        const SizedBox(height: 6),
                        _buildBreakdownRow("रद्द / परतावा:", "- ₹ ${refundsCancellations.toStringAsFixed(0)}", Colors.red.shade700),
                      ],
                      const Divider(height: 24),

                      // Payout Status Pills (Settled vs Pending)
                      Row(
                        children: [
                          _buildStatPill("खात्यात जमा", "₹ ${settledPayout.toStringAsFixed(0)}", AppTheme.successGreen),
                          const SizedBox(width: 12),
                          _buildStatPill("प्रलंबित रक्कम", "₹ ${pendingPayout.toStringAsFixed(0)}", AppTheme.turmericDark),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Orders & Units Sold Summary
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.borderWarm),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("एकूण ऑर्डर्स", style: TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text("$totalOrders", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.indigo)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.borderWarm),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("विकलेल्या वस्तू", style: TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text("$productsSold", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.terracotta)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Sales Trends Section with Period Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "विक्री आलेख",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderWarm),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedTrendPeriod,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down, color: AppTheme.terracotta),
                        items: const [
                          DropdownMenuItem(value: 'daily', child: Text("दैनिक", style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'weekly', child: Text("साप्ताहिक", style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'monthly', child: Text("मासिक", style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedTrendPeriod = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildTrendsSection(dailyTrends, weeklyTrends, monthlyTrends),
                const SizedBox(height: 24),

                // Best-Selling Products Section
                if (bestSellers.isNotEmpty) ...[
                  const Text(
                    "सर्वाधिक विक्री झालेली उत्पादने",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderWarm),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: bestSellers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final item = bestSellers[idx];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: idx == 0 ? AppTheme.turmericLight : AppTheme.backgroundSand,
                            child: Text(
                              "#${idx + 1}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: idx == 0 ? AppTheme.turmericDark : AppTheme.textMuted,
                              ),
                            ),
                          ),
                          title: Text(item['title'] ?? 'उत्पादन', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${item['quantity_sold'] ?? item['units_sold'] ?? 0} वस्तू विकल्या"),
                          trailing: Text(
                            "₹ ${((item['gross_revenue'] ?? item['total_revenue']) as num?)?.toStringAsFixed(0) ?? '0'}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.terracotta, fontSize: 16),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Recent Orders Section
                if (recentOrders.isNotEmpty) ...[
                  const Text(
                    "नुकत्याच आलेल्या ऑर्डर्स",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderWarm),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentOrders.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final ord = recentOrders[idx];
                        final ordId = ord['order_id'] ?? ord['id'];
                        final ordStatus = (ord['status'] as String? ?? 'pending').toUpperCase();
                        final ordAmount = (ord['artisan_net_earnings'] as num?)?.toDouble() ?? (ord['artisan_share'] as num?)?.toDouble() ?? (ord['total_amount'] as num?)?.toDouble() ?? 0.0;
                        final ordDate = (ord['created_at'] as String? ?? '').split('T').first;
                        final ordCity = ord['shipping_city'] ?? ord['buyer_city'] ?? 'भारत';

                        return ListTile(
                          title: Text("ऑर्डर #$ordId", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("$ordDate • $ordCity"),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("₹ ${ordAmount.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.terracotta)),
                              Text(ordStatus, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor(ordStatus))),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBreakdownRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textCharcoal)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildTrendsSection(List<dynamic> daily, List<dynamic> weekly, List<dynamic> monthly) {
    List<dynamic> activeTrends = _selectedTrendPeriod == 'daily'
        ? daily
        : _selectedTrendPeriod == 'weekly'
            ? weekly
            : monthly;

    if (activeTrends.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.borderWarm),
        ),
        alignment: Alignment.center,
        child: const Text(
          "सध्या कोणताही विक्री डेटा उपलब्ध नाही. नवीन ऑर्डर्स आल्यावर आलेख दिसेल.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    final maxVal = activeTrends.fold<double>(
      1.0,
      (max, e) => ((e['sales'] as num?)?.toDouble() ?? 0.0) > max ? ((e['sales'] as num?)?.toDouble() ?? 0.0) : max,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderWarm),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: activeTrends.take(6).map((trend) {
              final sales = (trend['sales'] as num?)?.toDouble() ?? 0.0;
              final period = trend['period'] as String? ?? '';
              final shortPeriod = period.length > 5 ? period.substring(period.length - 5) : period;
              final ratio = maxVal > 0 ? (sales / maxVal).clamp(0.08, 1.0) : 0.08;
              return _buildBar(
                period: shortPeriod,
                amount: "₹${(sales / 1000).toStringAsFixed(1)}k",
                heightRatio: ratio,
                isHighlight: sales == maxVal,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Text(
            "* हा आलेख थेट मंजूर झालेल्या ऑर्डर्सवर आधारित आहे.",
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return AppTheme.successGreen;
      case 'shipped':
        return AppTheme.indigoLight;
      case 'packed':
        return AppTheme.turmericDark;
      case 'accepted':
        return AppTheme.indigo;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget _buildStatPill(String title, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(val, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBar({required String period, required String amount, required double heightRatio, bool isHighlight = false}) {
    return Column(
      children: [
        Text(amount, style: TextStyle(fontWeight: FontWeight.bold, color: isHighlight ? AppTheme.terracotta : AppTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 6),
        Container(
          width: 38,
          height: 120 * heightRatio,
          decoration: BoxDecoration(
            color: isHighlight ? AppTheme.terracotta : AppTheme.indigoLight,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 10),
        Text(period, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      ],
    );
  }

  Widget _buildLearnTab(AppLocalizations l10n) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _lessons.length,
      itemBuilder: (context, index) {
        final lesson = _lessons[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderWarm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.turmericLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.turmericDark, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson['title']!,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          lesson['duration']!,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                lesson['content']!,
                style: const TextStyle(fontSize: 14, color: AppTheme.textCharcoal, height: 1.4),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text("हा धडा आवाजात ऐका"),
                onPressed: () {
                  VoiceGuidanceService.speakPrompt(context, lesson['content']!);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
