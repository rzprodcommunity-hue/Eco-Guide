import 'package:flutter/material.dart';
import '../../services/partner_service.dart';

class PartnerRegistrationSheet extends StatefulWidget {
  const PartnerRegistrationSheet({super.key});

  @override
  State<PartnerRegistrationSheet> createState() =>
      _PartnerRegistrationSheetState();
}

class _PartnerRegistrationSheetState extends State<PartnerRegistrationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String _category = 'guide';
  bool _submitting = false;
  int _step = 0; // 0 = form, 1 = success

  static const _categories = [
    {'key': 'guide', 'label': 'Guide', 'icon': Icons.person},
    {'key': 'accommodation', 'label': 'Hébergement', 'icon': Icons.hotel},
    {'key': 'artisan', 'label': 'Artisan', 'icon': Icons.handyman},
    {'key': 'restaurant', 'label': 'Restaurant', 'icon': Icons.restaurant},
    {'key': 'equipment', 'label': 'Équipement', 'icon': Icons.backpack},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await PartnerService.submit(
        businessName: _nameCtrl.text.trim(),
        category: _category,
        description: _descCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
      );
      if (mounted) setState(() { _step = 1; _submitting = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: _step == 1 ? _buildSuccess(primary) : _buildForm(theme, primary),
        ),
      ),
    );
  }

  Widget _buildSuccess(Color primary) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, color: primary, size: 48),
          ),
          const SizedBox(height: 20),
          const Text(
            'Demande envoyée !',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Votre demande de partenariat a été soumise. L\'administrateur va l\'examiner et vous contactera par email.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Fermer',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme, Color primary) {
    final onSurface = theme.colorScheme.onSurface;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 44, height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D4037),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.store_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Devenir Partenaire',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('Rejoignez notre réseau éco-responsable',
                          style: TextStyle(
                              fontSize: 12,
                              color: onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded,
                      color: onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Category selector
            Text('Type d\'activité',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final sel = _category == cat['key'];
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat['key'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: sel ? primary : theme.cardColor,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: sel
                              ? primary
                              : theme.dividerColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(cat['icon'] as IconData,
                              size: 15,
                              color: sel ? Colors.white : primary),
                          const SizedBox(width: 6),
                          Text(cat['label'] as String,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: sel
                                      ? Colors.white
                                      : onSurface)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            _field(
              controller: _nameCtrl,
              label: 'Nom de l\'établissement',
              icon: Icons.business_rounded,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _descCtrl,
              label: 'Description',
              icon: Icons.description_rounded,
              maxLines: 3,
              validator: (v) =>
                  v == null || v.trim().length < 20
                      ? 'Au moins 20 caractères'
                      : null,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _phoneCtrl,
              label: 'Téléphone',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _emailCtrl,
              label: 'Email de contact',
              icon: Icons.email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Champ obligatoire';
                if (!v.contains('@')) return 'Email invalide';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _field(
              controller: _addressCtrl,
              label: 'Adresse (optionnel)',
              icon: Icons.location_on_rounded,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Envoyer la demande',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
          fontSize: 14, color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: theme.cardColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
