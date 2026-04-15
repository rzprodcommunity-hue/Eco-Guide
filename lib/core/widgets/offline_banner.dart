import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';

/// Banner that appears at the top of the screen when in offline mode
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, _) {
        if (!connectivity.isOfflineMode) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            border: Border(
              bottom: BorderSide(
                color: Colors.orange.shade300,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off,
                size: 18,
                color: Colors.orange.shade800,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  connectivity.isOnline
                      ? 'Mode hors ligne - Backend non disponible'
                      : 'Mode hors ligne - Aucune connexion Internet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
              Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.orange.shade700,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small offline indicator badge for use in app bars
class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, _) {
        if (!connectivity.isOfflineMode) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade800,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                'Hors ligne',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
