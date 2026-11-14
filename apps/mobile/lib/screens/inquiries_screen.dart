import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/services/api_service.dart';
import 'package:kalasathi_mobile/theme/app_theme.dart';
import 'package:kalasathi_mobile/widgets/voice_help_fab.dart';

class InquiriesScreen extends StatefulWidget {
  final String? initialFilter;
  const InquiriesScreen({super.key, this.initialFilter});

  @override
  State<InquiriesScreen> createState() => _InquiriesScreenState();
}

class _InquiriesScreenState extends State<InquiriesScreen> {
  List<Map<String, dynamic>> _inquiries = [];
  bool _isLoading = true;
  String _activeTab = 'all'; // all, new, scheduled, confirmed, completed, rejected
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _activeTab = widget.initialFilter!;
    }
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

  Future<void> _updateStatus(int inquiryId, String newStatus, {DateTime? scheduledAt, String? notes, String? response}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.authToken != null) {
      final res = await ApiService.updateInquiryStatus(
        token: auth.authToken!,
        inquiryId: inquiryId,
        status: newStatus,
        scheduledContactAt: scheduledAt,
        contactNotes: notes,
        artisanResponse: response,
      );
      if (res != null) {
        setState(() {
          for (int i = 0; i < _inquiries.length; i++) {
            if (_inquiries[i]['id'] == inquiryId) {
              _inquiries[i] = res;
              break;
            }
          }
        });
      }
    }
  }

  Future<void> _confirmOrder(int inquiryId, double agreedPrice, int agreedQuantity, String deliveryDetails, {String? notes}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.authToken != null) {
      final res = await ApiService.confirmInquiryOrder(
        token: auth.authToken!,
        inquiryId: inquiryId,
        agreedPrice: agreedPrice,
        agreedQuantity: agreedQuantity,
        deliveryDetails: deliveryDetails,
        contactNotes: notes,
      );
      if (res != null) {
        setState(() {
          for (int i = 0; i < _inquiries.length; i++) {
            if (_inquiries[i]['id'] == inquiryId) {
              _inquiries[i] = res;
              break;
            }
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ऑर्डर यशस्वीपणे निश्चित झाली! (Order Confirmed)'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
        }
      }
    }
  }

  Future<void> _callBuyer(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _whatsappBuyer(String phone, String productTitle) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final msg = Uri.encodeComponent("Namaste! Regarding your inquiry for '$productTitle' on KalaSathi:");
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _emailBuyer(String email, String productTitle) async {
    final uri = Uri.parse('mailto:$email?subject=Re: KalaSathi Inquiry - $productTitle');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showScheduleModal(Map<String, dynamic> inq) {
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 2));
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 24,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ग्राहक संपर्क वेळ ठरवा\n(Schedule Contact)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'तुम्ही ग्राहकाला कधी संपर्क साधू इच्छिता ते निवडा:',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              // Date & Time Selectors
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text(
                        "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 60)),
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              selectedTime.hour,
                              selectedTime.minute,
                            );
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time_rounded, size: 16),
                      label: Text(
                        selectedTime.format(context),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedTime = picked;
                            selectedDate = DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              picked.hour,
                              picked.minute,
                            );
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: 'टीप / स्मरणपत्र (Notes / Reminder)',
                  hintText: 'उदा. दुपारी ४ वाजता व्हॉट्सॲपवर फोटो पाठवणे...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.terracotta,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final inqId = inq['id'] as int;
                    Navigator.pop(ctx);
                    _updateStatus(
                      inqId,
                      'contact_scheduled',
                      scheduledAt: selectedDate,
                      notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('संपर्क शेड्यूल केला: ${selectedDate.day}/${selectedDate.month} ${selectedTime.format(context)}'),
                      ),
                    );
                  },
                  child: const Text('शेड्यूल निश्चित करा (Save Schedule)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfirmOrderModal(Map<String, dynamic> inq) {
    final priceController = TextEditingController(text: inq['agreed_price']?.toString() ?? '');
    final qtyController = TextEditingController(text: (inq['quantity_needed'] ?? inq['agreed_quantity'] ?? 1).toString());
    final deliveryController = TextEditingController(text: inq['delivery_details'] ?? '');
    final notesController = TextEditingController(text: inq['contact_notes'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 24,
          left: 20,
          right: 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ऑर्डर निश्चित करा\n(Confirm Agreed Order)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "उत्पादन: ${inq['product_title'] ?? 'Handmade Creation'}",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFC84B31)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'ठरलेली किंमत (Agreed Selling Price in ₹) *',
                  hintText: 'उदा. 2500',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'नग / प्रमाण (Quantity) *',
                  hintText: 'उदा. 2',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: deliveryController,
                decoration: InputDecoration(
                  labelText: 'वितरण तपशील (Delivery Address / Timeline) *',
                  hintText: 'उदा. स्पीड पोस्ट द्वारे, पुणे - 20 नोव्हेंबर पर्यंत...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: 'इतर तपशील / पेमेंट टीप (Payment / Notes)',
                  hintText: 'उदा. ५०% ॲडव्हान्स प्राप्त झाला...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                    final qty = int.tryParse(qtyController.text.trim()) ?? 1;
                    final delivery = deliveryController.text.trim();
                    if (price <= 0 || delivery.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('कृपया योग्य किंमत आणि वितरण तपशील प्रविष्ट करा.')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    _confirmOrder(
                      inq['id'] as int,
                      price,
                      qty,
                      delivery,
                      notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                    );
                  },
                  child: const Text('ऑर्डर निश्चित करा (Confirm Order)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter inquiries by activeTab and searchQuery
    final filtered = _inquiries.where((inq) {
      final status = inq['status'] as String? ?? 'new';
      if (_activeTab == 'new' && status != 'new') return false;
      if (_activeTab == 'scheduled' && status != 'contact_scheduled') return false;
      if (_activeTab == 'confirmed' && status != 'order_confirmed') return false;
      if (_activeTab == 'completed' && status != 'completed') return false;
      if (_activeTab == 'rejected' && status != 'rejected') return false;
      if (_activeTab == 'pending' && !['new', 'accepted', 'contact_later', 'negotiation', 'contact_scheduled'].contains(status)) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (inq['buyer_name'] as String? ?? '').toLowerCase();
        final prod = (inq['product_title'] as String? ?? '').toLowerCase();
        final msg = (inq['message_en'] as String? ?? '').toLowerCase();
        final phone = (inq['buyer_phone'] as String? ?? '').toLowerCase();
        if (!name.contains(q) && !prod.contains(q) && !msg.contains(q) && !phone.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    final newCount = _inquiries.where((i) => (i['status'] ?? 'new') == 'new').length;
    final scheduledCount = _inquiries.where((i) => i['status'] == 'contact_scheduled').length;
    final confirmedCount = _inquiries.where((i) => i['status'] == 'order_confirmed').length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundSand,
      appBar: AppBar(
        title: const Text('ग्राहक चौकशी व ऑर्डर्स'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'ताजे करा',
            onPressed: _fetchInquiries,
          ),
        ],
      ),
      floatingActionButton: const VoiceHelpFab(
        customMessage: "ग्राहकांची चौकशी स्वीकारून त्यांच्याशी संपर्क साधा, वेळ ठरवा किंवा ठरलेली ऑर्डर निश्चित करा.",
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'ग्राहक नाव, फोन किंवा उत्पादन शोधा...',
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ),

            // Filter Tabs (Horizontal Scroll)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabChip('all', 'सर्व (${_inquiries.length})'),
                    const SizedBox(width: 8),
                    _buildTabChip('new', 'नवीन ($newCount)', badgeColor: const Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    _buildTabChip('scheduled', 'शेड्यूल ($scheduledCount)', badgeColor: const Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    _buildTabChip('pending', 'प्रलंबित (Pending)'),
                    const SizedBox(width: 8),
                    _buildTabChip('confirmed', 'निश्चित ऑर्डर्स ($confirmedCount)', badgeColor: const Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    _buildTabChip('completed', 'पूर्ण (Completed)'),
                    const SizedBox(width: 8),
                    _buildTabChip('rejected', 'नाकारलेले (Rejected)'),
                  ],
                ),
              ),
            ),

            // Inquiries List
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.terracotta,
                onRefresh: _fetchInquiries,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.terracotta))
                    : filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 56, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                                  const SizedBox(height: 14),
                                  const Text(
                                    "या वर्गात कोणतीही चौकशी नाही\n(No inquiries found in this category)",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final inq = filtered[index];
                              return _buildInquiryCard(inq);
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(String key, String label, {Color? badgeColor}) {
    final isSelected = _activeTab == key;
    return InkWell(
      onTap: () => setState(() => _activeTab = key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.terracotta : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildInquiryCard(Map<String, dynamic> inq) {
    final inqId = inq['id'] as int? ?? 0;
    final status = inq['status'] as String? ?? 'new';
    final buyerName = inq['buyer_name'] as String? ?? 'Interested Buyer';
    final buyerPhone = inq['buyer_phone'] as String?;
    final buyerEmail = inq['buyer_email'] as String?;
    final productTitle = inq['product_title'] as String? ?? 'Handcrafted Creation';
    final productImg = inq['product_image_url'] as String?;
    final message = inq['message_en'] as String? ?? '';
    final translated = inq['message_translated'] as String?;
    final qty = inq['quantity_needed'] as int?;
    final scheduledAtStr = inq['scheduled_contact_at'] as String?;
    final notes = inq['contact_notes'] as String?;
    final agreedPrice = inq['agreed_price'] as num?;
    final agreedQty = inq['agreed_quantity'] as num?;
    final delivery = inq['delivery_details'] as String?;

    // Status chip colors and text
    Color statusBg = const Color(0xFFFFF2EB);
    Color statusFg = AppTheme.terracotta;
    String statusLabel = 'नवीन चौकशी (New)';

    if (status == 'accepted') {
      statusBg = const Color(0xFFEFF6FF);
      statusFg = const Color(0xFF2563EB);
      statusLabel = 'स्वीकारली (Accepted)';
    } else if (status == 'contact_scheduled') {
      statusBg = const Color(0xFFFEF3C7);
      statusFg = const Color(0xFFD97706);
      statusLabel = 'संपर्क शेड्यूल केला';
    } else if (status == 'contacted') {
      statusBg = const Color(0xFFF3E8FF);
      statusFg = const Color(0xFF7C3AED);
      statusLabel = 'संपर्क झाला (Contacted)';
    } else if (status == 'negotiation') {
      statusBg = const Color(0xFFFFFBEB);
      statusFg = const Color(0xFFB45309);
      statusLabel = 'चर्चा सुरू (Negotiation)';
    } else if (status == 'order_confirmed') {
      statusBg = const Color(0xFFDCFCE7);
      statusFg = const Color(0xFF16A34A);
      statusLabel = 'ऑर्डर निश्चित (Confirmed)';
    } else if (status == 'completed') {
      statusBg = const Color(0xFFE2E8F0);
      statusFg = const Color(0xFF475569);
      statusLabel = 'पूर्ण (Completed)';
    } else if (status == 'rejected') {
      statusBg = const Color(0xFFFEE2E2);
      statusFg = const Color(0xFFDC2626);
      statusLabel = 'नाकारले (Rejected)';
    } else if (status == 'contact_later') {
      statusBg = const Color(0xFFF1F5F9);
      statusFg = const Color(0xFF64748B);
      statusLabel = 'नंतर संपर्क करा';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: status == 'new' ? AppTheme.terracotta : const Color(0xFFE2E8F0),
          width: status == 'new' ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Status Badge & Qty
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusFg),
                ),
              ),
              if (qty != null || agreedQty != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    "नग: ${agreedQty ?? qty} units",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Product & Image Row
          Row(
            children: [
              if (productImg != null && productImg.startsWith('http'))
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    productImg,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_rounded, size: 40, color: Color(0xFF94A3B8)),
                  ),
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.palette_rounded, color: Color(0xFF94A3B8)),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "ग्राहक: $buyerName",
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Message Box
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
                Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
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

          // Scheduled Time / Order Details Display
          if (scheduledAtStr != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alarm_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "शेड्यूल वेळ: ${scheduledAtStr.replaceAll('T', ' ').split('.').first}",
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (status == 'order_confirmed' && agreedPrice != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ठरलेली रक्कम: ₹$agreedPrice ($agreedQty units)", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                  if (delivery != null && delivery.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text("डिलिव्हरी: $delivery", style: const TextStyle(fontSize: 12, color: Color(0xFF15803D))),
                  ],
                ],
              ),
            ),
          ],

          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text("टीप: $notes", style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
          ],
          const SizedBox(height: 14),

          // ─── ACTION 1: Communication Buttons (Call, WhatsApp, Email) ─────
          Row(
            children: [
              if (buyerPhone != null && buyerPhone.isNotEmpty) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _updateStatus(inqId, 'contacted');
                      _callBuyer(buyerPhone);
                    },
                    icon: const Icon(Icons.call_rounded, size: 15),
                    label: const Text('कॉल करा', style: TextStyle(fontSize: 11.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _updateStatus(inqId, 'contacted');
                      _whatsappBuyer(buyerPhone, productTitle);
                    },
                    icon: const Icon(Icons.chat_rounded, size: 15),
                    label: const Text('व्हॉट्सॲप', style: TextStyle(fontSize: 11.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
                      _updateStatus(inqId, 'contacted');
                      _emailBuyer(buyerEmail, productTitle);
                    },
                    icon: const Icon(Icons.email_rounded, size: 15),
                    label: const Text('ईमेल', style: TextStyle(fontSize: 11.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // ─── ACTION 2: Artisan Workflow Status Buttons ─────────────────
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (status == 'new') ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 15, color: Color(0xFF2563EB)),
                  label: const Text('स्वीकारा (Accept)', style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB))),
                  onPressed: () => _updateStatus(inqId, 'accepted'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule_rounded, size: 15, color: Color(0xFFD97706)),
                  label: const Text('वेळ ठरवा (Schedule)', style: TextStyle(fontSize: 11.5, color: Color(0xFFD97706))),
                  onPressed: () => _showScheduleModal(inq),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.snooze_rounded, size: 15, color: Color(0xFF64748B)),
                  label: const Text('नंतर संपर्क (Later)', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  onPressed: () => _updateStatus(inqId, 'contact_later'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 15, color: Color(0xFFDC2626)),
                  label: const Text('नाकारा (Reject)', style: TextStyle(fontSize: 11.5, color: Color(0xFFDC2626))),
                  onPressed: () => _updateStatus(inqId, 'rejected'),
                ),
              ] else if (status == 'accepted' || status == 'contacted' || status == 'contact_later' || status == 'contact_scheduled') ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule_rounded, size: 15, color: Color(0xFFD97706)),
                  label: const Text('पुन्हा वेळ ठरवा (Reschedule)', style: TextStyle(fontSize: 11.5, color: Color(0xFFD97706))),
                  onPressed: () => _showScheduleModal(inq),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.handshake_rounded, size: 15),
                  label: const Text('ऑर्डर निश्चित करा (Confirm Order)', style: TextStyle(fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showConfirmOrderModal(inq),
                ),
              ] else if (status == 'order_confirmed') ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.done_all_rounded, size: 15),
                  label: const Text('ऑर्डर पूर्ण झाली (Mark Completed)', style: TextStyle(fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _updateStatus(inqId, 'completed'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
