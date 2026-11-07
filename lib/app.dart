import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/telegram/presentation/telegram_auth_gate.dart';

class TelegramNewsReaderApp extends StatelessWidget {
  const TelegramNewsReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'خبرخوان تلگرام',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [
        Locale('fa', 'IR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const TelegramAuthGate(),
    );
  }
}
