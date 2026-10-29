import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/screens/onboarding_screen.dart';
import 'package:kalasathi_mobile/screens/home_screen.dart';
import 'package:kalasathi_mobile/services/voice_guidance_service.dart';
import 'package:kalasathi_mobile/theme/app_theme.dart';

class LanguagePickerScreen extends StatelessWidget {
  final bool isModal;

  const LanguagePickerScreen({super.key, this.isModal = false});

  static const List<Map<String, String>> languages = [
    {'code': 'en', 'name': 'English', 'native': 'English', 'region': 'India / Global'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी', 'region': 'उत्तर भारत'},
    {'code': 'mr', 'name': 'Marathi', 'native': 'मराठी', 'region': 'महाराष्ट्र'},
    {'code': 'bn', 'name': 'Bengali', 'native': 'বাংলা', 'region': 'পশ্চিমবঙ্গ'},
    {'code': 'ta', 'name': 'Tamil', 'native': 'தமிழ்', 'region': 'தமிழ்நாடு'},
    {'code': 'te', 'name': 'Telugu', 'native': 'తెలుగు', 'region': 'ఆంధ్ర / తెలంగాణ'},
    {'code': 'kn', 'name': 'Kannada', 'native': 'ಕನ್ನಡ', 'region': 'ಕರ್ನಾಟಕ'},
    {'code': 'ml', 'name': 'Malayalam', 'native': 'മലയാളം', 'region': 'കേരളം'},
    {'code': 'gu', 'name': 'Gujarati', 'native': 'ગુજરાતી', 'region': 'ગુજરાત'},
    {'code': 'pa', 'name': 'Punjabi', 'native': 'ਪੰਜਾਬੀ', 'region': 'ਪੰਜਾਬ'},
    {'code': 'or', 'name': 'Odia', 'native': 'ଓଡ଼ିଆ', 'region': 'ଓଡ଼ିଶା'},
    {'code': 'as', 'name': 'Assamese', 'native': 'অসমীয়া', 'region': 'অসম'},
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundSand,
      appBar: AppBar(
        title: Text(
          l10n.translate('selectLanguage'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: isModal
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Audio Greeting Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.turmericLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.turmeric, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppTheme.turmeric,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.volume_up_rounded, color: AppTheme.textCharcoal),
                      onPressed: () {
                        VoiceGuidanceService.speakPrompt(
                          context,
                          l10n.translate('audioGreeting'),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      l10n.translate('audioGreeting'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textCharcoal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 12 Native Script Language Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.35,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final lang = languages[index];
                  final isSelected = authProvider.selectedLanguage == lang['code'];

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        await authProvider.setLanguage(lang['code']!);
                        if (isModal) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => authProvider.isAuthenticated
                                  ? const HomeScreen()
                                  : const OnboardingScreen(),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.terracotta : AppTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppTheme.terracottaDark : AppTheme.borderWarm,
                            width: isSelected ? 2.5 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? AppTheme.terracotta.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    lang['native']!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : AppTheme.textCharcoal,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${lang['name']!} (${lang['region']!})",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isSelected ? Colors.white70 : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
