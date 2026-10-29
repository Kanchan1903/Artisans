import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:kalasathi_mobile/providers/auth_provider.dart';
import 'package:kalasathi_mobile/providers/product_wizard_provider.dart';
import 'package:kalasathi_mobile/providers/order_provider.dart';
import 'package:kalasathi_mobile/screens/language_picker_screen.dart';
import 'package:kalasathi_mobile/screens/home_screen.dart';
import 'package:kalasathi_mobile/theme/app_theme.dart';

import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductWizardProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: const KalaSathiApp(),
    ),
  );
}

class KalaSathiApp extends StatelessWidget {
  const KalaSathiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return MaterialApp(
      title: 'KalaSathi Artisan App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      locale: Locale(auth.selectedLanguage),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        for (final supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == auth.selectedLanguage) {
            return supportedLocale;
          }
        }
        return Locale(auth.selectedLanguage);
      },
      home: auth.isAuthenticated ? const HomeScreen() : const LanguagePickerScreen(),
    );
  }
}
