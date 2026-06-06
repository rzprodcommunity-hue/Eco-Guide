import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers/sos_alerts_provider.dart';
import '../../core/models/sos_alert_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/responsive.dart';

class SosAlertsScreen extends StatefulWidget {
  const SosAlertsScreen({super.key});

  @override
  State<SosAlertsScreen> createState() => _SosAlertsScreenState();
}

class _SosAlertsScreenState extends State<SosAlertsScreen> {
  bool _showActiveOnly = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SosAlertsProvider>().loadAlerts(activeOnly: _showActiveOnly);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SosAlertsProvider>();

    final infoChildren = <Widget>[
      if (provider.isAlarmPlaying)
        ElevatedButton.icon(
          icon: const Icon(Icons.volume_off, color: Colors.white),
          label: const Text(
            'COUPER L\'ALARME',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
          onPressed: () => provider.stopAlarm(),
        ),
      if (provider.activeAlerts.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${provider.activeAlerts.length} alerte(s) active(s)',
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      Text(
        '${provider.alerts.length} alertes au total',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize: 16,
        ),
      ),
    ];

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Actives uniquement'),
        const SizedBox(width: 8),
        Switch(
          value: _showActiveOnly,
          onChanged: (value) {
            setState(() => _showActiveOnly = value);
            provider.loadAlerts(activeOnly: value);
          },
          activeColor: AppColors.primary,
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: () =>
              provider.loadAlerts(activeOnly: _showActiveOnly),
          icon: const Icon(Icons.refresh),
          tooltip: 'Rafraichir',
        ),
      ],
    );

    return Padding(
      padding: Responsive.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: infoChildren,
              ),
              controls,
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.alerts.isEmpty
                ? _buildEmptyState()
                : _buildAlertsList(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 80,
            color: AppColors.success.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune alerte',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showActiveOnly
                ? 'Aucune alerte active en ce moment'
                : 'Aucune alerte enregistree',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList(SosAlertsProvider provider) {
    return ListView.builder(
      itemCount: provider.alerts.length,
      itemBuilder: (context, index) {
        final alert = provider.alerts[index];
        return _buildAlertCard(alert, provider);
      },
    );
  }

  Widget _buildAlertCard(SosAlertModel alert, SosAlertsProvider provider) {
    final isActive = !alert.isResolved;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isActive ? Border.all(color: AppColors.error, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.error.withOpacity(0.1)
                  : Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? Icons.warning : Icons.check_circle,
                  color: isActive ? AppColors.error : AppColors.success,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isActive ? 'ALERTE ACTIVE' : 'ALERTE RESOLUE',
                        style: TextStyle(
                          color: isActive ? AppColors.error : AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Emise le ${DateFormat('dd/MM/yyyy a HH:mm').format(alert.createdAt)}',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  ElevatedButton.icon(
                    onPressed: () => _confirmResolve(alert, provider),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Resoudre'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserHeader(alert),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.badge_outlined,
                        label: 'ID Utilisateur',
                        value: alert.userId,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        icon: Icons.phone,
                        label: 'Contact d\'urgence',
                        value: alert.emergencyContact ?? '-',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoItem(
                  icon: Icons.location_on,
                  label: 'Coordonnees GPS',
                  value:
                      '${alert.latitude.toStringAsFixed(6)}, ${alert.longitude.toStringAsFixed(6)}',
                ),
                if (alert.message != null && alert.message!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildInfoItem(
                    icon: Icons.message,
                    label: 'Message',
                    value: alert.message!,
                  ),
                ],
                if (alert.resolvedAt != null) ...[
                  const SizedBox(height: 16),
                  _buildInfoItem(
                    icon: Icons.access_time,
                    label: 'Resolue le',
                    value: DateFormat(
                      'dd/MM/yyyy a HH:mm',
                    ).format(alert.resolvedAt!),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openMaps(alert),
                      icon: const Icon(Icons.map, size: 18),
                      label: const Text('Voir sur la carte'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _copyCoordinates(alert),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copier'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader(SosAlertModel alert) {
    final profile = alert.profile;
    final hasProfile = profile != null;
    final name = hasProfile ? profile.fullName : 'Utilisateur inconnu';
    final email = profile?.email;
    final phone = profile?.phone;
    final emergency = alert.emergencyContact;
    final initials = hasProfile ? profile.initials : '?';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(profile?.avatarUrl, initials),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (email != null && email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          email,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (phone != null && phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          phone,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (!hasProfile) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Aucun profil associe',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Call button (uses phone profile or emergencyContact fallback)
          if ((phone != null && phone.isNotEmpty) ||
              (emergency != null && emergency.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ElevatedButton.icon(
                onPressed: () => _callPhone(
                  (phone != null && phone.isNotEmpty) ? phone : emergency!,
                ),
                icon: const Icon(Icons.call, size: 18),
                label: const Text('Appeler'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          if (email != null && email.isNotEmpty)
            IconButton(
              onPressed: () => _copyText(email, 'Email copie'),
              icon: Icon(
                Icons.copy,
                size: 18,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              tooltip: 'Copier email',
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String initials) {
    const double size = 52;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );

    if (avatarUrl == null || avatarUrl.isEmpty) return placeholder;

    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      ),
    );
  }

  Future<void> _callPhone(String rawNumber) async {
    final number = rawNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (number.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Numero invalide')),
        );
      }
      return;
    }
    final uri = Uri(scheme: 'tel', path: number);
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de lancer l\'appel')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur appel: $e')),
        );
      }
    }
  }

  void _copyText(String text, String successMessage) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successMessage)),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmResolve(SosAlertModel alert, SosAlertsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resoudre l\'alerte'),
        content: const Text(
          'Confirmez-vous que cette alerte a ete traitee et resolue ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.resolveAlert(alert.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alerte marquee comme resolue'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _openMaps(SosAlertModel alert) {
    final alertPosition = LatLng(alert.latitude, alert.longitude);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 700,
            height: 520,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.error.withOpacity(0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppColors.error,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Localisation de l\'alerte SOS',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lat: ${alert.latitude.toStringAsFixed(6)}  |  Lng: ${alert.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // Map
                Expanded(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: alertPosition,
                      initialZoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
                        userAgentPackageName: 'com.ecoguide.backoffice',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: alertPosition,
                            width: 60,
                            height: 60,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.error.withOpacity(0.15),
                                  ),
                                ),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.error.withOpacity(0.3),
                                  ),
                                ),
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.error,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.error.withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Footer actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: '${alert.latitude}, ${alert.longitude}',
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Coordonnees copiees dans le presse-papiers',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copier coordonnees'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Fermer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _copyCoordinates(SosAlertModel alert) {
    Clipboard.setData(
      ClipboardData(text: '${alert.latitude}, ${alert.longitude}'),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coordonnees copiees dans le presse-papiers'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}
