import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/widgets.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isYearly = true;
  SubscriptionProvider? _subscriptions;

  @override
  void initState() {
    super.initState();
    // Le sort d'un achat n'arrive pas au retour de `buy()` mais par le flux du
    // store, parfois bien plus tard (un paiement différé peut mettre des
    // jours). L'écran écoute donc le provider au lieu d'attendre une valeur de
    // retour.
    _subscriptions = context.read<SubscriptionProvider>()
      ..addListener(_onStoreEvent);
  }

  @override
  void dispose() {
    _subscriptions?.removeListener(_onStoreEvent);
    super.dispose();
  }

  void _onStoreEvent() {
    final subscriptions = _subscriptions;
    final message = subscriptions?.message;
    if (subscriptions == null || message == null) return;
    subscriptions.consumeMessage();

    // Une notification du provider peut tomber pendant une phase de build, où
    // ouvrir un SnackBar lève une exception. On attend la fin de la frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify(message));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user.isPremium) {
      return _AlreadyPremium(entitlement: EntitlementService().read());
    }

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
                ..._buildCallToAction(subscriptions),
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

  /// Ce que l'utilisateur peut faire dépend de l'état du store, pas seulement
  /// de son envie d'acheter. Avant, le bouton était toujours là et n'aboutissait
  /// nulle part sur le web.
  List<Widget> _buildCallToAction(SubscriptionProvider subscriptions) {
    switch (subscriptions.availability) {
      case StoreAvailability.checking:
        return [
          const _PendingButton(label: 'Connexion au store…'),
        ];

      case StoreAvailability.unsupported:
        return [
          const _StoreNotice(
            icon: Icons.phone_iphone_rounded,
            title: 'L\'abonnement se souscrit depuis l\'app mobile',
            body: 'Le paiement passe par Google Play, qui n\'existe pas sur le '
                'web. Installe QuickConvert sur ton téléphone pour t\'abonner. '
                'Ici, les conversions gratuites restent disponibles.',
          ),
          ..._debugActivation(),
        ];

      case StoreAvailability.unavailable:
        return [
          const _StoreNotice(
            icon: Icons.cloud_off_rounded,
            title: 'Le store ne répond pas',
            body: 'Vérifie ta connexion et que l\'app a bien été installée '
                'depuis le Play Store, puis réessaie.',
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: subscriptions.isBusy ? null : _retry,
            child: const Text('Réessayer'),
          ),
          ..._debugActivation(),
        ];

      case StoreAvailability.ready:
        return [
          _buildPurchaseButton(subscriptions),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: subscriptions.isBusy ? null : _restorePurchases,
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
        ];
    }
  }

  /// Raccourci de développement : permet de tester l'app en Premium sans
  /// store. `kDebugMode` est résolu à la compilation, donc ce bouton n'existe
  /// pas dans un build de production — sans quoi il offrirait l'abonnement à
  /// quiconque ouvre la version web.
  List<Widget> _debugActivation() {
    if (!kDebugMode) return const [];
    return [
      const SizedBox(height: AppSpacing.md),
      TextButton(
        onPressed: () => context
            .read<AuthProvider>()
            .activateDebugPremium(const Duration(days: 30)),
        child: const Text('Activer le Premium (développement)'),
      ),
    ];
  }

  Widget _buildPurchaseButton(SubscriptionProvider subscriptions) {
    if (subscriptions.flow == PurchaseFlowStatus.pending) {
      return const _PendingButton(label: 'Validation par le store…');
    }
    if (subscriptions.flow == PurchaseFlowStatus.loadingProducts) {
      return const _PendingButton(label: 'Chargement des offres…');
    }

    final product = _selectedProduct(subscriptions);

    return ElevatedButton(
      // Sans offre chargée il n'y a rien à acheter : mieux vaut un bouton
      // éteint qu'un bouton qui échoue.
      onPressed: product == null ? null : () => _purchase(product),
      child: Text(_isYearly
          ? 'Prendre l\'abonnement annuel'
          : 'Prendre l\'abonnement mensuel'),
    );
  }

  ProductDetails? _selectedProduct(SubscriptionProvider subscriptions) =>
      _isYearly ? subscriptions.yearlyProduct : subscriptions.monthlyProduct;

  Future<void> _purchase(ProductDetails product) =>
      context.read<SubscriptionProvider>().buy(product);

  Future<void> _retry() => context.read<SubscriptionProvider>().retry();

  Future<void> _restorePurchases() =>
      context.read<SubscriptionProvider>().restorePurchases();

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Bouton plein, désactivé, avec un indicateur : montre qu'on attend le store
/// sans laisser l'utilisateur relancer un paiement en double.
class _PendingButton extends StatelessWidget {
  final String label;
  const _PendingButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// Explique pourquoi l'achat n'est pas possible ici, au lieu d'un bouton mort.
class _StoreNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _StoreNotice({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.sunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: palette.textMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.texts.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(body, style: context.texts.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
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
  final Entitlement entitlement;

  const _AlreadyPremium({required this.entitlement});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fromStore = entitlement.source == EntitlementSource.playStore ||
        entitlement.source == EntitlementSource.appStore;

    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: ContentColumn(
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
                const SizedBox(height: AppSpacing.xl),
                Text(entitlement.planLabel, style: context.texts.titleMedium),
                if (entitlement.source == EntitlementSource.debug) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Activation de développement',
                    style: context.texts.bodySmall,
                  ),
                ],
                if (fromStore) ...[
                  const SizedBox(height: AppSpacing.xl),
                  // Le Play Store impose que l'app mène à la page où l'on
                  // résilie. Ne pas l'avoir est un motif de rejet.
                  OutlinedButton.icon(
                    onPressed: _openStoreSubscriptions,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Gérer ou résilier mon abonnement'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openStoreSubscriptions() async {
    final url = entitlement.source == EntitlementSource.appStore
        ? AppConstants.appStoreSubscriptionsUrl
        : AppConstants.playSubscriptionsUrl;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
