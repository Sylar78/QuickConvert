import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/core.dart';
import 'providers/providers.dart';
import 'router/router.dart';

class QuickConvertApp extends StatelessWidget {
  const QuickConvertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConversionProvider()),
        ChangeNotifierProvider(create: (_) {
          final sub = SubscriptionProvider();
          sub.initialize();
          return sub;
        }),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeProvider.mode,
          onGenerateRoute: AppRouter.onGenerateRoute,
          initialRoute: AppRouter.home,
          builder: (context, child) {
            // La taille de texte du système est respectée, mais bornée : au-delà
            // de 1,3 les cartes de conversion débordent. Avant, elle était
            // simplement ignorée (`TextScaler.noScaling`), ce qui rendait l'app
            // inutilisable pour qui agrandit le texte.
            final scaler = MediaQuery.textScalerOf(context).clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.3,
            );
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scaler),
              child: child!,
            );
          },
        ),
      ),
    );
  }
}
