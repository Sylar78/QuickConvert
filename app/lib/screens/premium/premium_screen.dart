import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isYearly = true;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    if (user.isPremium) {
      return _buildAlreadyPremium(context);
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                decoration: const BoxDecoration(
                  gradient: AppColors.premiumGradient,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Colors.white, size: 56)
                        .animate()
                        .scale(duration: 600.ms, curve: Curves.elasticOut),
                    const SizedBox(height: 16),
                    Text(
                      'QuickConvert Premium',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 8),
                    Text(
                      'Convertis sans limites, sans pubs',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withAlpha(215),
                          ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 200.ms),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Toggle mensuel/annuel
                    _buildPlanToggle().animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 24),

                    // Prix
                    _buildPriceCard().animate().fadeIn(delay: 400.ms),
                    const SizedBox(height: 24),

                    // Features
                    Text(
                      'Tout ce que tu obtiens',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ).animate().fadeIn(delay: 450.ms),
                    const SizedBox(height: 12),
                    ..._buildFeatures().asMap().entries.map(
                          (e) => e.value.animate(delay: Duration(milliseconds: 500 + e.key * 60)),
                        ),
                    const SizedBox(height: 28),

                    // CTA Button
                    _buildPurchaseButton(context).animate().fadeIn(delay: 700.ms).slideY(begin: 0.3),
                    const SizedBox(height: 12),

                    // Restore & Terms
                    Center(
                      child: TextButton(
                        onPressed: () => _restorePurchases(context),
                        child: const Text('Restaurer mes achats'),
                      ),
                    ),
                    Center(
                      child: Text(
                        'Annule à tout moment. Renouvellement automatique.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _PlanTab(
            label: 'Mensuel\n4,99€/mois',
            isSelected: !_isYearly,
            onTap: () => setState(() => _isYearly = false),
          ),
          _PlanTab(
            label: 'Annuel\n2,99€/mois',
            isSelected: _isYearly,
            onTap: () => setState(() => _isYearly = true),
            badge: '-40%',
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.premiumGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.premium.withAlpha(90),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isYearly ? '35,88€/an' : '4,99€/mois',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _isYearly ? 'soit 2,99€/mois — économise 40%' : 'Annulable à tout moment',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const Spacer(),
          const Icon(Icons.star_rounded, color: Colors.white, size: 40),
        ],
      ),
    );
  }

  List<Widget> _buildFeatures() {
    final features = SubscriptionModel.monthly.features;
    return features
        .map(
          (f) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: AppColors.success, size: 16),
                ),
                const SizedBox(width: 12),
                Text(f, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        )
        .toList();
  }

  Widget _buildPurchaseButton(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    final isLoading = subProvider.status == SubscriptionStatus.loading;

    return ElevatedButton(
      onPressed: isLoading ? null : () => _purchase(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.premium,
        disabledBackgroundColor: AppColors.premium.withAlpha(150),
        minimumSize: const Size(double.infinity, 58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : Text(
              _isYearly ? 'Démarrer le Premium Annuel' : 'Démarrer le Premium Mensuel',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
    );
  }

  Future<void> _purchase(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final subProvider = context.read<SubscriptionProvider>();

    // Tenter l'achat réel via In-App Purchase
    if (subProvider.isAvailable) {
      onSuccess(DateTime expiresAt) {
        authProvider.activatePremium(expiresAt);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('🎉 Bienvenue dans QuickConvert Premium !'),
              backgroundColor: AppColors.premium,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }

      if (_isYearly) {
        await subProvider.purchaseYearly(onSuccess);
      } else {
        await subProvider.purchaseMonthly(onSuccess);
      }

      // Si erreur IAP, montrer un message
      if (subProvider.status == SubscriptionStatus.error && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(subProvider.error ?? 'Erreur lors de l\'achat'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      // Fallback mode test (store non disponible — émulateur/web)
      final expiresAt = DateTime.now().add(
        _isYearly ? const Duration(days: 365) : const Duration(days: 30),
      );
      authProvider.activatePremium(expiresAt);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Premium activé (mode test)'),
            backgroundColor: AppColors.premium,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _restorePurchases(BuildContext context) async {
    final subProvider = context.read<SubscriptionProvider>();
    if (subProvider.isAvailable) {
      await subProvider.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Restauration des achats en cours...'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Store non disponible'),
            backgroundColor: AppColors.textSecondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Widget _buildAlreadyPremium(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_rounded, color: AppColors.premium, size: 80),
            const SizedBox(height: 20),
            Text('Tu es Premium ! 🎉', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Profite de conversions illimitées sans pub',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;

  const _PlanTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppConstants.shortAnim,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (badge != null)
                Positioned(
                  top: 0,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
