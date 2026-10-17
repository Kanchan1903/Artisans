import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/screens/home_screen.dart';
import 'package:kalasathi_mobile/screens/language_picker_screen.dart';
import 'package:kalasathi_mobile/theme/app_theme.dart';
import 'package:kalasathi_mobile/widgets/voice_help_fab.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0; // 0 = Phone OTP, 1 = Profile details
  final TextEditingController _phoneController = TextEditingController(text: "+919876543210");
  final TextEditingController _otpController = TextEditingController(text: "123456");
  final TextEditingController _nameController = TextEditingController(text: "सुनीता बाई सोनवणे");
  final TextEditingController _villageController = TextEditingController(text: "पालघर (Palghar)");
  final TextEditingController _stateController = TextEditingController(text: "महाराष्ट्र (Maharashtra)");

  String _selectedCraft = "वारली चित्रकला (Warli Art)";
  bool _otpSent = false;

  final List<Map<String, dynamic>> _craftOptions = [
    {'name': 'वारली चित्रकला (Warli Art)', 'icon': Icons.palette_rounded},
    {'name': 'मातीकाम / कुंभारकाम (Pottery)', 'icon': Icons.water_drop_rounded},
    {'name': 'हथकरघा विणकाम (Handloom)', 'icon': Icons.style_rounded},
    {'name': 'लाकडी खेळणी (Woodcraft)', 'icon': Icons.toys_rounded},
    {'name': 'दागिने व मणीकाम (Jewelry)', 'icon': Icons.auto_awesome_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundSand,
      appBar: AppBar(
        title: Text(l10n.translate(_step == 0 ? 'phoneLogin' : 'artisanProfile')),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.language_rounded, color: AppTheme.indigo),
            label: Text(
              auth.selectedLanguage.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.indigo),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LanguagePickerScreen(isModal: true)),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: VoiceHelpFab(
        customMessage: _step == 0
            ? "कृपया तुमचा १० अंकी मोबाइल नंबर टाका आणि ओटीपी बटण दाबा."
            : "तुमचे नाव, हस्तकलेचा प्रकार आणि गावाचे नाव निवडून पुढे जा दाबा.",
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _step == 0 ? _buildPhoneOtpStep(l10n, auth) : _buildProfileStep(l10n, auth),
        ),
      ),
    );
  }

  Widget _buildPhoneOtpStep(AppLocalizations l10n, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Visual Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.terracottaLight,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.terracotta, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppTheme.terracotta,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_android_rounded, color: Colors.white, size: 34),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('phoneLogin'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textCharcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "फक्त फोन नंबर द्वारे सोपे लॉगिन",
                      style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Phone Input
        Text(
          l10n.translate('phoneHint'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.phone, color: AppTheme.terracotta, size: 28),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.borderWarm, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.borderWarm, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (!_otpSent)
          ElevatedButton.icon(
            icon: const Icon(Icons.send_rounded, size: 24),
            label: Text(l10n.translate('sendOtp')),
            onPressed: () async {
              await auth.sendOtp(_phoneController.text);
              setState(() {
                _otpSent = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("ओटीपी पाठवला आहे! (Test Code: 123456)"),
                  backgroundColor: AppTheme.successGreen,
                ),
              );
            },
          ),

        if (_otpSent) ...[
          const SizedBox(height: 20),
          Text(
            l10n.translate('enterOtp'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.terracotta, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.lock_open_rounded, size: 24),
            label: Text(l10n.translate('verifyOtp')),
            onPressed: () async {
              final ok = await auth.verifyOtp(
                phone: _phoneController.text,
                code: _otpController.text,
                name: _nameController.text,
              );
              if (ok) {
                setState(() {
                  _step = 1;
                });
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildProfileStep(AppLocalizations l10n, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar & Heading
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: AppTheme.indigoLight,
                child: const Icon(Icons.person_rounded, size: 54, color: AppTheme.indigo),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.terracotta,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text(
          l10n.translate('name'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 20),

        // Visual Craft Picker
        Text(
          l10n.translate('craftType'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Column(
          children: _craftOptions.map((craft) {
            final isSelected = _selectedCraft == craft['name'];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.turmericLight : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppTheme.turmericDark : AppTheme.borderWarm,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  craft['icon'] as IconData,
                  color: isSelected ? AppTheme.turmericDark : AppTheme.indigo,
                  size: 28,
                ),
                title: Text(
                  craft['name'] as String,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: AppTheme.turmericDark)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedCraft = craft['name'] as String;
                  });
                },
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        Text(
          l10n.translate('village'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _villageController,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 28),

        ElevatedButton.icon(
          icon: const Icon(Icons.arrow_forward_rounded, size: 24),
          label: Text(l10n.translate('continueBtn')),
          onPressed: () async {
            await auth.updateProfile(
              craftType: _selectedCraft,
              village: _villageController.text,
              district: "पालघर",
              state: _stateController.text,
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          },
        ),
      ],
    );
  }
}
