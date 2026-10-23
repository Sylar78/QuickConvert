import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/core.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../history/history_screen.dart';
import '../premium/premium_screen.dart';
import '../settings/settings_screen.dart';
import 'convert_tab.dart';

/// La coque de l'app : quatre onglets (trois sur iPhone sans offre Premium), une barre en bas sur téléphone et un
/// rail latéral dès que l'écran est large — ce qui règle le cas du web en
/// plein écran, où tout s'étirait jusqu'ici.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _Tab _selected = _Tab.convert;

  void _select(_Tab tab) => setState(() => _selected = tab);

  final _shared = SharedFilesService();

  @override
  void initState() {
    super.initState();
    _shared.incoming.addListener(_onShared);
    _shared.start();
  }

  @override
  void dispose() {
    _shared.incoming.removeListener(_onShared);
    super.dispose();
  }

  /// Un fichier partagé depuis une autre app ramène à l'écran de conversion,
  /// qui le prend en charge.
  void _onShared() {
    if (_shared.incoming.value != null && _selected != _Tab.convert) {
      _select(_Tab.convert);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sur iPhone, pas d'onglet Premium tant que l'App Store ne fournit aucune
    // offre : voir `SubscriptionProvider.canSellPremium`. Un abonné le garde,
    // pour gérer son abonnement.
    final showPremium = context.watch<AuthProvider>().user.isPremium ||
        context.watch<SubscriptionProvider>().canSellPremium;
    final tabs = [
      for (final tab in _Tab.values)
        if (tab != _Tab.premium || showPremium) tab,
    ];
    final selected = tabs.contains(_selected) ? _selected : _Tab.convert;
    final selectedIndex = tabs.indexOf(selected);
    void onSelected(int index) => _select(tabs[index]);

    final body = IndexedStack(
      index: selectedIndex,
      children: [
        // La clé garde l'état de chaque onglet quand Premium apparaît ou
        // disparaît et décale les autres.
        for (final tab in tabs)
          KeyedSubtree(
            key: ValueKey(tab),
            child: switch (tab) {
              _Tab.convert =>
                ConvertTab(onSeeHistory: () => _select(_Tab.history)),
              _Tab.history => const HistoryScreen(),
              _Tab.premium => const PremiumScreen(),
              _Tab.settings => const SettingsScreen(),
            },
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.expanded;

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onSelected,
                  labelType: NavigationRailLabelType.all,
                  leading: const _RailHeader(),
                  destinations: [
                    for (final d in tabs)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                VerticalDivider(width: 1, color: context.palette.border),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            height: 68,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (final d in tabs)
                NavigationDestination(
                  icon: Icon(d.icon),
                  label: d.label,
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _Tab {
  convert(Icons.swap_horiz_rounded, 'Convertir'),
  history(Icons.history_rounded, 'Historique'),
  premium(Icons.workspace_premium_rounded, 'Premium'),
  settings(Icons.settings_rounded, 'Réglages');

  const _Tab(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _RailHeader extends StatelessWidget {
  const _RailHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Icon(
        Icons.bolt_rounded,
        color: context.colors.primary,
        size: 26,
        semanticLabel: AppConstants.appName,
      ),
    );
  }
}
