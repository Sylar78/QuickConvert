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
        // L'abonnement accordé par le store est écrit par `SubscriptionProvider`
        // puis relu par `AuthProvider` : c'est ce branchement qui manquait, et
        // sans lui un achat réel ne donnait jamais le Premium.
        // `lazy: false` : la connexion au store doit avoir lieu au lancement,
        // pas à l'ouverture de l'écran Premium. C'est elle qui récupère un
        // paiement différé validé pendant que l'app était fermée, et qui
        // vérifie que l'abonnement gardé en local est toujours actif.
        ChangeNotifierProvider(
          lazy: false,
          create: (context) => SubscriptionProvider(
            onEntitlementChanged: context.read<AuthProvider>().syncEntitlement,
          )..initialize(),
        ),
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
