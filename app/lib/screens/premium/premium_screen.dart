import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  PremiumPlan _selected = PremiumPlan.yearly;
  SubscriptionProvider? _subscriptions;

  @override
  void initState() {
    super.initState();
    // Le sort d'un paiement n'arrive pas au retour de `buy()` : sur mobile il
    // vient du flux du store, parfois des jours plus tard ; sur le web l'app
    // est rechargée au retour de Stripe. L'écran écoute donc le provider.
    _subscriptions = context.read<SubscriptionProvider>()
      ..addListener(_onBillingEvent);
  }

  @override
  void dispose() {
    _subscriptions?.removeListener(_onBillingEvent);
    super.dispose();
  }

  void _onBillingEvent() {
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
                  offers: subscriptions.offers,
                  selected: _selected,
                  onChanged: (plan) => setState(() => _selected = plan),
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

  /// Ce que l'utilisateur peut faire dépend de l'état du moyen de paiement,
  /// pas seulement de son envie de s'abonner. Avant, le bouton était toujours
  /// là et n'aboutissait nulle part sur le web.
  List<Widget> _buildCallToAction(SubscriptionProvider subscriptions) {
    switch (subscriptions.availability) {
      case StoreAvailability.checking:
        return [const _PendingButton(label: 'Connexion en cours…')];

      case StoreAvailability.unsupported:
        return [
          const _StoreNotice(
            icon: Icons.phone_iphone_rounded,
            title: 'L\'abonnement se souscrit depuis l\'app mobile',
            body: 'Le paiement passe par Google Play, qui n\'existe pas ici. '
                'Les conversions gratuites, elles, restent disponibles.',
          ),
          ..._debugActivation(),
        ];

      case StoreAvailability.unavailable:
        return [
          const _StoreNotice(
            icon: Icons.cloud_off_rounded,
            title: 'Le paiement ne répond pas',
            body: 'Vérifie ta connexion, puis réessaie.',
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: subscriptions.isBusy ? null : _retry,
            child: const Text('Réessayer'),
          ),
          ..._debugActivation(),
        ];

      case StoreAvailability.ready:
        if (subscriptions.offersUnavailable) {
          return [
            const _StoreNotice(
              icon: Icons.schedule_rounded,
              title: 'Les offres ne sont pas disponibles',
              body: 'Le store ne propose aucune formule pour le moment. '
                  'Ce n\'est pas ton appareil : réessaie plus tard, les '
                  'conversions gratuites restent disponibles.',
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: subscriptions.isBusy ? null : _retry,
              child: const Text('Réessayer'),
            ),
            ..._debugActivation(),
          ];
        }
        return [
          _buildPurchaseButton(subscriptions),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: subscriptions.isBusy ? null : _restore,
              child: Text(subscriptions.isBrowserBound
                  ? 'Vérifier mon abonnement'
                  : 'Restaurer mes achats'),
            ),
          ),
          if (subscriptions.isBrowserBound) ...[
            Center(
              child: TextButton(
                onPressed: subscriptions.isBusy ? null : _askForRestoreCode,
                child: const Text('J\'ai déjà un abonnement sur un autre appareil'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _StoreNotice(
              icon: Icons.info_outline_rounded,
              title: 'Ton abonnement sera rattaché à ce navigateur',
              body: 'QuickConvert n\'a pas encore de comptes. Après le '
                  'paiement, garde le code affiché sur l\'écran Premium : '
                  'c\'est lui qui te permettra de retrouver ton abonnement '
                  'ailleurs, ou si tu effaces les données du site.',
            ),
          ] else
            Center(
              child: Text(
                'Renouvellement automatique, annulable à tout moment '
                'depuis ton compte du store.',
                style: context.texts.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          const _LegalLinks(),
        ];
    }
  }

  /// Raccourci de développement : permet de tester l'app en Premium sans
  /// payer. `kDebugMode` est résolu à la compilation, donc ce bouton n'existe
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
      return const _PendingButton(label: 'Paiement en cours…');
    }
    if (subscriptions.flow == PurchaseFlowStatus.loadingProducts) {
      return const _PendingButton(label: 'Chargement des offres…');
    }

    // Sur mobile il faut que le store ait livré l'offre ; sur le web c'est
    // Stripe qui affiche le prix définitif sur sa propre page.
    final offer = subscriptions.offerFor(_selected);
    final blocked = subscriptions.backend == BillingBackend.store &&
        offer.storeProduct == null;

    return ElevatedButton(
      onPressed: blocked ? null : () => subscriptions.buy(_selected),
      child: Text('Prendre l\'abonnement ${_selected.title.toLowerCase()}'),
    );
  }

  Future<void> _retry() => context.read<SubscriptionProvider>().retry();

  Future<void> _restore() =>
      context.read<SubscriptionProvider>().restorePurchases();

  /// Reprise d'un abonnement souscrit ailleurs, par son code.
  Future<void> _askForRestoreCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        title: const Text('Reprendre un abonnement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Colle le code affiché sur l\'écran Premium de l\'appareil où '
              'tu as payé.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Code d\'abonnement'),
              onSubmitted: (value) => Navigator.pop(dialogContext, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Reprendre'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (!mounted || code == null || code.trim().isEmpty) return;
    await context.read<SubscriptionProvider>().restoreWithCode(code);
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Conditions et confidentialité, sous l'offre d'abonnement.
///
/// L'App Store refuse un écran d'abonnement reconductible qui n'y mène pas
/// (règle 3.1.2). Les deux pages sont servies par le site.
class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _LegalLink(
          label: "Conditions d'utilisation",
          url: AppConstants.termsUrl,
        ),
        Text('·', style: context.texts.bodySmall),
        const _LegalLink(
          label: 'Confidentialité',
          url: AppConstants.privacyUrl,
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final String url;

  const _LegalLink({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: context.texts.bodySmall),
    );
  }
}

/// Bouton plein, désactivé, avec un indicateur : montre qu'on attend sans
/// laisser l'utilisateur relancer un paiement en double.
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

/// Explique une situation au lieu de laisser un bouton mort ou un silence.
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
  final List<PlanOffer> offers;
  final PremiumPlan selected;
  final ValueChanged<PremiumPlan> onChanged;

  const _PlanPicker({
    required this.offers,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // L'annuel d'abord : c'est la formule mise en avant.
    final ordered = [
      ...offers.where((o) => o.plan == PremiumPlan.yearly),
      ...offers.where((o) => o.plan != PremiumPlan.yearly),
    ];

    return Column(
      children: [
        for (final offer in ordered) ...[
          _PlanOption(
            offer: offer,
            badge: offer.plan == PremiumPlan.yearly ? 'Le plus avantageux' : null,
            isSelected: offer.plan == selected,
            onTap: () => onChanged(offer.plan),
          ),
          if (offer != ordered.last) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _PlanOption extends StatelessWidget {
  final PlanOffer offer;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanOption({
    required this.offer,
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
      label: 'Abonnement ${offer.plan.title}, '
          '${offer.priceLabel} ${offer.plan.period}',
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
                          Text(offer.plan.title, style: context.texts.titleLarge),
                          if (badge != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm, vertical: 2),
                              decoration: BoxDecoration(
                                color: palette.success.withAlpha(38),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
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
                      Text(offer.plan.period, style: context.texts.bodySmall),
                    ],
                  ),
                ),
                Text(offer.priceLabel, style: context.texts.headlineSmall),
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
    final subscriptions = context.watch<SubscriptionProvider>();
    final isDebug = entitlement.source == EntitlementSource.debug;

    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ContentColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Icon(Icons.verified_rounded, color: palette.premium, size: 64),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Tu es Premium',
                  style: context.texts.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Conversions illimitées, sans publicité.',
                  style: context.texts.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  entitlement.planLabel,
                  style: context.texts.titleMedium,
                  textAlign: TextAlign.center,
                ),
                if (isDebug) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Activation de développement',
                    style: context.texts.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (entitlement.source == EntitlementSource.stripe) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _RestoreCode(code: subscriptions.restoreCode),
                ],
                if (!isDebug) ...[
                  const SizedBox(height: AppSpacing.xl),
                  // Le Play Store impose que l'app mène à la page où l'on
                  // résilie, et vendre un abonnement sans ce chemin ne se
                  // fait pas non plus sur le web.
                  OutlinedButton.icon(
                    onPressed: () => _manage(context),
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

  Future<void> _manage(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened =
        await context.read<SubscriptionProvider>().openManageSubscription();
    if (opened) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('La page de gestion n\'a pas pu s\'ouvrir.'),
      ));
  }
}

/// Le code qui rattache un abonnement Stripe à ce navigateur.
///
/// Faute de comptes utilisateurs, c'est la seule chose qui permet de retrouver
/// son abonnement ailleurs — donc il doit être visible et copiable, pas caché.
class _RestoreCode extends StatelessWidget {
  final String code;

  const _RestoreCode({required this.code});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ton code d\'abonnement', style: context.texts.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Garde-le : il te permet de retrouver ton abonnement sur un autre '
            'navigateur, ou si tu effaces les données du site.',
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          SelectableText(
            code,
            style: context.texts.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copier'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: code));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Code copié.')));
  }
}
