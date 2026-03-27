import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../profile/profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _trailAlerts = false;
  bool _poiAlerts = false;
  bool _securityAlerts = false;
  bool _gpsEnabled = false;
  bool _powerSaving = false;

  static const Color _pageBg = Color(0xFFF6F5F2);
  static const Color _cardBg = Color(0xFFEDE8DF);
  static const Color _title = Color(0xFF222222);
  static const Color _subtitle = Color(0xFF666666);
  static const Color _muted = Color(0xFF8C8895);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              _SettingCard(
                child: _SettingTile(
                  icon: Icons.person,
                  iconColor: AppTheme.primaryColor,
                  title: user?.fullName ?? 'Mon profil',
                  subtitle: 'Voir profil et progression',
                  trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('PREFERENCES REGIONALES'),
              const SizedBox(height: 10),
              _SettingCard(
                child: _SettingTile(
                  icon: Icons.language,
                  iconColor: AppTheme.primaryColor,
                  title: 'Langue de l\'application',
                  subtitle: 'Choisissez votre langue preferee',
                  trailing: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Francais (FR)',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.chevron_right_rounded, color: _muted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('COMMUNICATIONS'),
              const SizedBox(height: 10),
              _SettingCard(
                child: Column(
                  children: [
                    _SettingTile(
                      icon: Icons.notifications_active,
                      iconColor: AppTheme.primaryColor,
                      title: 'Alertes de sentier',
                      subtitle: 'Recevoir des alertes en cas de danger',
                      trailing: _buildSwitch(
                        value: _trailAlerts,
                        onChanged: (value) => setState(() => _trailAlerts = value),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingTile(
                      icon: Icons.help,
                      iconColor: AppTheme.primaryColor,
                      title: 'Points d\'interet',
                      subtitle: 'Notifications a proximite des POI',
                      trailing: _buildSwitch(
                        value: _poiAlerts,
                        onChanged: (value) => setState(() => _poiAlerts = value),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingTile(
                      icon: Icons.medical_services,
                      iconColor: AppTheme.primaryColor,
                      title: 'Alertes de securite',
                      subtitle: 'Informations meteo et secours',
                      trailing: _buildSwitch(
                        value: _securityAlerts,
                        onChanged: (value) => setState(() => _securityAlerts = value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('SYSTEME ET GPS'),
              const SizedBox(height: 10),
              _SettingCard(
                child: Column(
                  children: [
                    _SettingTile(
                      icon: Icons.location_on,
                      iconColor: AppTheme.primaryColor,
                      title: 'Localisation GPS',
                      subtitle: 'Necessaire pour la navigation',
                      trailing: _buildSwitch(
                        value: _gpsEnabled,
                        onChanged: (value) => setState(() => _gpsEnabled = value),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingTile(
                      icon: Icons.gps_fixed,
                      iconColor: AppTheme.primaryColor,
                      title: 'Precision GPS',
                      subtitle: 'Equilibre entre batterie et precision',
                      trailing: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Elevee',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.chevron_right_rounded, color: _muted),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingTile(
                      icon: Icons.battery_charging_full,
                      iconColor: AppTheme.primaryColor,
                      title: 'Economie d\'energie',
                      subtitle: 'Reduit la frequence du GPS + mode dark',
                      trailing: _buildSwitch(
                        value: _powerSaving,
                        onChanged: (value) => setState(() => _powerSaving = value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('STOCKAGE'),
              const SizedBox(height: 10),
              _SettingCard(
                child: Column(
                  children: const [
                    _SettingTile(
                      icon: Icons.download_for_offline,
                      iconColor: AppTheme.primaryColor,
                      title: 'Cartes hors ligne',
                      subtitle: 'Gerer vos cartes telechargees',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '1.2 GB',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.chevron_right_rounded, color: _muted),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    _SettingTile(
                      icon: Icons.delete_outline,
                      iconColor: AppTheme.primaryColor,
                      title: 'Vider le cache',
                      subtitle: 'Liberer de l\'espace local',
                      trailing: Icon(Icons.chevron_right_rounded, color: _muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('A PROPOS'),
              const SizedBox(height: 10),
              _SettingCard(
                child: Column(
                  children: const [
                    _SettingTile(
                      icon: Icons.description,
                      iconColor: AppTheme.primaryColor,
                      title: 'Conditions d\'utilisation',
                      subtitle: 'Mentions legales et vie privee',
                      trailing: Icon(Icons.chevron_right_rounded, color: _muted),
                    ),
                    SizedBox(height: 10),
                    _SettingTile(
                      icon: Icons.info_outline,
                      iconColor: AppTheme.primaryColor,
                      title: 'Version',
                      subtitle: 'Eco-Guide v2.4.0',
                      trailing: Icon(Icons.chevron_right_rounded, color: _muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: () => _onLogout(context),
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Deconnexion',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD54A3A),
                  side: const BorderSide(color: Color(0xFFD54A3A), width: 1.5),
                  backgroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.arrow_back, color: _title),
          ),
          const Expanded(
            child: Text(
              'Parametres',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _title,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Centre d\'aide bientot disponible')),
              );
            },
            icon: const Icon(Icons.help_outline, color: _title),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF4A4A4A),
      ),
    );
  }

  Widget _buildSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: AppTheme.primaryColor,
      inactiveThumbColor: const Color(0xFF5C5C5C),
      inactiveTrackColor: const Color(0xFFD9D7DD),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Future<void> _onLogout(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deconnexion'),
        content: const Text('Voulez-vous vous deconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deconnecter'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await authProvider.logout();
    }
  }
}

class _SettingCard extends StatelessWidget {
  final Widget child;

  const _SettingCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _SettingsScreenState._cardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _SettingsScreenState._title,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _SettingsScreenState._subtitle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}
