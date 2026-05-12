import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/map_offline_service.dart';
import '../profile/profile_screen.dart';
import '../offline/offline_trails_screen.dart';
import 'terms_screen.dart';
import 'version_screen.dart';

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
  final MapOfflineService _mapOfflineService = MapOfflineService();
  bool _hasOfflineMap = false;
  bool _isDownloadingMap = false;
  String _offlineMapStatus = 'Vérification...';

  Color _pageBg(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark
      ? const Color(0xFF121212)
      : const Color(0xFFF6F5F2);
  Color _cardBg(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark
      ? const Color(0xFF1E1E1E)
      : const Color(0xFFEDE8DF);
  Color _titleColor(BuildContext ctx) => Theme.of(ctx).colorScheme.onSurface;
  Color _subtitleColor(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6);
  Color _mutedColor(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5);

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkOfflineMap();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _trailAlerts = prefs.getBool('settings_trail_alerts') ?? false;
        _poiAlerts = prefs.getBool('settings_poi_alerts') ?? true;
        _securityAlerts = prefs.getBool('settings_security_alerts') ?? true;
        _gpsEnabled = prefs.getBool('settings_gps_enabled') ?? true;
        _powerSaving = prefs.getBool('settings_power_saving') ?? false;
      });
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _checkOfflineMap() async {
    await _mapOfflineService.initialize();
    final hasTiles = await _mapOfflineService.hasAnyOfflineTile();
    if (mounted) {
      setState(() {
        _hasOfflineMap = hasTiles;
        _offlineMapStatus = hasTiles
            ? 'Disponible (Tabarka)'
            : 'Télécharger via WIFI';
      });
    }
  }

  Future<void> _handleDownloadMap() async {
    if (_hasOfflineMap) return;
    setState(() {
      _isDownloadingMap = true;
      _offlineMapStatus = 'Téléchargement en cours...';
    });

    try {
      await _mapOfflineService.downloadTabarkaTiles();
      await _checkOfflineMap();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Carte de Tabarka téléchargée avec succès. Vous pouvez maintenant naviguer hors ligne !',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingMap = false);
        _checkOfflineMap();
      }
    }
  }

  void _showLanguagePicker(BuildContext context) {
    final localeProvider = context.read<LocaleProvider>();
    final current = localeProvider.languageCode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44, height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(sheetContext).dividerColor
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  localeProvider.t('language.choose'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(sheetContext).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
                _LanguageOption(
                  flag: '🇫🇷',
                  label: localeProvider.t('language.french'),
                  code: 'fr',
                  selected: current == 'fr',
                  onTap: () async {
                    await localeProvider.setLocale('fr');
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                ),
                const SizedBox(height: 10),
                _LanguageOption(
                  flag: '🇬🇧',
                  label: localeProvider.t('language.english'),
                  code: 'en',
                  selected: current == 'en',
                  onTap: () async {
                    await localeProvider.setLocale('en');
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleClearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le cache ?'),
        content: const Text(
          'Cela supprimera la carte hors ligne. Vous devrez la retélécharger avec une connexion Internet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _mapOfflineService.clearTabarkaTiles();
    await _checkOfflineMap();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cache vidé avec succès')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final lp = context.watch<LocaleProvider>();

    return Scaffold(
      backgroundColor: _pageBg(context),
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
                  title: user?.fullName ?? lp.t('settings.profile'),
                  subtitle: lp.t('settings.profile.subtitle'),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: _mutedColor(context),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(
                  context.watch<LocaleProvider>().t('settings.regional')),
              const SizedBox(height: 10),
              _SettingCard(
                child: Column(
                  children: [
                    Consumer<LocaleProvider>(
                      builder: (context, localeProvider, _) {
                        return _SettingTile(
                          icon: Icons.language,
                          iconColor: AppTheme.primaryColor,
                          title: localeProvider.t('settings.language'),
                          subtitle:
                              localeProvider.t('settings.language.subtitle'),
                          onTap: () => _showLanguagePicker(context),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                localeProvider.languageLabel,
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: _mutedColor(context),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, _) {
                        return _SettingTile(
                          icon: Icons.dark_mode,
                          iconColor: AppTheme.primaryColor,
                          title: context
                              .watch<LocaleProvider>()
                              .t('settings.darkmode'),
                          subtitle: context
                              .watch<LocaleProvider>()
                              .t('settings.darkmode.subtitle'),
                          trailing: _buildSwitch(
                            value: themeProvider.isDarkMode,
                            onChanged: (value) {
                              themeProvider.toggleTheme(value);
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(lp.t('settings.communications')),
              const SizedBox(height: 10),
              _SettingCard(
                child: Column(
                  children: [
                    _SettingTile(
                      icon: Icons.notifications_active,
                      iconColor: AppTheme.primaryColor,
                      title: lp.t('settings.trailAlerts'),
                      subtitle: lp.t('settings.trailAlerts.subtitle'),
                      trailing: _buildSwitch(
                        value: _trailAlerts,
                        onChanged: (value) {
                          setState(() => _trailAlerts = value);
                          _updateSetting('settings_trail_alerts', value);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingTile(
                      icon: Icons.help,
                      iconColor: AppTheme.primaryColor,
                      title: lp.t('settings.poiAlerts'),
                      subtitle: lp.t('settings.poiAlerts.subtitle'),
                      trailing: _buildSwitch(
                        value: _poiAlerts,
                        onChanged: (value) {
                          setState(() => _poiAlerts = value);
                          _updateSetting('settings_poi_alerts', value);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingTile(
                      icon: Icons.medical_services,
                      iconColor: AppTheme.primaryColor,
                      title: lp.t('settings.safetyAlerts'),
                      subtitle: lp.t('settings.safetyAlerts.subtitle'),
                      trailing: _buildSwitch(
                        value: _securityAlerts,
                        onChanged: (value) {
                          setState(() => _securityAlerts = value);
                          _updateSetting('settings_security_alerts', value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(lp.t('settings.system')),
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
                        onChanged: (value) {
                          setState(() => _gpsEnabled = value);
                          _updateSetting('settings_gps_enabled', value);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingTile(
                      icon: Icons.gps_fixed,
                      iconColor: AppTheme.primaryColor,
                      title: 'Precision GPS',
                      subtitle: 'Equilibre entre batterie et precision',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Elevee',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: _mutedColor(context),
                          ),
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
                        onChanged: (value) {
                          setState(() => _powerSaving = value);
                          _updateSetting('settings_power_saving', value);
                        },
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
                  children: [
                    _SettingTile(
                      icon: Icons.download_for_offline,
                      iconColor: AppTheme.primaryColor,
                      title: lp.t('settings.offlineMap'),
                      subtitle: _offlineMapStatus,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const OfflineTrailsScreen(),
                          ),
                        );
                        _checkOfflineMap();
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isDownloadingMap)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Text(
                              _hasOfflineMap ? 'OK' : '12 MB',
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: _mutedColor(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingTile(
                      icon: Icons.delete_outline,
                      iconColor: AppTheme.primaryColor,
                      title: lp.t('settings.clearCache'),
                      subtitle: 'Liberer de l\'espace local',
                      onTap: _handleClearCache,
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: _mutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(
                  context.watch<LocaleProvider>().t('settings.about')),
              const SizedBox(height: 10),
              _SettingCard(
                child: Column(
                  children: [
                    _SettingTile(
                      icon: Icons.description,
                      iconColor: AppTheme.primaryColor,
                      title: lp.t('settings.terms'),
                      subtitle: lp.t('settings.terms.subtitle'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TermsScreen()),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: _mutedColor(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingTile(
                      icon: Icons.info_outline,
                      iconColor: AppTheme.primaryColor,
                      title: lp.t('settings.version'),
                      subtitle: lp.t('settings.version.app'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const VersionScreen()),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: _mutedColor(context),
                      ),
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
                  backgroundColor: Theme.of(context).cardColor,
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
            icon: Icon(Icons.arrow_back, color: _titleColor(context)),
          ),
          Expanded(
            child: Text(
              'Parametres',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _titleColor(context),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Centre d\'aide bientot disponible'),
                ),
              );
            },
            icon: Icon(Icons.help_outline, color: _titleColor(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: _subtitleColor(context),
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
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : const Color(0xFFEDE8DF),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color:
                  (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.white)
                      .withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.1
                            : 0.72,
                      ),
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
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
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

class _LanguageOption extends StatelessWidget {
  final String flag;
  final String label;
  final String code;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.flag,
    required this.label,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor
                : theme.dividerColor.withValues(alpha: 0.2),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    code.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.primaryColor, size: 22),
          ],
        ),
      ),
    );
  }
}
