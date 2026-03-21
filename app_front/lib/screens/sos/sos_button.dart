import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/sos_service.dart';

class SosButton extends StatelessWidget {
  const SosButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'sosButton',
      backgroundColor: AppTheme.sosColor,
      onPressed: () => _showSosDialog(context),
      child: const Icon(Icons.sos, color: Colors.white, size: 28),
    );
  }

  void _showSosDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SosDialog(),
    );
  }
}

class SosDialog extends StatefulWidget {
  const SosDialog({super.key});

  @override
  State<SosDialog> createState() => _SosDialogState();
}

class _SosDialogState extends State<SosDialog> {
  final _messageController = TextEditingController();
  final _contactController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _sendSosAlert() async {
    final authProvider = context.read<AuthProvider>();

    if (!authProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez etre connecte pour envoyer une alerte SOS')),
      );
      return;
    }

    if (authProvider.isDemoUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le mode demo ne permet pas d\'envoyer une alerte SOS. Connectez-vous avec un vrai compte.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final apiClient = context.read<ApiClient>();
      final sosService = SosService(apiClient);

      await sosService.sendAlert(
        latitude: AppConstants.defaultLatitude,
        longitude: AppConstants.defaultLongitude,
        message: _messageController.text.isEmpty ? null : _messageController.text,
        emergencyContact: _contactController.text.isEmpty ? null : _contactController.text,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alerte SOS envoyee avec succes!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        final message = e.statusCode == 401
            ? 'Session invalide. Veuillez vous reconnecter avant d\'envoyer une alerte SOS.'
            : 'Erreur: ${e.message}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _callEmergency() async {
    final uri = Uri.parse('tel:112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppTheme.sosColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sos, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Text('Urgence SOS'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Envoyez une alerte avec votre position GPS aux services de secours.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Quick call button
            ElevatedButton.icon(
              onPressed: _callEmergency,
              icon: const Icon(Icons.phone),
              label: const Text('Appeler les secours (112)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.sosColor,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            const Divider(),
            const SizedBox(height: 16),

            // Message field
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message (optionnel)',
                hintText: 'Decrivez votre situation...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Emergency contact field
            TextField(
              controller: _contactController,
              decoration: const InputDecoration(
                labelText: 'Contact d\'urgence (optionnel)',
                hintText: '+212 600 000 000',
                prefixIcon: Icon(Icons.contact_phone),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isSending ? null : _sendSosAlert,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.sosColor,
            foregroundColor: Colors.white,
          ),
          child: _isSending
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Envoyer alerte'),
        ),
      ],
    );
  }
}
