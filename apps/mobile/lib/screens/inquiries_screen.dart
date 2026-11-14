import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/services/api_service.dart';
import 'package:kalasathi_mobile/theme/app_theme.dart';
import 'package:kalasathi_mobile/widgets/voice_help_fab.dart';

class InquiriesScreen extends StatefulWidget {
  const InquiriesScreen({super.key});

  @override
  State<InquiriesScreen> createState() => _InquiriesScreenState();
}

class _InquiriesScreenState extends State<InquiriesScreen> {
  List<Map<String, dynamic>> _inquiries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInquiries();
  }

  Future<void> _fetchInquiries() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.authToken != null && auth.authToken!.isNotEmpty) {
      final list = await ApiService.getArtisanInquiries(auth.authToken!);
      if (mounted) {
        setState(() {
          _inquiries = list;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsRead(int inquiryId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.authToken != null) {
      await ApiService.markInquiryRead(token: auth.authToken!, inquiryId: inquiryId);
      setState(() {
        for (var inq in _inquiries) {
          if (inq['id'] == inquiryId) {
            inq['is_read'] = true;
          }
        }
      });
    }
  }

  Future<void> _callBuyer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _emailBuyer(String email, String productTitle) async {
    final uri = Uri.parse('mailto:$email?subject=Re: Inquiry for $productTitle');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundSand,
      appBar: AppBar(
        title: const Text('ग्राहक चौकशी (Buyer Inquiries)'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchInquiries,
          ),
        ],
      ),
      floatingActionButton: const VoiceHelpFab(
        customMessage: "येथे ग्राहकांनी विचारलेली चौकशी दिसते. त्यांना फोन किंवा ईमेल द्वारे थेट संपर्क करा.",
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.terracotta,
          onRefresh: _fetchInquiries,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.terracotta))
              : _inquiries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mark_email_unread_outlined, size: 64, color: AppTheme.textMuted.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            const Text(
                              "अद्याप कोणतीही चौकशी नाही\n(No buyer inquiries yet)",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "वेबसाईटवरून ग्राहकांनी संपर्क साधल्यास ती माहिती येथे दिसेल.",
                              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _inquiries.length,
                      itemBuilder: (context, index) {
                        final inq = _inquiries[index];
                        final inqId = inq['id'] as int? ?? 0;
                        final buyerName = inq['buyer_name'] as String? ?? 'Interested Buyer';
                        final buyerPhone = inq['buyer_phone'] as String?;
                        final buyerEmail = inq['buyer_email'] as String?;
                        final productTitle = inq['product_title'] as String? ?? 'Handcrafted Creation';
                        final message = inq['message_en'] as String? ?? '';
                        final translated = inq['message_translated'] as String?;
                        final qty = inq['quantity_needed'] as int?;
                        final isRead = inq['is_read'] as bool? ?? false;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isRead ? AppTheme.borderWarm : AppTheme.terracotta,
                              width: isRead ? 1 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top badge & quantity
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isRead ? Colors.grey.shade100 : const Color(0xFFFFF2EB),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isRead ? Icons.mark_email_read_rounded : Icons.mark_email_unread_rounded,
                                          size: 14,
                                          color: isRead ? Colors.grey : AppTheme.terracotta,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isRead ? "वाचले (Read)" : "नवीन चौकशी (New)",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isRead ? Colors.grey : AppTheme.terracotta,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (qty != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "प्रमाण: $qty units",
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Product Name
                              Text(
                                productTitle,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Buyer details
                              Row(
                                children: [
                                  const Icon(Icons.person_rounded, size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Text(
                                    buyerName,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Message box
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message,
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                                    ),
                                    if (translated != null && translated != message) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        translated,
                                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Action buttons: Call / Email / Mark Read
                              Row(
                                children: [
                                  if (buyerPhone != null && buyerPhone.isNotEmpty) ...[
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          _markAsRead(inqId);
                                          _callBuyer(buyerPhone);
                                        },
                                        icon: const Icon(Icons.call_rounded, size: 16),
                                        label: const Text("कॉल करा (Call)", style: TextStyle(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF059669),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (buyerEmail != null && buyerEmail.isNotEmpty) ...[
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          _markAsRead(inqId);
                                          _emailBuyer(buyerEmail, productTitle);
                                        },
                                        icon: const Icon(Icons.email_rounded, size: 16),
                                        label: const Text("ईमेल (Email)", style: TextStyle(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF3B82F6),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (!isRead)
                                    IconButton(
                                      icon: const Icon(Icons.done_all_rounded, color: Color(0xFF64748B)),
                                      tooltip: "वाचले म्हणून नोंदवा",
                                      onPressed: () => _markAsRead(inqId),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
