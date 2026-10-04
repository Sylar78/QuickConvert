import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../services/services.dart';
import '../history/history_screen.dart';
import '../premium/premium_screen.dart';
import '../settings/settings_screen.dart';
import 'convert_tab.dart';

/// La coque de l'app : quatre onglets, une barre en bas sur téléphone et un
/// rail latéral dès que l'écran est large — ce qui règle le cas du web en
/// plein écran, où tout s'étirait jusqu'ici.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  static const _destinations = [
    (icon: Icons.swap_horiz_rounded, label: 'Convertir'),
    (icon: Icons.history_rounded, label: 'Historique'),
    (icon: Icons.workspace_premium_rounded, label: 'Premium'),
    (icon: Icons.settings_rounded, label: 'Réglages'),
  ];

  void _select(int index) => setState(() => _selectedTab = index);

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
    if (_shared.incoming.value != null && _selectedTab != 0) _select(0);
  }

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _selectedTab,
      children: [
        ConvertTab(onSeeHistory: () => _select(1)),
        const HistoryScreen(),
        const PremiumScreen(),
        const SettingsScreen(),
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
                  selectedIndex: _selectedTab,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  leading: const _RailHeader(),
                  destinations: [
                    for (final d in _destinations)
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
            selectedIndex: _selectedTab,
            onDestinationSelected: _select,
            height: 68,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (final d in _destinations)
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
