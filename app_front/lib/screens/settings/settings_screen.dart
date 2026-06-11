import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/map_tile_url.dart';
import '../../core/widgets/logout_dialog.dart';
import '../../services/voice_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/map_offline_service.dart';
import '../profile/profile_screen.dart';
import '../offline/offline_trails_screen.dart';
import '../help/help_center_screen.dart';
import 'qr_unlock_screen.dart';
import 'terms_screen.dart';
import 'version_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const SettingsScreen({super.key, this.onBack});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _trailAlerts = false;
  bool _poiAlerts = false;
  bool _securityAlerts = false;
  bool _gpsEnabled = false;
  bool _powerSaving = false;
  String _gpsPrecision = 'Haute';
  final MapOfflineService _mapOfflineService = MapOfflineService();
  bool _hasOfflineMap = false;
  final bool _isDownloadingMap = false;
  String _offlineMapStatus = 'Vérification...';

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
        _gpsPrecision = prefs.getString('settings_gps_precision') ?? 'Haute';
      });
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _showGpsPrecisionPicker(BuildContext context) {
    final lp = context.read<LocaleProvider>();
    final options = ['Haute', 'Normale', 'Économie'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
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
                    color: Theme.of(ctx).dividerColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                lp.t('settings.gpsPrecision.modal.title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                lp.t('settings.gpsPrecision.modal.subtitle'),
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 14),
              ...options.map((opt) {
                final selected = _gpsPrecision == opt;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      setState(() => _gpsPrecision = opt);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('settings_gps_precision', opt);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primaryColor.withValues(alpha: 0.08)
                            : Theme.of(ctx).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primaryColor
                              : Theme.of(ctx).dividerColor.withValues(alpha: 0.2),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            opt == 'Haute'
                                ? Icons.gps_fixed
                                : opt == 'Normale'
                                    ? Icons.gps_not_fixed
                                    : Icons.battery_saver,
                            color: selected
                                ? AppTheme.primaryColor
                                : Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opt == 'Haute'
                                      ? lp.t('settings.gpsPrecision.high')
                                      : opt == 'Normale'
                                          ? lp.t('settings.gpsPrecision.normal')
                                          : lp.t('settings.gpsPrecision.battery'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(ctx).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  opt == 'Haute'
                                      ? lp.t('settings.gpsPrecision.high.desc')
                                      : opt == 'Normale'
                                          ? lp.t('settings.gpsPrecision.normal.desc')
                                          : lp.t('settings.gpsPrecision.battery.desc'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle_rounded,
                                color: AppTheme.primaryColor, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
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
                const SizedBox(height: 10),
                _LanguageOption(
                  flag: '🇹🇳',
                  label: localeProvider.t('language.arabic'),
                  code: 'ar',
                  selected: current == 'ar',
                  onTap: () async {
                    await localeProvider.setLocale('ar');
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
    final lp = context.read<LocaleProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lp.t('settings.clearCache.dialog.title')),
        content: Text(
          lp.t('settings.clearCache.dialog.content'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lp.t('settings.clearCache.dialog.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(lp.t('settings.clearCache.dialog.delete'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _mapOfflineService.clearTabarkaTiles();
    await _checkOfflineMap();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lp.t('settings.clearCache.success'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final lp = context.watch<LocaleProvider>();

    final width = MediaQuery.sizeOf(context).width;
    final hPad = width >= 700 ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Let content flow UNDER the floating bottom bar so its edges stay
      // transparent (like the home & map pages) instead of sitting on an
      // opaque white shelf.
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                hPad,
                8,
                hPad,
                MediaQuery.of(context).padding.bottom + 88,
              ),
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
                    const SizedBox(height: 10),
                    // Global voice (text-to-speech) on/off — governs POIs, the
                    // chatbot, trail instructions and alerts. Works offline.
                    ValueListenableBuilder<bool>(
                      valueListenable: VoiceService.instance.enabled,
                      builder: (context, voiceOn, _) {
                        final lp = context.watch<LocaleProvider>();
                        return Column(
                          children: [
                            _SettingTile(
                              icon: Icons.volume_up,
                              iconColor: AppTheme.primaryColor,
                              title: lp.t('settings.voice'),
                              subtitle: lp.t('settings.voice.subtitle'),
                              trailing: _buildSwitch(
                                value: voiceOn,
                                onChanged: (value) =>
                                    VoiceService.instance.setEnabled(value),
                              ),
                            ),
                            // Voice type (féminine / masculine / …) — only when
                            // voice is enabled. Plays a sample on change.
                            if (voiceOn) ...[
                              const SizedBox(height: 10),
                              ValueListenableBuilder<String>(
                                valueListenable: VoiceService.instance.profile,
                                builder: (context, prof, __) {
                                  return _SettingTile(
                                    icon: Icons.record_voice_over,
                                    iconColor: AppTheme.primaryColor,
                                    title: lp.t('settings.voiceType'),
                                    subtitle: VoiceService.displayName(prof),
                                    trailing: DropdownButton<String>(
                                      value: prof,
                                      underline: const SizedBox.shrink(),
                                      items: VoiceService.profiles
                                          .map(
                                            (id) => DropdownMenuItem(
                                              value: id,
                                              child: Text(
                                                  VoiceService.displayName(id)),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        if (v == null) return;
                                        VoiceService.instance.setProfile(v);
                                        VoiceService.instance
                                            .preview(lp.locale.languageCode);
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
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
                      title: lp.t('settings.gps'),
                      subtitle: lp.t('settings.gps.subtitle'),
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
                      title: lp.t('settings.gpsPrecision'),
                      subtitle: lp.t('settings.gpsPrecision.subtitle'),
                      onTap: () => _showGpsPrecisionPicker(context),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _gpsPrecision,
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
                      icon: Icons.battery_charging_full,
                      iconColor: AppTheme.primaryColor,
                      title: lp.t('settings.powerSaving'),
                      subtitle: lp.t('settings.powerSaving.subtitle'),
                      trailing: _buildSwitch(
                        value: _powerSaving,
                        onChanged: (value) {
                          setState(() => _powerSaving = value);
                          _updateSetting('settings_power_saving', value);
                          context.read<ThemeProvider>().toggleTheme(value);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingTile(
                      icon: Icons.qr_code_scanner,
                      iconColor: AppTheme.primaryColor,
                      title: lp.t('settings.qrUnlock'),
                      subtitle: lp.t('settings.qrUnlock.subtitle'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const QrUnlockScreen(),
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: _mutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(lp.t('settings.storage')),
              const SizedBox(height: 10),
              _SettingCard(
                child: Column(
                  children: [
                    _buildOfflineMapPreview(),
                    const SizedBox(height: 12),
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
                label: Text(
                  lp.t('settings.logout'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
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
        ),
      ),
    );
  }

  Widget _buildOfflineMapPreview() {
    final center = LatLng(
      AppConstants.defaultLatitude,
      AppConstants.defaultLongitude,
    );
    final theme = Theme.of(context);
    final dotColor =
        _hasOfflineMap ? AppTheme.primaryColor : const Color(0xFFE67E22);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // Live, theme-aware map (uses cached tiles when offline)
          SizedBox(
            height: 150,
            width: double.infinity,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 11,
                minZoom: 3,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: mapTileUrlForTheme(context),
                  userAgentPackageName: 'com.ecoguide.app',
                  tileProvider:
                      LocalFirstTileProvider(service: _mapOfflineService),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: AppTheme.primaryColor,
                        size: 38,
                        shadows: [
                          Shadow(color: Colors.black45, blurRadius: 6),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Status chip (top-left)
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.cardColor.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _offlineMapStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Attribution (bottom-right)
          Positioned(
            right: 8,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OpenStreetMap',
                style: TextStyle(fontSize: 9, color: Colors.black54),
              ),
            ),
          ),
          // "Manage" hint pill (bottom-left)
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.layers_outlined, color: Colors.white, size: 13),
                  SizedBox(width: 5),
                  Text(
                    'Gérer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tap target (topmost) → open the offline maps manager
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const OfflineTrailsScreen(),
                    ),
                  );
                  _checkOfflineMap();
                },
              ),
            ),
          ),
        ],
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
              if (widget.onBack != null) {
                widget.onBack!();
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _titleColor(context)),
          ),
          Expanded(
            child: Text(
              context.watch<LocaleProvider>().t('settings.title'),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: MediaQuery.sizeOf(context).width < 360 ? 23 : 28,
                fontWeight: FontWeight.w800,
                color: _titleColor(context),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
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
    if (await showLogoutDialog(context)) {
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
        color: Theme.of(context).cardColor,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
