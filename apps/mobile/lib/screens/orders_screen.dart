import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/providers/order_provider.dart';
import 'package:kalasathi_mobile/services/voice_guidance_service.dart';
import 'package:kalasathi_mobile/theme/app_theme.dart';
import 'package:kalasathi_mobile/widgets/voice_help_fab.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.authToken != null && auth.authToken!.isNotEmpty) {
        Provider.of<OrderProvider>(context, listen: false).fetchOrders(auth.authToken!);
      }
    });
  }

  String _t(AuthProvider auth, {required String en, required String hi, required String mr}) {
    if (auth.selectedLanguage == 'mr') return mr;
    if (auth.selectedLanguage == 'hi') return hi;
    return en;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);

    final refreshTooltip = _t(auth, en: "Refresh", hi: "रिफ्रेश करें", mr: "ताजे करा");
    final customVoiceMsg = _t(auth,
        en: "Accept new orders when they arrive, and tap Pack when ready for shipping.",
        hi: "नया आर्डर आने पर उसे स्वीकार करें और पैक होने पर 'पैक करें' पर दबाएं।",
        mr: "नवीन ऑर्डर आल्यावर ती स्वीकारा आणि पॅक झाल्यावर 'पॅक झाले' वर दाबा.");
    final emptyOrderMsg = _t(auth,
        en: "No new orders currently.",
        hi: "वर्तमान में कोई नया आर्डर नहीं है।",
        mr: "सध्या कोणतीही नवीन ऑर्डर नाही.");

    return Scaffold(
      backgroundColor: AppTheme.backgroundSand,
      appBar: AppBar(
        title: Text(l10n.translate('orders')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: refreshTooltip,
            onPressed: () {
              if (auth.authToken != null) {
                orderProvider.fetchOrders(auth.authToken!);
              }
            },
          ),
        ],
      ),
      floatingActionButton: VoiceHelpFab(
        customMessage: customVoiceMsg,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.terracotta,
          onRefresh: () async {
            if (auth.authToken != null) {
              await orderProvider.fetchOrders(auth.authToken!);
            }
          },
          child: orderProvider.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.terracotta))
              : orderProvider.orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.textMuted.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(
                            emptyOrderMsg,
                            style: const TextStyle(fontSize: 16, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: orderProvider.orders.length,
                      itemBuilder: (context, index) {
                        final order = orderProvider.orders[index];
                        final orderId = order['id'] as int;
                        final status = order['status'] as String? ?? 'pending';
                        final paymentStatus = order['payment_status'] as String? ?? 'paid';
                        final total = (order['total'] as num?)?.toDouble() ?? 0.0;
                        final addr = order['shipping_address'] as Map<String, dynamic>? ?? {};
                        final items = (order['items'] as List<dynamic>?) ?? [];
                        final createdAt = order['created_at'] as String? ?? '';

                        final orderPrefix = _t(auth, en: "Order", hi: "आर्डर", mr: "ऑर्डर");
                        final orderedItemsHeader = _t(auth, en: "Ordered Items:", hi: "आर्डर किए गए उत्पाद:", mr: "ऑर्डर केलेल्या वस्तू:");
                        final defaultItemTitle = _t(auth, en: "Handcrafted Item", hi: "हस्तशिल्प उत्पाद", mr: "हस्तकला उत्पादन");
                        final totalPayableLabel = _t(auth, en: "Total Payable Amount:", hi: "कुल देय राशि:", mr: "एकूण देयक रक्कम:");
                        final defaultCustomerName = _t(auth, en: "Customer", hi: "ग्राहक", mr: "ग्राहक");

                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: status == 'pending' ? AppTheme.terracotta : AppTheme.borderWarm,
                              width: status == 'pending' ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order Header: Order ID + Status badges
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "$orderPrefix #$orderId",
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      if (createdAt.isNotEmpty)
                                        Text(
                                          createdAt.substring(0, createdAt.length > 10 ? 10 : createdAt.length),
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                        ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      // Payment Status Badge
                                      _buildPaymentBadge(paymentStatus),
                                      const SizedBox(width: 8),
                                      // Fulfilment Status Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: _statusColor(status).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            color: _statusColor(status),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 24),

                              // Products in this Order
                              if (items.isNotEmpty) ...[
                                Text(
                                  orderedItemsHeader,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textMuted),
                                ),
                                const SizedBox(height: 8),
                                ...items.map((item) {
                                  final itemMap = item as Map<String, dynamic>;
                                  final title = itemMap['product_title_${auth.selectedLanguage}'] ??
                                      itemMap['product_title'] ??
                                      itemMap['title'] ??
                                      defaultItemTitle;
                                  final qty = itemMap['quantity'] ?? 1;
                                  final itemPrice = (itemMap['price'] as num?)?.toDouble() ?? 0.0;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            "$title  x$qty",
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          "₹ ${(itemPrice * qty).toStringAsFixed(0)}",
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const Divider(height: 24),
                              ],

                              // Total Price
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(totalPayableLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                  Text(
                                    "₹ ${total.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.terracotta,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Shipping Details & Delivery address
                              if (addr.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.backgroundSand,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, color: AppTheme.terracotta, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "${addr['name'] ?? defaultCustomerName}\n${addr['line1'] ?? ''}, ${addr['city'] ?? ''}, ${addr['state'] ?? ''} - ${addr['pincode'] ?? ''}",
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Action Button Flow (Pending -> Accepted -> Packed -> Shipped)
                              _buildActionButtons(context, orderId, status, auth.authToken ?? '', orderProvider, l10n, auth),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }

  Widget _buildPaymentBadge(String paymentStatus) {
    final isPaid = paymentStatus.toLowerCase() == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid ? AppTheme.successGreenLight : AppTheme.turmericLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
            size: 12,
            color: isPaid ? AppTheme.successGreen : AppTheme.turmericDark,
          ),
          const SizedBox(width: 4),
          Text(
            isPaid ? "PAID" : "COD",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isPaid ? AppTheme.successGreen : AppTheme.turmericDark,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppTheme.terracotta;
      case 'accepted':
        return AppTheme.turmericDark;
      case 'packed':
        return AppTheme.indigo;
      case 'shipped':
        return AppTheme.successGreen;
      case 'delivered':
        return AppTheme.successGreen;
      case 'cancelled':
        return Colors.red;
      default:
        return AppTheme.textMuted;
    }
  }

  Widget _buildActionButtons(
    BuildContext context,
    int orderId,
    String currentStatus,
    String token,
    OrderProvider provider,
    AppLocalizations l10n,
    AuthProvider auth,
  ) {
    if (currentStatus == 'pending') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: Text(l10n.translate('acceptOrder')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.indigo,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                await provider.advanceOrderStatus(token, orderId, 'accepted');
                if (context.mounted) {
                  final prompt = _t(auth,
                      en: "Order accepted. Please pack the item.",
                      hi: "आर्डर स्वीकार कर लिया गया है। अब उत्पाद पैक करें।",
                      mr: "ऑर्डर स्वीकारली आहे. आता वस्तू पॅक करा.");
                  VoiceGuidanceService.speakPrompt(context, prompt);
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
            onPressed: () => _confirmCancelOrder(context, orderId, token, provider, auth),
            child: Text(_t(auth, en: "Cancel", hi: "रद्द करें", mr: "रद्द करा"), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    } else if (currentStatus == 'accepted') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.inventory_2_rounded),
              label: Text(l10n.translate('packOrder')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.turmericDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                await provider.advanceOrderStatus(token, orderId, 'packed');
                if (context.mounted) {
                  final prompt = _t(auth,
                      en: "Order packed and ready for courier pickup.",
                      hi: "आर्डर पैक हो गया है और कूरियर के लिए तैयार है।",
                      mr: "ऑर्डर पॅक झाली आहे. कुरिअरला पाठवण्यासाठी सज्ज आहे.");
                  VoiceGuidanceService.speakPrompt(context, prompt);
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
            onPressed: () => _confirmCancelOrder(context, orderId, token, provider, auth),
            child: Text(_t(auth, en: "Cancel", hi: "रद्द करें", mr: "रद्द करा"), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    } else if (currentStatus == 'packed') {
      return ElevatedButton.icon(
        icon: const Icon(Icons.local_shipping_rounded),
        label: Text(l10n.translate('shipOrder')),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.indigo,
          minimumSize: const Size.fromHeight(50),
        ),
        onPressed: () async {
          await provider.advanceOrderStatus(token, orderId, 'shipped');
          if (context.mounted) {
            final prompt = _t(auth,
                en: "Order shipped. Customer notified.",
                hi: "आर्डर रवाना हो गया है। ग्राहक को सूचित कर दिया गया है।",
                mr: "ऑर्डर रवाना झाली आहे. ग्राहकाला संदेश गेला आहे.");
            VoiceGuidanceService.speakPrompt(context, prompt);
          }
        },
      );
    } else if (currentStatus == 'shipped') {
      return ElevatedButton.icon(
        icon: const Icon(Icons.verified_rounded),
        label: Text(_t(auth, en: "Mark as Delivered", hi: "वितरित मार्क करें", mr: "वितरित झाली म्हणून नोंदवा")),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.successGreen,
          minimumSize: const Size.fromHeight(50),
        ),
        onPressed: () async {
          await provider.advanceOrderStatus(token, orderId, 'delivered');
          if (context.mounted) {
            final prompt = _t(auth,
                en: "Order delivered. Earnings credited.",
                hi: "आर्डर ग्राहक तक पहुँच गया है। कमाई जमा हो गई है।",
                mr: "ऑर्डर ग्राहकापर्यंत पोहोचली आहे. कमाई जमा झाली.");
            VoiceGuidanceService.speakPrompt(context, prompt);
          }
        },
      );
    } else if (currentStatus == 'delivered') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.successGreenLight,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.successGreen),
            const SizedBox(width: 8),
            Text(
              _t(auth, en: "Successfully Delivered", hi: "सफलतापूर्वक वितरित", mr: "यशस्वीरित्या वितरित"),
              style: const TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    } else if (currentStatus == 'cancelled') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          _t(auth, en: "Cancelled Order", hi: "रद्द आर्डर", mr: "रद्द केलेली ऑर्डर"),
          style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  void _confirmCancelOrder(BuildContext context, int orderId, String token, OrderProvider provider, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t(auth, en: "Cancel this order?", hi: "क्या यह आर्डर रद्द करना चाहते हैं?", mr: "ऑर्डर रद्द करायची आहे का?")),
        content: Text(_t(auth,
            en: "Cancelling will refund the buyer and restore product stock.",
            hi: "रद्द करने पर खरीदार को पैसे वापस मिलेंगे और उत्पाद स्टॉक में वापस आ जाएगा।",
            mr: "ऑर्डर रद्द केल्यास ग्राहकाला पैसे परत मिळतील आणि वस्तू पुन्हा साठ्यात जोडली जाईल.")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t(auth, en: "Go Back", hi: "वापस जाएं", mr: "मागे जा")),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.cancelOrder(token, orderId);
              if (mounted) {
                final msg = success
                    ? _t(auth, en: "Order cancelled and stock restored.", hi: "आर्डर रद्द हुआ और स्टॉक बहाल हुआ।", mr: "ऑर्डर रद्द झाली व साठ्यात परत जोडली गेली.")
                    : _t(auth, en: "Error cancelling order.", hi: "आर्डर रद्द करने में त्रुटि हुई।", mr: "ऑर्डर रद्द करण्यात त्रुटी आली.");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    backgroundColor: success ? AppTheme.textCharcoal : Colors.red,
                  ),
                );
              }
            },
            child: Text(_t(auth, en: "Yes, Cancel", hi: "हाँ, रद्द करें", mr: "होय, रद्द करा")),
          ),
        ],
      ),
    );
  }
}
