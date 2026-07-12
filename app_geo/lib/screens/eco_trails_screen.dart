import 'package:flutter/material.dart';

import '../models/trail.dart';
import '../services/remote_trail_service.dart';
import '../utils/formatters.dart';
import 'trail_qr_screen.dart';
import 'trail_view_screen.dart';

/// Lists Eco-Guide trails downloaded from Supabase, with a button to download
/// or update them. Each trail can be viewed (offline map) or turned into an
/// authorization QR code.
class EcoTrailsScreen extends StatefulWidget {
  const EcoTrailsScreen({super.key});

  @override
  State<EcoTrailsScreen> createState() => _EcoTrailsScreenState();
}

class _EcoTrailsScreenState extends State<EcoTrailsScreen> {
  final RemoteTrailService _service = RemoteTrailService();

  List<Trail> _trails = [];
  bool _loading = true;
  bool _updating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCached();
  }

  Future<void> _loadCached() async {
    final cached = await _service.loadCached();
    if (!mounted) return;
    setState(() {
      _trails = cached;
      _loading = false;
    });
    // Auto-update on first open when nothing is cached yet.
    if (cached.isEmpty) _update();
  }

  Future<void> _update() async {
    if (_updating) return;
    setState(() {
      _updating = true;
      _error = null;
    });
    try {
      final trails = await _service.refresh();
      if (!mounted) return;
      setState(() => _trails = trails);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${trails.length} sentier(s) à jour.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Échec de la mise à jour : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de contacter Supabase.')),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sentiers Eco-Guide'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _updating ? null : _update,
        icon: _updating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.cloud_download),
        label: Text(_updating ? 'Mise à jour…' : 'Mettre à jour'),
        backgroundColor: const Color(0xFF22B53A),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _update,
              child: _trails.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Icon(Icons.terrain,
                            size: 72, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _error ??
                                  'Aucun sentier téléchargé.\n'
                                      'Touchez « Mettre à jour » pour les '
                                      'télécharger depuis Eco-Guide (Supabase).',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: _trails.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, i) => _buildTile(_trails[i]),
                    ),
            ),
    );
  }

  Widget _buildTile(Trail trail) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: const Color(0xFF22B53A),
        child: Icon(Icons.hiking, color: Colors.white),
      ),
      title: Text(trail.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${formatDistance(trail.distanceMeters)} • ${trail.points.length} points',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Générer le QR',
            icon: const Icon(Icons.qr_code_2, color: const Color(0xFF22B53A)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TrailQrScreen(trail: trail)),
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TrailViewScreen(trail: trail)),
      ),
    );
  }
}
