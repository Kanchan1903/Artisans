import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:kalasathi_mobile/services/voice_guidance_service.dart';
import 'package:kalasathi_mobile/theme/app_theme.dart';

class VoiceHelpFab extends StatelessWidget {
  final String? customMessage;

  const VoiceHelpFab({super.key, this.customMessage});

  @override
  Widget build(BuildContext context) {
    Provider.of<AuthProvider>(context);
    final l10n = AppLocalizations.of(context);
    final text = customMessage ?? l10n.translate('helpHome');

    return FloatingActionButton.extended(
      heroTag: 'voice_help_fab_${UniqueKey()}',
      onPressed: () {
        VoiceGuidanceService.speakPrompt(context, text);
      },
      backgroundColor: AppTheme.turmeric,
      foregroundColor: AppTheme.textCharcoal,
      elevation: 4,
      icon: const Icon(Icons.record_voice_over_rounded, size: 28),
      label: Text(
        l10n.translate('helpSpeak'),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
