import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/screens/language_picker_screen.dart';
import 'package:kalasathi_mobile/screens/onboarding_screen.dart';
import 'package:kalasathi_mobile/theme/app_theme.dart';
import 'package:kalasathi_mobile/widgets/voice_help_fab.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _upiController = TextEditingController(text: "sunita.warli@okhdfcbank");
  final TextEditingController _bankAccountController = TextEditingController(text: "XXXX-XXXX-4589");
  final TextEditingController _ifscController = TextEditingController(text: "HDFC0001234");

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundSand,
      appBar: AppBar(
        title: Text(l10n.translate('settings')),
      ),
      floatingActionButton: const VoiceHelpFab(
        customMessage: "येथे तुम्ही भाषा बदलू शकता आणि बँक खात्याची माहिती नोंदवू शकता.",
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Language Switcher Tile
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderWarm),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.indigoLight,
                    child: Icon(Icons.language_rounded, color: AppTheme.indigo),
                  ),
                  title: Text(
                    l10n.translate('selectLanguage'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("${l10n.translate('currentLanguage')}: ${AppLocalizations.getLanguageNative(auth.selectedLanguage)}"),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LanguagePickerScreen(isModal: true)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Bank & UPI Details
              Text(
                l10n.translate('bankDetails'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderWarm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('upiId'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _upiController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.backgroundSand,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.translate('bankAccountNumber'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _bankAccountController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.backgroundSand,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.translate('ifscCode'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _ifscController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.backgroundSand,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      child: Text(l10n.translate('save')),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.translate('bankDetailsSaved')),
                            backgroundColor: AppTheme.successGreen,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Logout Button
              OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: Text(l10n.translate('logout'), style: const TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                onPressed: () async {
                  await auth.logout();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
