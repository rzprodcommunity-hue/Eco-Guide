import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/trail.dart';
import '../services/trail_qr.dart';

/// Shows a signed QR code that authorizes the selected [trail]. The user scans
/// it from app_front (Paramètres → Déverrouiller un sentier) to unlock the
/// "Démarrer" button for this trail.
class TrailQrScreen extends StatelessWidget {
  final Trail trail;
  const TrailQrScreen({super.key, required this.trail});

  @override
  Widget build(BuildContext context) {
    final payload = TrailQr.build(trailId: trail.id, trailName: trail.name);

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR du sentier'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code_2, size: 56, color: const Color(0xFF22B53A)),
              const SizedBox(height: 12),
              Text(
                trail.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF22B53A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 14, color: const Color(0xFF22B53A)),
                    SizedBox(width: 6),
                    Text(
                      'Valable 24 heures',
                      style: TextStyle(
                        color: const Color(0xFF22B53A),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: payload,
                  version: QrVersions.auto,
                  size: 240,
                  gapless: false,
                  backgroundColor: Colors.white,
                  errorStateBuilder: (context, error) => const SizedBox(
                    width: 240,
                    height: 240,
                    child: Center(
                      child: Text(
                        'Impossible de générer le QR.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF22B53A).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: const Color(0xFF22B53A)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Depuis Eco-Guide : Paramètres → Déverrouiller un '
                        'sentier (QR), puis scannez ce code pour activer le '
                        'bouton « Démarrer ». Le code expire après 24 h — '
                        'rouvrez cet écran pour en générer un nouveau.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: payload));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copié.')),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copier le code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
