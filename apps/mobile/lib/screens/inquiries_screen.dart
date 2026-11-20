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
  String _activeTab = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _activeTab = widget.initialFilter!;
    }
    _fetchInquiries();
  }

  String _t(AuthProvider auth, {required String en, required String hi, required String mr}) {
    if (auth.selectedLanguage == 'mr') return mr;
    if (auth.selectedLanguage == 'hi') return hi;
    return en;
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
          final confirmMsg = _t(auth,
              en: 'Order Confirmed Successfully!',
              hi: 'आर्डर सफलतापूर्वक निश्चित किया गया!',
              mr: 'ऑर्डर यशस्वीपणे निश्चित झाली!');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(confirmMsg),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        }
      }
    }
  }

  Future<void> _callBuyer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _whatsappBuyer(String phone, String productTitle) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final msgText = _t(auth,
        en: 'Namaste! Connecting regarding your inquiry for $productTitle on KalaSathi.',
        hi: 'नमस्ते! कलासाथी पर आपके $productTitle की पूछताछ के संदर्भ में संपर्क कर रहे हैं।',
        mr: 'नमस्ते! कलासाथी वरील आपल्या $productTitle च्या चौकशीबाबत संपर्क करत आहोत.');
    final text = Uri.encodeComponent(msgText);
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _emailBuyer(String email, String productTitle) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final subject = Uri.encodeComponent(_t(auth,
        en: 'Regarding your inquiry on KalaSathi: $productTitle',
        hi: 'कलासाथी पर आपकी पूछताछ के संदर्भ में: $productTitle',
        mr: 'कलासाथी वरील चौकशी संदर्भात: $productTitle'));
    final uri = Uri.parse('mailto:$email?subject=$subject');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showScheduleModal(Map<String, dynamic> inq, AuthProvider auth) {
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 2));
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _t(auth, en: 'Schedule Customer Contact', hi: 'ग्राहक संपर्क समय निर्धारित करें', mr: 'ग्राहक संपर्क वेळ ठरवा'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _t(auth, en: 'Choose when you would like to contact the buyer:', hi: 'चुनें कि आप खरीदार से कब संपर्क करना चाहते हैं:', mr: 'तुम्ही ग्राहकाला कधी संपर्क साधू इच्छिता ते निवडा:'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
                  labelText: _t(auth, en: 'Notes / Reminder', hi: 'नोट / रिमाइंडर', mr: 'टीप / स्मरणपत्र'),
                  hintText: _t(auth, en: 'e.g. Send photos on WhatsApp at 4 PM...', hi: 'उदा. शाम 4 बजे व्हाट्सएप पर फोटो भेजें...', mr: 'उदा. दुपारी ४ वाजता व्हॉट्सॲपवर फोटो पाठवणे...'),
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
                    if (mounted) {
                      final scheduledMsg = _t(auth,
                          en: 'Contact scheduled: ${selectedDate.day}/${selectedDate.month} ${selectedTime.format(context)}',
                          hi: 'संपर्क निर्धारित: ${selectedDate.day}/${selectedDate.month} ${selectedTime.format(context)}',
                          mr: 'संपर्क शेड्यूल केला: ${selectedDate.day}/${selectedDate.month} ${selectedTime.format(context)}');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(scheduledMsg)),
                      );
                    }
                  },
                  child: Text(_t(auth, en: 'Save Schedule', hi: 'शेड्यूल सहेजें', mr: 'शेड्यूल निश्चित करा'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfirmOrderModal(Map<String, dynamic> inq, AuthProvider auth) {
    final priceController = TextEditingController(text: inq['agreed_price']?.toString() ?? inq['product_price']?.toString() ?? '');
    final qtyController = TextEditingController(text: inq['agreed_quantity']?.toString() ?? inq['quantity']?.toString() ?? '1');
    final deliveryController = TextEditingController(text: inq['delivery_details'] ?? '');
    final notesController = TextEditingController(text: inq['contact_notes'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _t(auth, en: 'Confirm Agreed Order', hi: 'तय आर्डर की पुष्टि करें', mr: 'ऑर्डर निश्चित करा'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "${_t(auth, en: 'Product:', hi: 'उत्पाद:', mr: 'उत्पादन:')} ${inq['product_title'] ?? 'Handmade Creation'}",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFC84B31)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _t(auth, en: 'Agreed Price (in ₹) *', hi: 'तय कीमत (₹ में) *', mr: 'ठरलेली किंमत (₹ मध्ये) *'),
                  hintText: '2500',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _t(auth, en: 'Quantity *', hi: 'मात्रा *', mr: 'नग / प्रमाण *'),
                  hintText: '1',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: deliveryController,
                decoration: InputDecoration(
                  labelText: _t(auth, en: 'Delivery Address / Timeline *', hi: 'वितरण पता / समय सीमा *', mr: 'वितरण तपशील (पत्ता / मुदत) *'),
                  hintText: _t(auth, en: 'e.g. By Speed Post, by Nov 20...', hi: 'उदा. स्पीड पोस्ट द्वारा, 20 नवंबर तक...', mr: 'उदा. स्पीड पोस्ट द्वारे, 20 नोव्हेंबर पर्यंत...'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: _t(auth, en: 'Payment / Notes', hi: 'भुगतान / नोट', mr: 'इतर तपशील / पेमेंट टीप'),
                  hintText: _t(auth, en: 'e.g. 50% advance received...', hi: 'उदा. 50% अग्रिम प्राप्त हुआ...', mr: 'उदा. ५०% ॲडव्हान्स प्राप्त झाला...'),
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
                      final errorMsg = _t(auth,
                          en: 'Please enter a valid price and delivery details.',
                          hi: 'कृपया सही कीमत और वितरण विवरण दर्ज करें।',
                          mr: 'कृपया योग्य किंमत आणि वितरण तपशील प्रविष्ट करा.');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(errorMsg)),
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
                  child: Text(_t(auth, en: 'Confirm Order', hi: 'आर्डर की पुष्टि करें', mr: 'ऑर्डर निश्चित करा'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
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
    final auth = Provider.of<AuthProvider>(context);

    // Apply Filter & Search
    final filtered = _inquiries.where((inq) {
      if (_activeTab != 'all' && (inq['status'] ?? 'new') != _activeTab) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (inq['buyer_name'] ?? '').toString().toLowerCase();
        final phone = (inq['buyer_phone'] ?? '').toString().toLowerCase();
        final prod = (inq['product_title'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q) || prod.contains(q);
      }
      return true;
    }).toList();

    // Counts for badge
    final newCount = _inquiries.where((e) => (e['status'] ?? 'new') == 'new').length;
    final scheduledCount = _inquiries.where((e) => e['status'] == 'contact_scheduled').length;
    final confirmedCount = _inquiries.where((e) => e['status'] == 'order_confirmed').length;

    final screenTitle = _t(auth, en: 'Customer Inquiries & Orders', hi: 'ग्राहक पूछताछ और आर्डर', mr: 'ग्राहक चौकशी व ऑर्डर्स');
    final refreshTooltip = _t(auth, en: 'Refresh', hi: 'रिफ्रेश करें', mr: 'ताजे करा');
    final voicePrompt = _t(auth,
        en: "Review customer inquiries, contact buyers directly, schedule calls, or confirm custom orders.",
        hi: "ग्राहकों की पूछताछ स्वीकार करें, उनसे सीधे संपर्क करें, समय तय करें या आर्डर की पुष्टि करें।",
        mr: "ग्राहकांची चौकशी स्वीकारून त्यांच्याशी संपर्क साधा, वेळ ठरवा किंवा ठरलेली ऑर्डर निश्चित करा.");
    final searchHint = _t(auth, en: 'Search by buyer name, phone, or product...', hi: 'ग्राहक नाम, फोन या उत्पाद खोजें...', mr: 'ग्राहक नाव, फोन किंवा उत्पादन शोधा...');

    return Scaffold(
      backgroundColor: AppTheme.backgroundSand,
      appBar: AppBar(
        title: Text(screenTitle),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: refreshTooltip,
            onPressed: _fetchInquiries,
          ),
        ],
      ),
      floatingActionButton: VoiceHelpFab(
        customMessage: voicePrompt,
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
                  hintText: searchHint,
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
                    _buildTabChip('all', "${_t(auth, en: 'All', hi: 'सभी', mr: 'सर्व')} (${_inquiries.length})"),
                    const SizedBox(width: 8),
                    _buildTabChip('new', "${_t(auth, en: 'New', hi: 'नए', mr: 'नवीन')} ($newCount)", badgeColor: const Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    _buildTabChip('scheduled', "${_t(auth, en: 'Scheduled', hi: 'शेड्यूल', mr: 'शेड्यूल')} ($scheduledCount)", badgeColor: const Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    _buildTabChip('pending', _t(auth, en: 'Pending', hi: 'लंबित', mr: 'प्रलंबित')),
                    const SizedBox(width: 8),
                    _buildTabChip('confirmed', "${_t(auth, en: 'Confirmed', hi: 'पुष्ट आर्डर', mr: 'निश्चित ऑर्डर्स')} ($confirmedCount)", badgeColor: const Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    _buildTabChip('completed', _t(auth, en: 'Completed', hi: 'पूर्ण', mr: 'पूर्ण')),
                    const SizedBox(width: 8),
                    _buildTabChip('rejected', _t(auth, en: 'Rejected', hi: 'अस्वीकृत', mr: 'नाकारलेले')),
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
                                  Text(
                                    _t(auth, en: "No inquiries found in this category", hi: "इस श्रेणी में कोई पूछताछ नहीं मिली", mr: "या वर्गात कोणतीही चौकशी नाही"),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, idx) => _buildInquiryCard(filtered[idx], auth),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.terracotta : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeColor != null && !isSelected) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInquiryCard(Map<String, dynamic> inq, AuthProvider auth) {
    final inqId = inq['id'] as int;
    final status = (inq['status'] as String? ?? 'new').toLowerCase();
    final buyerName = inq['buyer_name'] ?? _t(auth, en: 'Buyer', hi: 'ग्राहक', mr: 'ग्राहक');
    final buyerPhone = inq['buyer_phone'] as String?;
    final buyerEmail = inq['buyer_email'] as String?;
    final productTitle = inq['product_title_${auth.selectedLanguage}'] ??
        inq['product_title'] ??
        _t(auth, en: 'Handcrafted Item', hi: 'हस्तशिल्प उत्पाद', mr: 'हस्तकला उत्पादन');
    final productImg = inq['product_image'] as String?;
    final message = inq['message'] ?? '';
    final translated = inq['translated_message'] as String?;
    final agreedPrice = (inq['agreed_price'] as num?)?.toDouble();
    final agreedQty = inq['agreed_quantity'] as int?;
    final qty = inq['quantity'] as int?;
    final delivery = inq['delivery_details'] as String?;
    final notes = inq['contact_notes'] as String?;
    final scheduledAtStr = inq['scheduled_contact_at'] as String?;

    // Status chip colors and text
    Color statusBg = const Color(0xFFFFF2EB);
    Color statusFg = AppTheme.terracotta;
    String statusLabel = _t(auth, en: 'New Inquiry', hi: 'नई पूछताछ', mr: 'नवीन चौकशी');

    if (status == 'accepted') {
      statusBg = const Color(0xFFEFF6FF);
      statusFg = const Color(0xFF2563EB);
      statusLabel = _t(auth, en: 'Accepted', hi: 'स्वीकृत', mr: 'स्वीकारली');
    } else if (status == 'contact_scheduled') {
      statusBg = const Color(0xFFFEF3C7);
      statusFg = const Color(0xFFD97706);
      statusLabel = _t(auth, en: 'Scheduled', hi: 'शेड्यूल', mr: 'संपर्क शेड्यूल केला');
    } else if (status == 'contacted') {
      statusBg = const Color(0xFFF3E8FF);
      statusFg = const Color(0xFF7C3AED);
      statusLabel = _t(auth, en: 'Contacted', hi: 'संपर्क किया', mr: 'संपर्क झाला');
    } else if (status == 'negotiation') {
      statusBg = const Color(0xFFFFFBEB);
      statusFg = const Color(0xFFB45309);
      statusLabel = _t(auth, en: 'In Discussion', hi: 'चर्चा जारी', mr: 'चर्चा सुरू');
    } else if (status == 'order_confirmed') {
      statusBg = const Color(0xFFDCFCE7);
      statusFg = const Color(0xFF16A34A);
      statusLabel = _t(auth, en: 'Order Confirmed', hi: 'पुष्ट आर्डर', mr: 'ऑर्डर निश्चित');
    } else if (status == 'completed') {
      statusBg = const Color(0xFFE2E8F0);
      statusFg = const Color(0xFF475569);
      statusLabel = _t(auth, en: 'Completed', hi: 'पूर्ण', mr: 'पूर्ण');
    } else if (status == 'rejected') {
      statusBg = const Color(0xFFFEE2E2);
      statusFg = const Color(0xFFDC2626);
      statusLabel = _t(auth, en: 'Rejected', hi: 'अस्वीकृत', mr: 'नाकारले');
    } else if (status == 'contact_later') {
      statusBg = const Color(0xFFF1F5F9);
      statusFg = const Color(0xFF64748B);
      statusLabel = _t(auth, en: 'Contact Later', hi: 'बाद में संपर्क करें', mr: 'नंतर संपर्क करा');
    }

    final qtyPrefix = _t(auth, en: 'Qty:', hi: 'मात्रा:', mr: 'नग:');
    final buyerPrefix = _t(auth, en: 'Buyer:', hi: 'ग्राहक:', mr: 'ग्राहक:');

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
          // Header Row: Status badge & Inquiry ID
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(10),
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
                    "$qtyPrefix ${agreedQty ?? qty}",
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
                      "$buyerPrefix $buyerName",
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
                      "${_t(auth, en: 'Scheduled:', hi: 'शेड्यूल समय:', mr: 'शेड्यूल वेळ:')} ${scheduledAtStr.replaceAll('T', ' ').split('.').first}",
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
                  Text(
                    "${_t(auth, en: 'Agreed Price:', hi: 'तय कीमत:', mr: 'ठरलेली रक्कम:')} ₹$agreedPrice ($agreedQty ${_t(auth, en: 'units', hi: 'इकाइयां', mr: 'नग')})",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                  ),
                  if (delivery != null && delivery.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text("${_t(auth, en: 'Delivery:', hi: 'वितरण:', mr: 'डिलिव्हरी:')} $delivery", style: const TextStyle(fontSize: 12, color: Color(0xFF15803D))),
                  ],
                ],
              ),
            ),
          ],

          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text("${_t(auth, en: 'Notes:', hi: 'नोट:', mr: 'टीप:')} $notes", style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
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
                    label: Text(_t(auth, en: 'Call', hi: 'कॉल करें', mr: 'कॉल करा'), style: const TextStyle(fontSize: 11.5)),
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
                    label: Text(_t(auth, en: 'WhatsApp', hi: 'व्हाट्सएप', mr: 'व्हॉट्सॲप'), style: const TextStyle(fontSize: 11.5)),
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
                    label: Text(_t(auth, en: 'Email', hi: 'ईमेल', mr: 'ईमेल'), style: const TextStyle(fontSize: 11.5)),
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
                  label: Text(_t(auth, en: 'Accept', hi: 'स्वीकार करें', mr: 'स्वीकारा'), style: const TextStyle(fontSize: 11.5, color: Color(0xFF2563EB))),
                  onPressed: () => _updateStatus(inqId, 'accepted'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule_rounded, size: 15, color: Color(0xFFD97706)),
                  label: Text(_t(auth, en: 'Schedule', hi: 'शेड्यूल करें', mr: 'वेळ ठरवा'), style: const TextStyle(fontSize: 11.5, color: Color(0xFFD97706))),
                  onPressed: () => _showScheduleModal(inq, auth),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.snooze_rounded, size: 15, color: Color(0xFF64748B)),
                  label: Text(_t(auth, en: 'Contact Later', hi: 'बाद में संपर्क', mr: 'नंतर संपर्क'), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  onPressed: () => _updateStatus(inqId, 'contact_later'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 15, color: Color(0xFFDC2626)),
                  label: Text(_t(auth, en: 'Reject', hi: 'अस्वीकार करें', mr: 'नाकारा'), style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626))),
                  onPressed: () => _updateStatus(inqId, 'rejected'),
                ),
              ] else if (status == 'accepted' || status == 'contacted' || status == 'contact_later' || status == 'contact_scheduled') ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule_rounded, size: 15, color: Color(0xFFD97706)),
                  label: Text(_t(auth, en: 'Reschedule', hi: 'पुनः समय तय करें', mr: 'पुन्हा वेळ ठरवा'), style: const TextStyle(fontSize: 11.5, color: Color(0xFFD97706))),
                  onPressed: () => _showScheduleModal(inq, auth),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.handshake_rounded, size: 15),
                  label: Text(_t(auth, en: 'Confirm Order', hi: 'आर्डर की पुष्टि करें', mr: 'ऑर्डर निश्चित करा'), style: const TextStyle(fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showConfirmOrderModal(inq, auth),
                ),
              ] else if (status == 'order_confirmed') ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.done_all_rounded, size: 15),
                  label: Text(_t(auth, en: 'Mark Completed', hi: 'पूर्ण मार्क करें', mr: 'ऑर्डर पूर्ण झाली'), style: const TextStyle(fontSize: 11.5)),
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
