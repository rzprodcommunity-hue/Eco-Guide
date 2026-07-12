import 'package:flutter/material.dart';

import '../models/trail.dart';
import '../services/storage_service.dart';
import '../utils/formatters.dart';
import 'trail_view_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final StorageService _storage = StorageService();
  late Future<List<Trail>> _future;

  @override
  void initState() {
    super.initState();
    _future = _storage.listTrails();
  }

  void _reload() {
    setState(() => _future = _storage.listTrails());
  }

  Future<void> _delete(Trail trail) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer définitivement « ${trail.name} » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _storage.deleteTrail(trail);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes trajets')),
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
                  'Aucun trajet enregistré.\nDémarrez un nouvel enregistrement depuis l\'accueil.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              itemCount: trails.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final t = trails[i];
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: const Color(0xFF22B53A),
                    child: Icon(Icons.route, color: Colors.white),
                  ),
                  title: Text(t.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${formatDateTime(t.startedAt)}\n'
                    '${formatDistance(t.distanceMeters)} • '
                    '${formatDuration(t.duration)}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(t),
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrailViewScreen(trail: t),
                      ),
                    );
                    _reload();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
