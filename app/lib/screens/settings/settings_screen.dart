import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/core.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    } catch (_) {
      // Pas d'info de paquet sur certaines cibles : on n'affiche rien.
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: SafeArea(
        top: false,
        child: ContentColumn(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md,
                AppSpacing.gutter, AppSpacing.xxxl),
            children: [
              const _SectionHeader('Compte'),
              _SettingsTile(
                icon: user.isPremium
                    ? Icons.workspace_premium_rounded
                    : Icons.person_rounded,
                title: user.email ?? 'Mode invité',
                subtitle: user.isPremium
                    ? 'Conversions illimitées'
                    : '${AppConstants.freeConversionsPerDay} conversions par jour',
                color: user.isPremium
                    ? context.palette.premium
                    : context.colors.primary,
              ),
              // Tant que Supabase est désactivé, l'app ne propose pas une
              // connexion qui se solderait par un refus.
              if (AppConstants.authEnabled && !auth.isAuthenticated)
                _SettingsTile(
                  icon: Icons.login_rounded,
                  title: 'Se connecter',
                  subtitle: 'Retrouve ton historique sur tous tes appareils',
                  onTap: () => Navigator.pushNamed(context, '/auth'),
                ),
              if (AppConstants.authEnabled && auth.isAuthenticated)
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Se déconnecter',
                  color: context.colors.error,
                  onTap: auth.signOut,
                ),

              const SizedBox(height: AppSpacing.xl),
              const _SectionHeader('Apparence'),
              _SettingsTile(
                icon: switch (themeProvider.mode) {
                  ThemeMode.light => Icons.light_mode_rounded,
                  ThemeMode.dark => Icons.dark_mode_rounded,
                  ThemeMode.system => Icons.brightness_auto_rounded,
                },
                title: 'Thème',
                subtitle: themeProvider.label,
                onTap: () => _chooseTheme(themeProvider),
              ),

              if (!user.isPremium) ...[
                const SizedBox(height: AppSpacing.xl),
                const _SectionHeader('Premium'),
                _SettingsTile(
                  icon: Icons.bolt_rounded,
                  title: 'Passer à Premium',
                  subtitle: 'Conversions illimitées, sans publicité',
                  color: context.palette.premium,
                  onTap: () => Navigator.pushNamed(context, '/premium'),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),
              const _SectionHeader('Support'),
              _SettingsTile(
                icon: Icons.star_rounded,
                title: 'Noter l\'application',
                color: context.palette.premium,
                onTap: () => _launch('${AppConstants.siteUrl}/noter'),
              ),
              _SettingsTile(
                icon: Icons.ios_share_rounded,
                title: 'Partager QuickConvert',
                onTap: _shareApp,
              ),
              _SettingsTile(
                icon: Icons.mail_rounded,
                title: 'Contacter le support',
                onTap: () => _launch('mailto:support@quickconvert.app'),
              ),

              const SizedBox(height: AppSpacing.xl),
              const _SectionHeader('Légal'),
              _SettingsTile(
                icon: Icons.privacy_tip_rounded,
                title: 'Politique de confidentialité',
                onTap: () => _launch('${AppConstants.siteUrl}/privacy'),
              ),
              _SettingsTile(
                icon: Icons.gavel_rounded,
                title: 'Conditions d\'utilisation',
                onTap: () => _launch('${AppConstants.siteUrl}/terms'),
              ),

              if (!user.isPremium) ...[
                const SizedBox(height: AppSpacing.xl),
                const AdBannerContainer(),
              ],

              const SizedBox(height: AppSpacing.xxl),
              Center(
                child: Column(
                  children: [
                    Text(AppConstants.appName, style: context.texts.titleSmall),
                    if (_version.isNotEmpty)
                      Text('Version $_version', style: context.texts.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseTheme(ThemeProvider provider) async {
    final choice = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Thème', style: context.texts.headlineSmall),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final mode in ThemeMode.values)
              RadioListTile<ThemeMode>(
                value: mode,
                groupValue: provider.mode,
                onChanged: (value) => Navigator.pop(sheetContext, value),
                title: Text(switch (mode) {
                  ThemeMode.system => 'Comme le système',
                  ThemeMode.light => 'Clair',
                  ThemeMode.dark => 'Sombre',
                }),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );

    if (choice != null) await provider.setMode(choice);
  }

  Future<void> _shareApp() async {
    await Share.share(
      'QuickConvert — convertis tes fichiers en deux gestes : '
      '${AppConstants.siteUrl}',
      subject: AppConstants.appName,
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          left: AppSpacing.xs, bottom: AppSpacing.sm, top: AppSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: context.texts.labelSmall?.copyWith(letterSpacing: 0.8),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = color ?? context.colors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(31),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, color: accent, size: 19),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.texts.titleMedium),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(subtitle!, style: context.texts.bodySmall),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right_rounded, color: palette.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
