import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/gpx_service.dart';
import 'eco_trails_screen.dart';
import 'history_screen.dart';
import 'offline_map_screen.dart';
import 'record_screen.dart';
import 'trail_view_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _importGpx(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    if (!path.toLowerCase().endsWith('.gpx')) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un fichier .gpx')),
      );
      return;
    }

    try {
      final trail = await GpxService().parseGpxFile(File(path));
      if (!context.mounted) return;
      if (trail.points.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun point trouvé dans ce GPX')),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TrailViewScreen(trail: trail)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la lecture du GPX: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F5),
      appBar: AppBar(
        // Brand pill: white-on-green logo + name.
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.explore, color: Color(0xFF22B53A), size: 18),
            ),
            const SizedBox(width: 12),
            const Text(
              'Eco-tracer',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF22B53A), Color(0xFF0E7A23)],
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero logo — brand-green tile so the white lotus reads cleanly.
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF22B53A), Color(0xFF0E7A23)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(255, 6, 82, 19).withValues(alpha: 0.30),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/logo.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.spa,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _MenuButton(
              icon: Icons.fiber_manual_record,
              color: const Color(0xFFE53935),
              label: 'Nouveau trajet',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecordScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _MenuButton(
              icon: Icons.history,
              color: const Color(0xFF3949AB),
              label: 'Mes trajets',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _MenuButton(
              icon: Icons.file_open,
              color: const Color(0xFF00897B),
              label: 'Importer un GPX',
              onTap: () => _importGpx(context),
            ),
            const SizedBox(height: 12),
            _MenuButton(
              icon: Icons.cloud_download,
              color: const Color(0xFF1E88E5),
              label: 'Sentiers Eco-Guide (en ligne)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EcoTrailsScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _MenuButton(
              icon: Icons.map,
              color: const Color(0xFF22B53A),
              label: 'Carte hors ligne (télécharger)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OfflineMapScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _MenuButton(
              icon: Icons.school_outlined,
              color: const Color(0xFFFFA000),
              label: 'Formation',
              onTap: () => _showFormation(context),
            ),
            const SizedBox(height: 12),
            _MenuButton(
              icon: Icons.support_agent_rounded,
              color: const Color(0xFF6A1B9A),
              label: 'Contact',
              onTap: () => _showContact(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showFormation(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _InfoSheet(
        icon: Icons.school_outlined,
        accent: Color(0xFFFFA000),
        title: 'Formation Eco-tracer',
        items: [
          _InfoItem(
            icon: Icons.play_circle_outline,
            label: 'Démarrer un trajet',
            text:
                'Touchez « Nouveau trajet » et autorisez la géolocalisation. '
                'Appuyez sur Démarrer pour enregistrer en arrière-plan.',
          ),
          _InfoItem(
            icon: Icons.cloud_download,
            label: 'Préparer le hors-ligne',
            text:
                'Téléchargez le pack « Jbel Chitana » depuis Carte hors ligne '
                'avant votre sortie : aucune connexion ne sera nécessaire.',
          ),
          _InfoItem(
            icon: Icons.share,
            label: 'Exporter en GPX',
            text:
                'Ouvrez un trajet dans « Mes trajets » et utilisez Partager '
                'pour exporter le fichier .gpx vers une autre application.',
          ),
          _InfoItem(
            icon: Icons.battery_charging_full,
            label: 'Conseil batterie',
            text:
                'Activez le mode économie d\'énergie et laissez l\'écran '
                'verrouillé : le GPS continue grâce à la notification active.',
          ),
        ],
      ),
    );
  }

  void _showContact(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _InfoSheet(
        icon: Icons.support_agent_rounded,
        accent: Color(0xFF6A1B9A),
        title: 'Nous contacter',
        items: [
          _InfoItem(
            icon: Icons.mail_outline,
            label: 'Email',
            text: 'contact@eco-guide.tn',
          ),
          _InfoItem(
            icon: Icons.phone_outlined,
            label: 'Téléphone',
            text: '+216 78 000 000',
          ),
          _InfoItem(
            icon: Icons.location_on_outlined,
            label: 'Adresse',
            text: 'Eco-Guide HQ, Tabarka, Tunisie',
          ),
          _InfoItem(
            icon: Icons.language,
            label: 'Site web',
            text: 'www.eco-guide.tn',
          ),
        ],
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String text;
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.text,
  });
}

class _InfoSheet extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final List<_InfoItem> items;

  const _InfoSheet({
    required this.icon,
    required this.accent,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 18 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2E1A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map(
            (it) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(it.icon, color: accent, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A2E1A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          it.text,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: Color(0xFF4A5D4F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2E1A),
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: color.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
