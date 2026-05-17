import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../conversion/conversion_screen.dart';
import '../history/history_screen.dart';
import '../premium/premium_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  final List<ConversionType> _conversionTypes = [
    ConversionType.pdfToJpg,
    ConversionType.jpgToPdf,
    ConversionType.pngToJpg,
    ConversionType.docToPdf,
    ConversionType.jpgToPng,
    ConversionType.pngToPdf,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _HomeTab(conversionTypes: _conversionTypes),
          const HistoryScreen(),
          const PremiumScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Accueil',
                isSelected: _selectedTab == 0,
                onTap: () => setState(() => _selectedTab = 0),
              ),
              _NavItem(
                icon: Icons.history_rounded,
                label: 'Historique',
                isSelected: _selectedTab == 1,
                onTap: () => setState(() => _selectedTab = 1),
              ),
              _NavItem(
                icon: Icons.bolt_rounded,
                label: 'Premium',
                isSelected: _selectedTab == 2,
                onTap: () => setState(() => _selectedTab = 2),
                isPremiumTab: true,
              ),
              _NavItem(
                icon: Icons.settings_rounded,
                label: 'Réglages',
                isSelected: _selectedTab == 3,
                onTap: () => setState(() => _selectedTab = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final List<ConversionType> conversionTypes;

  const _HomeTab({required this.conversionTypes});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QuickConvert',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1),
                          Text(
                            'Convertis instantanément 🚀',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
                        ],
                      ),
                      if (user.isPremium)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: AppColors.premiumGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Premium',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Bannière premium si limite proche
          if (!user.isPremium && user.remainingConversions <= 3)
            SliverToBoxAdapter(
              child: PremiumBanner(
                remainingConversions: user.remainingConversions,
                onUpgrade: () => Navigator.pushNamed(context, '/premium'),
              ).animate().fadeIn(delay: 200.ms),
            ),

          // Titre section
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Choisir une conversion',
                style: Theme.of(context).textTheme.headlineSmall,
              ).animate().fadeIn(delay: 150.ms),
            ),
          ),

          // Grille de conversions
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.9,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final type = conversionTypes[index];
                  return ConversionCard(
                    type: type,
                    index: index,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConversionScreen(type: type),
                      ),
                    ),
                  );
                },
                childCount: conversionTypes.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isPremiumTab;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isPremiumTab = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPremiumTab
        ? AppColors.premium
        : isSelected
            ? AppColors.primary
            : AppColors.textHint;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppConstants.shortAnim,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isPremiumTab ? AppColors.premiumLight : AppColors.surfaceVariant)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
