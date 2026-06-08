import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/responsive.dart';

class FormationScreen extends StatelessWidget {
  const FormationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: Responsive.pagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ──
              Text(
                'Formation',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Le guide complet pour administrer la plateforme Eco-Guide.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),

              // ── Welcome banner ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.school_rounded, color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Bienvenue Administrateur !',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Depuis ce tableau de bord, vous gérez l\'ensemble du '
                      'contenu de l\'application mobile : sentiers de randonnée, '
                      'points d\'intérêt, quiz éducatifs, économie locale, '
                      'comptes utilisateurs et alertes de secours. Ce guide '
                      'vous accompagne pas à pas dans chacune de ces tâches.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.5,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Quick steps ──
              _sectionTitle(context, 'Premiers pas'),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(
                    child: _StepChip(
                      number: '1',
                      label: 'Connectez-vous avec votre compte administrateur.',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _StepChip(
                      number: '2',
                      label:
                          'Choisissez une section dans le menu de gauche.',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _StepChip(
                      number: '3',
                      label:
                          'Créez ou modifiez le contenu puis enregistrez.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Feature guide ──
              _sectionTitle(context, 'Guide des fonctionnalités'),
              const SizedBox(height: 12),
              const _FormationCard(
                icon: Icons.route,
                title: 'Gérer les sentiers',
                description:
                    'Créez, modifiez et publiez les sentiers de randonnée '
                    'visibles dans l\'application.',
                steps: [
                  'Cliquez sur « Créer un nouveau sentier ».',
                  'Renseignez le nom, la description, la difficulté et la région.',
                  'Tracez le parcours en touchant la carte, ou importez un '
                      'fichier GPX.',
                  'Cliquez sur « Calculer » : la distance, le dénivelé et la '
                      'durée sont estimés automatiquement (modifiables).',
                  'Ajoutez des photos et, si besoin, rattachez des points '
                      'd\'intérêt au sentier.',
                  'Cliquez sur « Enregistrer ».',
                ],
              ),
              const SizedBox(height: 16),
              const _FormationCard(
                icon: Icons.location_on,
                title: 'Ajouter des points d\'intérêt',
                description:
                    'Référencez les lieux remarquables : panoramas, faune, '
                    'flore, sources, sites historiques…',
                steps: [
                  'Placez le marqueur sur la carte (ou utilisez votre position).',
                  'Choisissez une catégorie et rédigez une description.',
                  'Ajoutez une photo et éventuellement une vidéo (MP4 ≤ 100 Mo).',
                  'Associez le point à un sentier si nécessaire.',
                  'Enregistrez : le point apparaît dans la liste filtrable.',
                ],
              ),
              const SizedBox(height: 16),
              const _FormationCard(
                icon: Icons.quiz,
                title: 'Créer des quiz',
                description:
                    'Proposez des questionnaires éducatifs pour sensibiliser '
                    'les randonneurs à l\'environnement.',
                steps: [
                  'Ajoutez une ou plusieurs questions.',
                  'Saisissez les réponses et désignez la bonne réponse.',
                  'Définissez les points attribués.',
                  'Enregistrez le quiz pour le rendre disponible.',
                ],
              ),
              const SizedBox(height: 16),
              const _FormationCard(
                icon: Icons.store,
                title: 'Économie locale',
                description:
                    'Mettez en avant les hébergements, guides et artisans '
                    'locaux autour des sentiers.',
                steps: [
                  'Ajoutez un service avec sa catégorie et sa localisation.',
                  'Renseignez le contact, le site web et une description.',
                  'Ajoutez une photo puis enregistrez.',
                ],
              ),
              const SizedBox(height: 16),
              const _FormationCard(
                icon: Icons.warning_amber_rounded,
                title: 'Suivre les alertes SOS',
                description:
                    'Recevez en temps réel les demandes de secours envoyées '
                    'depuis l\'application.',
                steps: [
                  'Une alarme sonore et une notification signalent une alerte.',
                  'Consultez la localisation GPS et le message du randonneur.',
                  'Filtrez sur « Actives uniquement » pour les urgences en cours.',
                  'Coordonnez les secours puis cliquez sur « Résoudre ».',
                ],
              ),
              const SizedBox(height: 16),
              const _FormationCard(
                icon: Icons.people,
                title: 'Gérer les utilisateurs',
                description:
                    'Consultez les comptes des randonneurs et leur activité.',
                steps: [
                  'Recherchez un utilisateur par nom ou e-mail.',
                  'Consultez la date d\'inscription et les statistiques globales.',
                  'Cliquez sur « Voir » pour afficher les SOS et messages '
                      'envoyés par l\'utilisateur.',
                  'Exportez la liste complète au format CSV si besoin.',
                ],
              ),
              const SizedBox(height: 28),

              // ── Best practices ──
              _sectionTitle(context, 'Bonnes pratiques'),
              const SizedBox(height: 12),
              _BulletCard(
                bullets: const [
                  'Rédigez des descriptions claires et mentionnez les '
                      'consignes de sécurité importantes.',
                  'Vérifiez toujours la position GPS d\'un sentier ou d\'un '
                      'point avant de l\'enregistrer.',
                  'Utilisez des photos de bonne qualité (la première photo '
                      'est l\'image principale).',
                  'Traitez les alertes SOS en priorité absolue.',
                  'Mettez régulièrement le contenu à jour (saisons, '
                      'fermetures, dangers temporaires).',
                ],
              ),
              const SizedBox(height: 28),

              // ── Help ──
              _sectionTitle(context, 'Besoin d\'aide ?'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.support_agent, color: AppColors.primary, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Une question ou un problème ? Contactez l\'équipe '
                        'support depuis la page Contact.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/contact'),
                      icon: const Icon(Icons.mail_outline, size: 18),
                      label: const Text('Contact'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
      );
}

class _StepChip extends StatelessWidget {
  final String number;
  final String label;
  const _StepChip({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              number,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String> steps;

  const _FormationCard({
    required this.icon,
    required this.title,
    required this.description,
    this.steps = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.primary, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...steps.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${e.key + 1}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.value,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.8),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _BulletCard extends StatelessWidget {
  final List<String> bullets;
  const _BulletCard({required this.bullets});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: bullets
            .map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_circle,
                          color: AppColors.success, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        b,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.8),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
