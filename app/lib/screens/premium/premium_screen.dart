import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isYearly = true;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user.isPremium) return const _AlreadyPremium();

    final subscriptions = context.watch<SubscriptionProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md,
              AppSpacing.gutter, AppSpacing.xxxl),
          child: ContentColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hero(),
                const SizedBox(height: AppSpacing.xxl),
                _PlanPicker(
                  isYearly: _isYearly,
                  monthlyPrice: _monthlyPrice(subscriptions),
                  yearlyPrice: _yearlyPrice(subscriptions),
                  onChanged: (yearly) => setState(() => _isYearly = yearly),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('Ce que ça change', style: context.texts.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                for (final feature in SubscriptionModel.monthly.features)
                  _FeatureRow(feature),
                const SizedBox(height: AppSpacing.xxl),
                _buildPurchaseButton(subscriptions),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton(
                    onPressed: _restorePurchases,
                    child: const Text('Restaurer mes achats'),
                  ),
                ),
                Center(
                  child: Text(
                    'Renouvellement automatique, annulable à tout moment '
                    'depuis ton compte du store.',
                    style: context.texts.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Le prix vient du store dès qu'il a répondu : c'est lui qui connaît la
  // devise et la fiscalité de l'utilisateur, et le Play Store demande que ce
  // soit celui-là qui s'affiche. Les constantes ne servent que d'attente.
  String _monthlyPrice(SubscriptionProvider provider) =>
      provider.monthlyProduct?.price ?? AppConstants.fallbackMonthlyPrice;

  String _yearlyPrice(SubscriptionProvider provider) =>
      provider.yearlyProduct?.price ?? AppConstants.fallbackYearlyPrice;

  Widget _buildPurchaseButton(SubscriptionProvider subscriptions) {
    final isLoading = subscriptions.status == SubscriptionStatus.loading;

    return ElevatedButton(
      onPressed: isLoading ? null : _purchase,
      child: isLoading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: context.colors.onPrimary,
              ),
            )
          : Text(_isYearly ? 'Prendre l\'abonnement annuel' : 'Prendre l\'abonnement mensuel'),
    );
  }

  Future<void> _purchase() async {
    final auth = context.read<AuthProvider>();
    final subscriptions = context.read<SubscriptionProvider>();

    if (!subscriptions.isAvailable) {
      // En débogage, on active Premium sans passer par le store pour pouvoir
      // tester l'app. En production ce raccourci offrirait l'abonnement à
      // quiconque ouvre la version web, où le store n'existe pas.
      if (kDebugMode) {
        auth.activatePremium(DateTime.now().add(
          _isYearly ? const Duration(days: 365) : const Duration(days: 30),
        ));
        _notify('Premium activé (mode développement)');
      } else {
        _notify('Les abonnements ne sont pas disponibles sur cette plateforme.');
      }
      return;
    }

    void onSuccess(DateTime expiresAt) {
      auth.activatePremium(expiresAt);
      _notify('Bienvenue dans QuickConvert Premium.');
    }

    if (_isYearly) {
      await subscriptions.purchaseYearly(onSuccess);
    } else {
      await subscriptions.purchaseMonthly(onSuccess);
    }

    if (subscriptions.status == SubscriptionStatus.error) {
      _notify(subscriptions.error ?? 'L\'achat n\'a pas abouti.');
    }
  }

  Future<void> _restorePurchases() async {
    final subscriptions = context.read<SubscriptionProvider>();
    if (!subscriptions.isAvailable) {
      _notify('Aucun store disponible sur cette plateforme.');
      return;
    }
    await subscriptions.restorePurchases();
    _notify('Restauration en cours…');
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: palette.premiumSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.premium.withAlpha(71)),
      ),
      child: Column(
        children: [
          Icon(Icons.bolt_rounded, size: 40, color: palette.premium),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Convertis sans compter',
            style: context.texts.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Plus de limite quotidienne, plus de publicité.',
            style: context.texts.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PlanPicker extends StatelessWidget {
  final bool isYearly;
  final String monthlyPrice;
  final String yearlyPrice;
  final ValueChanged<bool> onChanged;

  const _PlanPicker({
    required this.isYearly,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PlanOption(
          title: 'Annuel',
          price: yearlyPrice,
          period: 'par an',
          badge: 'Le plus avantageux',
          isSelected: isYearly,
          onTap: () => onChanged(true),
        ),
        const SizedBox(height: AppSpacing.md),
        _PlanOption(
          title: 'Mensuel',
          price: monthlyPrice,
          period: 'par mois',
          isSelected: !isYearly,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _PlanOption extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanOption({
    required this.title,
    required this.price,
    required this.period,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Abonnement $title, $price $period',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: AppDuration.fast,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isSelected ? colors.primaryContainer : colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isSelected ? colors.primary : palette.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? colors.primary : palette.textMuted,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title, style: context.texts.titleLarge),
                          if (badge != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm, vertical: 2),
                              decoration: BoxDecoration(
                                color: palette.success.withAlpha(38),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                badge!,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: palette.success,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(period, style: context.texts.bodySmall),
                    ],
                  ),
                ),
                Text(price, style: context.texts.headlineSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String label;
  const _FeatureRow(this.label);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 20, color: palette.success),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: context.texts.bodyLarge)),
        ],
      ),
    );
  }
}

class _AlreadyPremium extends StatelessWidget {
  const _AlreadyPremium();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, color: palette.premium, size: 64),
              const SizedBox(height: AppSpacing.xl),
              Text('Tu es Premium', style: context.texts.headlineMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Conversions illimitées, sans publicité.',
                style: context.texts.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
