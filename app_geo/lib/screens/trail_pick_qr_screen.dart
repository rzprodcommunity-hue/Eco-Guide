import 'package:flutter/material.dart';

import '../models/trail.dart';
import '../services/storage_service.dart';
import '../utils/formatters.dart';
import 'trail_qr_screen.dart';

/// Lets the user pick one of their saved trails and generate an
/// authorization QR code for it (valid 24h).
class TrailPickQrScreen extends StatefulWidget {
  const TrailPickQrScreen({super.key});

  @override
  State<TrailPickQrScreen> createState() => _TrailPickQrScreenState();
}

class _TrailPickQrScreenState extends State<TrailPickQrScreen> {
  final StorageService _storage = StorageService();
  late Future<List<Trail>> _future;

  @override
  void initState() {
    super.initState();
    _future = _storage.listTrails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Générer un QR de sentier'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<List<Trail>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final trails = snap.data ?? const <Trail>[];
          if (trails.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aucun sentier enregistré.\n'
                  'Enregistrez ou importez un trajet, puis revenez ici pour '
                  'générer son QR code.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                color: const Color(0xFF22B53A).withValues(alpha: 0.07),
                child: const Text(
                  'Sélectionnez un sentier pour afficher son QR code '
                  'd\'autorisation (valable 24 heures).',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: trails.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final t = trails[i];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: const Color(0xFF22B53A),
                        child: Icon(Icons.qr_code_2, color: Colors.white),
                      ),
                      title: Text(
                        t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${formatDateTime(t.startedAt)} • '
                        '${formatDistance(t.distanceMeters)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TrailQrScreen(trail: t),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
