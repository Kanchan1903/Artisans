import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/screens/home_screen.dart';
import 'package:kalasathi_mobile/screens/language_picker_screen.dart';
import 'package:kalasathi_mobile/widgets/voice_help_fab.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.initialPhone, this.popOnSuccess = false});

  final String? initialPhone;
  final bool popOnSuccess;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isSignUp = true;
  bool _agreeTerms = true;
  bool _obscurePassword = true;

  final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _identifierController =
      TextEditingController(text: widget.initialPhone ?? "+919800000001");
  final TextEditingController _passwordController = TextEditingController(text: "kalasathi123");

  String? _lastLanguage;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context);
    final l10n = AppLocalizations.of(context);
    if (_lastLanguage != auth.selectedLanguage) {
      _lastLanguage = auth.selectedLanguage;
      final localizedName = l10n.translate('artisanNameLocalized');
      if (_nameController.text.isEmpty ||
          _nameController.text == "Sunita Bai Sonawane" ||
          _nameController.text.contains("सुनीता") ||
          _nameController.text.contains("ಸುನೀತಾ") ||
          _nameController.text.contains("Sunita")) {
        _nameController.text = localizedName;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth, AppLocalizations l10n) async {
    if (_isSignUp && !_agreeTerms) {
      setState(() {
        _errorMessage = l10n.translate('agreeTerms');
      });
      return;
    }

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (identifier.isEmpty || password.isEmpty || (_isSignUp && name.isEmpty)) {
      setState(() {
        _errorMessage = "Please fill in all required fields";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await auth.verifyOtp(
      phone: identifier.startsWith('+') ? identifier : '+91$identifier',
      code: "123456",
      name: _isSignUp ? name : (auth.artisanProfile?['name'] ?? name),
    );

    setState(() {
      _isLoading = false;
    });

    if (success && mounted && widget.popOnSuccess) {
      Navigator.pop(context);
    } else if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (mounted) {
      setState(() {
        _errorMessage = auth.lastAuthError ??
            "Authentication failed. Please check details or use Demo Login.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<AuthProvider>(context);

    final currentLang = auth.selectedLanguage;

    return Scaffold(
      body: Stack(
        children: [
          // ─── Violet Gradient Aesthetic Background ─────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF8B5CF6), // Soft Violet Top
                  Color(0xFF7C3AED), // Purple Accent
                  Color(0xFF9333EA), // Deep Fuchsia/Violet
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Top Left & Bottom Right Botanical Motif Silhouettes
          Positioned(
            top: -30,
            left: -30,
            child: Opacity(
              opacity: 0.22,
              child: Image.asset(
                'assets/images/login_pot.png',
                width: 180,
                errorBuilder: (_, __, ___) => const Icon(Icons.local_florist, size: 140, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            right: -30,
            child: Opacity(
              opacity: 0.18,
              child: Image.asset(
                'assets/images/login_pot.png',
                width: 220,
                errorBuilder: (_, __, ___) => const Icon(Icons.spa, size: 160, color: Colors.white),
              ),
            ),
          ),

          // ─── Center Glass/Floating Card ──────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440),
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 30,
                        spreadRadius: 2,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Card Header
                      Text(
                        _isSignUp ? l10n.translate('createAccount') : l10n.translate('signIn'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1B4B), // Dark Indigo / Violet
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.translate('joinSubtitle'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── Language Selector Pill Bar ──────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Row(
                          children: [
                            // English Pill
                            _buildLangPill(
                              code: 'en',
                              label: 'English',
                              icon: Icons.language,
                              isSelected: currentLang == 'en',
                              onTap: () => auth.setLanguage('en'),
                            ),
                            // Hindi Pill
                            _buildLangPill(
                              code: 'hi',
                              label: 'हिन्दी',
                              isSelected: currentLang == 'hi',
                              onTap: () => auth.setLanguage('hi'),
                            ),
                            // Marathi Pill
                            _buildLangPill(
                              code: 'mr',
                              label: 'मराठी',
                              isSelected: currentLang == 'mr',
                              onTap: () => auth.setLanguage('mr'),
                            ),
                            // More Languages (12 Indian languages)
                            IconButton(
                              icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF7C3AED), size: 20),
                              tooltip: "All 12 Languages",
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LanguagePickerScreen(isModal: true)),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Error message if any
                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF87171)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ─── Input Fields ──────────────────────────────────────────
                      if (_isSignUp) ...[
                        _buildInputField(
                          controller: _nameController,
                          hintText: l10n.translate('fullName'),
                          prefixIcon: Icons.person_rounded,
                        ),
                        const SizedBox(height: 14),
                      ],

                      _buildInputField(
                        controller: _identifierController,
                        hintText: l10n.translate('phoneOrEmail'),
                        prefixIcon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),

                      _buildInputField(
                        controller: _passwordController,
                        hintText: l10n.translate('password'),
                        prefixIcon: Icons.lock_rounded,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: const Color(0xFF6B7280),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Terms Agreement Checkbox
                      if (_isSignUp) ...[
                        Row(
                          children: [
                            Checkbox(
                              value: _agreeTerms,
                              activeColor: const Color(0xFF7C3AED),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                              onChanged: (val) {
                                setState(() {
                                  _agreeTerms = val ?? true;
                                });
                              },
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _agreeTerms = !_agreeTerms),
                                child: Text(
                                  l10n.translate('agreeTerms'),
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ─── Primary Gradient Action Button ─────────────────────────
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF8B5CF6), // Violet
                              Color(0xFF6366F1), // Indigo
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withOpacity(0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _submit(auth, l10n),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _isSignUp ? l10n.translate('createAccount') : l10n.translate('signIn'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Divider "OR"
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              l10n.translate('or'),
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Toggle between Login & Signup
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isSignUp = !_isSignUp;
                            _errorMessage = null;
                          });
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isSignUp
                                  ? "${l10n.translate('alreadyHaveAccount')} "
                                  : "${l10n.translate('dontHaveAccount')} ",
                              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                            ),
                            Text(
                              _isSignUp ? "${l10n.translate('signIn')} →" : "${l10n.translate('createAccount')} →",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: const VoiceHelpFab(
        customMessage: "खाते तयार करण्यासाठी तुमचे नाव व मोबाइल नंबर टाका किंवा त्वरित साइन इन करा.",
      ),
    );
  }

  Widget _buildLangPill({
    required String code,
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF6B7280)),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.normal),
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 6, right: 8),
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFEDE9FE),
              shape: BoxShape.circle,
            ),
            child: Icon(prefixIcon, color: Color(0xFF7C3AED), size: 18),
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
