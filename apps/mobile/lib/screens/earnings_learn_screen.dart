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
  String _selectedTrendPeriod = 'monthly';

  String _t(AuthProvider auth, {required String en, required String hi, required String mr}) {
    if (auth.selectedLanguage == 'mr') return mr;
    if (auth.selectedLanguage == 'hi') return hi;
    return en;
  }

  List<Map<String, String>> _getLessons(String lang) {
    if (lang == 'en') {
      return [
        {
          'title': '1. Smartphone Photography',
          'duration': '2 min audio lesson',
          'icon': 'camera',
          'content': 'Sit in natural sunlight when taking photos. Keep a plain wall in the background. Avoid shadows. Our AI automatically enhances the craft and creates a clean studio look.',
        },
        {
          'title': '2. Fair Pricing & Profit',
          'duration': '3 min audio lesson',
          'icon': 'price',
          'content': 'Add at least ₹85 per hour of artisan labor to your raw material costs. KalaSathi guarantees you never sell below your production costs.',
        },
        {
          'title': '3. Digital Sales & Stories',
          'duration': '2 min audio lesson',
          'icon': 'store',
          'content': 'Buyers appreciate the cultural heritage and story behind handmade craft. Speak about your process. Buyers across India and worldwide can read your craft story.',
        },
      ];
    } else if (lang == 'hi') {
      return [
        {
          'title': '१. स्मार्टफोन फोटोग्राफी',
          'duration': '२ मिनट ऑडियो पाठ',
          'icon': 'camera',
          'content': 'हस्तशिल्प की फोटो लेते समय प्राकृतिक धूप में बैठें। पीछे सादी दीवार रखें। परछाई न आने दें। हमारा एआई अपने आप सुंदर स्टूडियो बैकग्राउंड तैयार करेगा।',
        },
        {
          'title': '२. उचित मूल्य और लाभ',
          'duration': '३ मिनट ऑडियो पाठ',
          'icon': 'price',
          'content': 'कच्चे माल की लागत में प्रति घंटे कम से कम ₹८५ की मजदूरी जोड़ें। कलासाथी गारंटी देता है कि आप कभी घाटे में नहीं बेचेंगे।',
        },
        {
          'title': '३. डिजिटल बिक्री और कहानी',
          'duration': '२ मिनट ऑडियो पाठ',
          'icon': 'store',
          'content': 'ग्राहकों को हस्तकला की कहानी पसंद आती है। आपने इसे कैसे बनाया, बोलकर बताएं। देश-दुनिया के खरीदार इसे पढ़ सकते हैं।',
        },
      ];
    } else {
      return [
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
    }
  }

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
    final auth = Provider.of<AuthProvider>(context);

    final refreshTooltip = _t(auth, en: "Refresh", hi: "रिफ्रेश करें", mr: "ताजे करा");
    final customVoiceMsg = _t(auth,
        en: "In Earnings, view your verified sales, payouts, and audio lessons to grow craft sales.",
        hi: "कमाई अनुभाग में सत्यापित बिक्री, भुगतान और ऑडियो पाठ देखें।",
        mr: "कमाईच्या भागात थेट डेटाबेसमधील विक्री व उत्पन्न दिसते, आणि धड्यांच्या भागात विक्री वाढवणारे ऑडिओ आहेत.");

    return Scaffold(
      backgroundColor: AppTheme.backgroundSand,
      appBar: AppBar(
        title: Text(l10n.translate('earnings')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: refreshTooltip,
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
      floatingActionButton: VoiceHelpFab(
        customMessage: customVoiceMsg,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEarningsTab(l10n, auth),
          _buildLearnTab(l10n, auth),
        ],
      ),
    );
  }

  Widget _buildEarningsTab(AppLocalizations l10n, AuthProvider auth) {
    final token = auth.authToken;

    if (token == null || token.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              _t(auth, en: "Please log in to view earnings.", hi: "कृपया कमाई देखने के लिए लॉगिन करें।", mr: "कृपया कमाई पाहण्यासाठी लॉग इन करा."),
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
              child: Text(_t(auth, en: "Log In", hi: "लॉग इन करें", mr: "लॉग इन करा")),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.terracotta));
        }

        final data = snapshot.data ?? {};
        final netEarnings = (data['net_earnings'] as num?)?.toDouble() ?? 0.0;
        final grossSales = (data['gross_sales'] as num?)?.toDouble() ?? 0.0;
        final platformFees = (data['platform_fees'] as num?)?.toDouble() ?? 0.0;
        final refundsCancellations = (data['refunds_cancellations'] as num?)?.toDouble() ?? 0.0;
        final settledPayout = (data['settled_payout'] as num?)?.toDouble() ?? 0.0;
        final pendingPayout = (data['pending_payout'] as num?)?.toDouble() ?? 0.0;
        final totalOrders = data['total_orders'] ?? 0;
        final productsSold = data['products_sold'] ?? 0;
        final bestSellers = (data['best_sellers'] as List<dynamic>?) ?? [];
        final recentOrders = (data['recent_orders'] as List<dynamic>?) ?? [];
        final dailyTrends = (data['sales_trends_daily'] as List<dynamic>?) ?? [];
        final weeklyTrends = (data['sales_trends_weekly'] as List<dynamic>?) ?? [];
        final monthlyTrends = (data['sales_trends_monthly'] as List<dynamic>?) ?? [];

        return RefreshIndicator(
          color: AppTheme.terracotta,
          onRefresh: () async {
            _loadDashboard();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['artisan_name'] != null) ...[
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
                          Text(
                            _t(auth, en: "Verified Artisan", hi: "सत्यापित कारीगर", mr: "सत्यापित कारागीर"),
                            style: const TextStyle(fontSize: 12, color: AppTheme.successGreen, fontWeight: FontWeight.bold),
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
                          Text(
                            _t(auth, en: "Net Earnings", hi: "शुद्ध कमाई", mr: "निव्वळ कमाई"),
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 14, fontWeight: FontWeight.bold),
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
                      Text(
                        _t(auth, en: "Financial Breakdown:", hi: "वित्तीय विवरण:", mr: "रक्कमेचा हिशोब:"),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 10),
                      _buildBreakdownRow(_t(auth, en: "Gross Sales:", hi: "कुल बिक्री:", mr: "एकूण विक्री:"), "₹ ${grossSales.toStringAsFixed(0)}", AppTheme.textCharcoal),
                      const SizedBox(height: 6),
                      _buildBreakdownRow(_t(auth, en: "KalaSathi Fee (8%):", hi: "कलासाथी शुल्क (8%):", mr: "कलासाथी फी (८%):"), "- ₹ ${platformFees.toStringAsFixed(0)}", Colors.red.shade700),
                      if (refundsCancellations > 0) ...[
                        const SizedBox(height: 6),
                        _buildBreakdownRow(_t(auth, en: "Refunds / Cancelled:", hi: "रिफंड / रद्द:", mr: "रद्द / परतावा:"), "- ₹ ${refundsCancellations.toStringAsFixed(0)}", Colors.red.shade700),
                      ],
                      const Divider(height: 24),

                      // Payout Status Pills (Settled vs Pending)
                      Row(
                        children: [
                          _buildStatPill(_t(auth, en: "Settled to Bank", hi: "खाते में जमा", mr: "खात्यात जमा"), "₹ ${settledPayout.toStringAsFixed(0)}", AppTheme.successGreen),
                          const SizedBox(width: 12),
                          _buildStatPill(_t(auth, en: "Pending Payout", hi: "लंबित राशि", mr: "प्रलंबित रक्कम"), "₹ ${pendingPayout.toStringAsFixed(0)}", AppTheme.turmericDark),
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
                            Text(_t(auth, en: "Total Orders", hi: "कुल आर्डर", mr: "एकूण ऑर्डर्स"), style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
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
                            Text(_t(auth, en: "Items Sold", hi: "बिकी वस्तुएं", mr: "विकलेल्या वस्तू"), style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
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
                    Text(
                      _t(auth, en: "Sales Trends", hi: "बिक्री रुझान", mr: "विक्री आलेख"),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        items: [
                          DropdownMenuItem(value: 'daily', child: Text(_t(auth, en: "Daily", hi: "दैनिक", mr: "दैनिक"), style: const TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'weekly', child: Text(_t(auth, en: "Weekly", hi: "साप्ताहिक", mr: "साप्ताहिक"), style: const TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'monthly', child: Text(_t(auth, en: "Monthly", hi: "मासिक", mr: "मासिक"), style: const TextStyle(fontSize: 12))),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedTrendPeriod = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildTrendsSection(dailyTrends, weeklyTrends, monthlyTrends, auth),
                const SizedBox(height: 24),

                // Best-Selling Products Section
                if (bestSellers.isNotEmpty) ...[
                  Text(
                    _t(auth, en: "Best-Selling Products", hi: "शीर्ष बिक्री उत्पाद", mr: "सर्वाधिक विक्री झालेली उत्पादने"),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        final defaultTitle = _t(auth, en: 'Product', hi: 'उत्पाद', mr: 'उत्पादन');
                        final soldSuffix = _t(auth, en: 'units sold', hi: 'वस्तुएं बिकीं', mr: 'वस्तू विकल्या');
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
                          title: Text(item['title'] ?? defaultTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${item['quantity_sold'] ?? item['units_sold'] ?? 0} $soldSuffix"),
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
                  Text(
                    _t(auth, en: "Recent Orders", hi: "हाल के आर्डर", mr: "नुकत्याच आलेल्या ऑर्डर्स"),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        final ordCity = ord['shipping_city'] ?? ord['buyer_city'] ?? _t(auth, en: 'India', hi: 'भारत', mr: 'भारत');
                        final orderPrefix = _t(auth, en: 'Order', hi: 'आर्डर', mr: 'ऑर्डर');

                        return ListTile(
                          title: Text("$orderPrefix #$ordId", style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildTrendsSection(List<dynamic> daily, List<dynamic> weekly, List<dynamic> monthly, AuthProvider auth) {
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
        child: Text(
          _t(auth,
              en: "No sales trend data yet. Graph will appear as orders arrive.",
              hi: "वर्तमान में कोई बिक्री डेटा उपलब्ध नहीं है। आर्डर आने पर ग्राफ दिखाई देगा।",
              mr: "सध्या कोणताही विक्री डेटा उपलब्ध नाही. नवीन ऑर्डर्स आल्यावर आलेख दिसेल."),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textMuted),
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
          Text(
            _t(auth,
                en: "* This trend is based directly on approved orders.",
                hi: "* यह रुझान सीधे स्वीकृत आर्डरों पर आधारित है।",
                mr: "* हा आलेख थेट मंजूर झालेल्या ऑर्डर्सवर आधारित आहे."),
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
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

  Widget _buildLearnTab(AppLocalizations l10n, AuthProvider auth) {
    final lessons = _getLessons(auth.selectedLanguage);
    final listenPrompt = _t(auth, en: "Listen to this audio lesson", hi: "यह पाठ ऑडियो में सुनें", mr: "हा धडा आवाजात ऐका");

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: lessons.length,
      itemBuilder: (context, index) {
        final lesson = lessons[index];
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
                label: Text(listenPrompt),
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
