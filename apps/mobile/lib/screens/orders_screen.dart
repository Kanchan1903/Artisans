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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundSand,
      appBar: AppBar(
        title: Text(l10n.translate('orders')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "ताजे करा",
            onPressed: () {
              if (auth.authToken != null) {
                orderProvider.fetchOrders(auth.authToken!);
              }
            },
          ),
        ],
      ),
      floatingActionButton: const VoiceHelpFab(
        customMessage: "नवीन ऑर्डर आल्यावर ती स्वीकारा आणि पॅक झाल्यावर 'पॅक झाले' वर दाबा.",
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
                          const Text(
                            "सध्या कोणतीही नवीन ऑर्डर नाही.",
                            style: TextStyle(fontSize: 16, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
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
                                        "ऑर्डर #$orderId",
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
                                const Text(
                                  "ऑर्डर केलेल्या वस्तू:",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textMuted),
                                ),
                                const SizedBox(height: 6),
                                ...items.map((item) {
                                  final itemMap = item as Map<String, dynamic>;
                                  final title = itemMap['product_title'] ?? itemMap['title'] ?? 'हस्तकला उत्पादन';
                                  final qty = itemMap['quantity'] ?? 1;
                                  final unitPrice = (itemMap['unit_price'] as num?)?.toDouble() ?? 0.0;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.circle, size: 8, color: AppTheme.terracotta),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "$title  × $qty",
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                          ),
                                        ),
                                        Text(
                                          "₹ ${(unitPrice * (qty as num)).toStringAsFixed(0)}",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 12),
                              ],

                              // Total value
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("एकूण देयक रक्कम:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                  Text(
                                    "₹ ${total.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.terracotta,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),

                              // Buyer Delivery Address
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_rounded, color: AppTheme.indigo, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${l10n.translate('buyerAddress')}:",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textMuted),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "${addr['name'] ?? 'ग्राहक'}\n${addr['line1'] ?? ''}, ${addr['city'] ?? ''}, ${addr['state'] ?? ''} - ${addr['pincode'] ?? ''}",
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Status Progression & Action Buttons
                              _buildStatusActionButtons(context, orderId, status, auth.authToken ?? "", orderProvider, l10n),
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
    Color bg;
    Color fg;
    String label;
    switch (paymentStatus.toLowerCase()) {
      case 'paid':
        bg = AppTheme.successGreenLight;
        fg = AppTheme.successGreen;
        label = "PAID";
        break;
      case 'cod_pending':
        bg = AppTheme.turmericLight;
        fg = AppTheme.turmericDark;
        label = "COD PENDING";
        break;
      case 'refunded':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade700;
        label = "REFUNDED";
        break;
      default:
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        label = paymentStatus.toUpperCase();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return AppTheme.indigo;
      case 'packed':
        return AppTheme.turmericDark;
      case 'shipped':
        return AppTheme.indigoLight;
      case 'delivered':
        return AppTheme.successGreen;
      case 'cancelled':
        return Colors.red;
      default:
        return AppTheme.textMuted;
    }
  }

  Widget _buildStatusActionButtons(
    BuildContext context,
    int orderId,
    String currentStatus,
    String token,
    OrderProvider provider,
    AppLocalizations l10n,
  ) {
    if (currentStatus == 'pending') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded),
              label: Text(l10n.translate('acceptOrder')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.indigo,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                await provider.advanceOrderStatus(token, orderId, 'accepted');
                if (context.mounted) {
                  VoiceGuidanceService.speakPrompt(context, "ऑर्डर स्वीकारली आहे. आता वस्तू पॅक करा.");
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
            onPressed: () => _confirmCancelOrder(context, orderId, token, provider),
            child: const Text("रद्द करा", style: TextStyle(fontWeight: FontWeight.bold)),
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
                  VoiceGuidanceService.speakPrompt(context, "ऑर्डर पॅक झाली आहे. कुरिअरला पाठवण्यासाठी सज्ज आहे.");
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
            onPressed: () => _confirmCancelOrder(context, orderId, token, provider),
            child: const Text("रद्द करा", style: TextStyle(fontWeight: FontWeight.bold)),
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
            VoiceGuidanceService.speakPrompt(context, "ऑर्डर रवाना झाली आहे. ग्राहकाला संदेश गेला आहे.");
          }
        },
      );
    } else if (currentStatus == 'shipped') {
      return ElevatedButton.icon(
        icon: const Icon(Icons.verified_rounded),
        label: const Text("वितरित झाली म्हणून नोंदवा"),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.successGreen,
          minimumSize: const Size.fromHeight(50),
        ),
        onPressed: () async {
          await provider.advanceOrderStatus(token, orderId, 'delivered');
          if (context.mounted) {
            VoiceGuidanceService.speakPrompt(context, "ऑर्डर ग्राहकापर्यंत पोहोचली आहे. कमाई जमा झाली.");
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
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.successGreen),
            SizedBox(width: 8),
            Text(
              "यशस्वीरित्या वितरित",
              style: TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.bold),
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
          "रद्द केलेली ऑर्डर",
          style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  void _confirmCancelOrder(BuildContext context, int orderId, String token, OrderProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ऑर्डर रद्द करायची आहे का?"),
        content: const Text("ऑर्डर रद्द केल्यास ग्राहकाला पैसे परत मिळतील आणि वस्तू पुन्हा साठ्यात जोडली जाईल."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("मागे जा"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.cancelOrder(token, orderId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? "ऑर्डर रद्द झाली व साठ्यात परत जोडली गेली." : "ऑर्डर रद्द करण्यात त्रुटी आली."),
                    backgroundColor: success ? AppTheme.textCharcoal : Colors.red,
                  ),
                );
              }
            },
            child: const Text("होय, रद्द करा"),
          ),
        ],
      ),
    );
  }
}
