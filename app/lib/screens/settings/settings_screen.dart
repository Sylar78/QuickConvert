import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/core.dart';
import '../../providers/providers.dart';

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
    final info = await PackageInfo.fromPlatform();
    setState(() => _version = '${info.version} (${info.buildNumber})');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profil
          _SectionHeader(title: 'Compte'),
          _SettingsTile(
            icon: Icons.person_rounded,
            title: user.email ?? 'Invité',
            subtitle: user.isPremium ? 'Compte Premium ✨' : 'Compte gratuit — 5 conversions/jour',
            color: AppColors.primary,
          ),
          if (!authProvider.isAuthenticated)
            _SettingsTile(
              icon: Icons.login_rounded,
              title: 'Se connecter / S\'inscrire',
              subtitle: 'Synchronise ton historique',
              color: AppColors.accent,
              onTap: () => Navigator.pushNamed(context, '/auth'),
            ),
          if (authProvider.isAuthenticated)
            _SettingsTile(
              icon: Icons.logout_rounded,
              title: 'Se déconnecter',
              color: AppColors.error,
              onTap: () => authProvider.signOut(),
            ),

          const SizedBox(height: 20),

          // Premium
          if (!user.isPremium) ...[
            _SectionHeader(title: 'Premium'),
            _SettingsTile(
              icon: Icons.bolt_rounded,
              title: 'Passer à Premium',
              subtitle: '4,99€/mois — Conversions illimitées',
              color: AppColors.premium,
              onTap: () => Navigator.pushNamed(context, '/premium'),
            ),
            const SizedBox(height: 20),
          ],

          // Support
          _SectionHeader(title: 'Support'),
          _SettingsTile(
            icon: Icons.star_rounded,
            title: 'Noter l\'application',
            subtitle: 'Ça nous aide beaucoup !',
            color: AppColors.premium,
            onTap: () => _launchUrl('https://apps.apple.com/app/quickconvert'),
          ),
          _SettingsTile(
            icon: Icons.share_rounded,
            title: 'Partager QuickConvert',
            color: AppColors.primary,
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.mail_rounded,
            title: 'Contacter le support',
            color: AppColors.accent,
            onTap: () => _launchUrl('mailto:support@quickconvert.app'),
          ),

          const SizedBox(height: 20),

          // Légal
          _SectionHeader(title: 'Légal'),
          _SettingsTile(
            icon: Icons.privacy_tip_rounded,
            title: 'Politique de confidentialité',
            onTap: () => _launchUrl('https://quickconvert.app/privacy'),
          ),
          _SettingsTile(
            icon: Icons.gavel_rounded,
            title: 'Conditions d\'utilisation',
            onTap: () => _launchUrl('https://quickconvert.app/terms'),
          ),

          const SizedBox(height: 32),

          // Version
          Center(
            child: Column(
              children: [
                const Text('QuickConvert', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 16)),
                Text('Version $_version', style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                const SizedBox(height: 4),
                const Text('Made with ❤️', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
              fontSize: 12,
            ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: (color ?? AppColors.textSecondary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color ?? AppColors.textSecondary, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
        subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12)) : null,
        trailing: onTap != null
            ? const Icon(Icons.chevron_right_rounded, color: AppColors.textHint)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
