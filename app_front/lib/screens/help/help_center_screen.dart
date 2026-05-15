import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBg : AppTheme.backgroundColor;
    final surface = isDark ? AppTheme.darkSurface : Colors.white;
    final primary =   AppTheme.primaryColor;
    final textMain = isDark ? AppTheme.darkTextMain : AppTheme.textPrimary;
    final textSub = isDark ? AppTheme.darkTextSub : AppTheme.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Centre d\'aide',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Guide'),
            Tab(text: 'FAQ'),
            Tab(text: 'Contact'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GuideTab(
            isDark: isDark,
            surface: surface,
            primary: primary,
            textMain: textMain,
            textSub: textSub,
          ),
          _FaqTab(
            isDark: isDark,
            surface: surface,
            primary: primary,
            textMain: textMain,
            textSub: textSub,
          ),
          _ContactTab(
            isDark: isDark,
            surface: surface,
            primary: primary,
            textMain: textMain,
            textSub: textSub,
          ),
        ],
      ),
    );
  }
}

// ─── GUIDE TAB ───────────────────────────────────────────────────────────────

class _GuideTab extends StatelessWidget {
  final bool isDark;
  final Color surface, primary, textMain, textSub;

  const _GuideTab({
    required this.isDark,
    required this.surface,
    required this.primary,
    required this.textMain,
    required this.textSub,
  });

  static const _features = [
    _Feature(
      icon: Icons.map_rounded,
      color: Color(0xFF1565C0),
      title: 'Carte Interactive',
      steps: [
        'Ouvrez l\'onglet "Carte" depuis la barre de navigation.',
        'Pincez pour zoomer ou dézoomez sur la carte.',
        'Appuyez sur un marqueur pour voir les détails d\'un sentier ou POI.',
        'Activez le mode hors-ligne pour utiliser la carte sans internet.',
        'Le bouton SOS envoie votre position en cas d\'urgence.',
      ],
    ),
    _Feature(
      icon: Icons.hiking_rounded,
      color: Color(0xFF2E7D32),
      title: 'Sentiers de Randonnée',
      steps: [
        'Accédez à "Sentiers" depuis la navigation principale.',
        'Filtrez par difficulté : Facile, Modéré, Difficile.',
        'Appuyez sur un sentier pour voir la distance, dénivelé et durée.',
        'Téléchargez un sentier en mode hors-ligne via l\'icône ↓.',
        'Démarrez la navigation GPS depuis la page de détail.',
      ],
    ),
    _Feature(
      icon: Icons.place_rounded,
      color: Color(0xFF6A1B9A),
      title: 'Points d\'Intérêt (POI)',
      steps: [
        'Explorez les POIs depuis l\'onglet dédié ou sur la carte.',
        'Chaque POI affiche son type : cascade, sommet, vue panoramique…',
        'Activez le Voice-over (icône 🔊) pour écouter la description.',
        'Consultez la galerie photo et les vidéos associées.',
        'Lancez la navigation vers le POI depuis son écran de détail.',
      ],
    ),
    _Feature(
      icon: Icons.quiz_rounded,
      color: Color(0xFFE65100),
      title: 'Quiz Nature',
      steps: [
        'Ouvrez l\'onglet "Quiz" et choisissez une catégorie.',
        'Répondez aux questions sur la faune, flore et écologie.',
        'Votre score est sauvegardé et comparé à vos sessions précédentes.',
        'Gagnez des badges en complétant des catégories.',
        'Consultez le classement général dans votre profil.',
      ],
    ),
    _Feature(
      icon: Icons.sos_rounded,
      color: Color(0xFFC62828),
      title: 'Alerte SOS',
      steps: [
        'Maintenez le bouton SOS rouge pendant 2 secondes pour l\'activer.',
        'Votre position GPS est automatiquement jointe à l\'alerte.',
        'L\'alerte est envoyée aux secours même sans connexion internet.',
        'Une file d\'attente offline synchronise l\'envoi dès que le réseau revient.',
        'Restez calme et restez sur place après avoir envoyé l\'alerte.',
      ],
    ),
    _Feature(
      icon: Icons.store_rounded,
      color: Color(0xFF00695C),
      title: 'Services Locaux',
      steps: [
        'L\'onglet "Services" liste les guides, hébergements et artisans.',
        'Filtrez par type de service selon vos besoins.',
        'Appelez ou envoyez un message directement depuis l\'app.',
        'Consultez les avis et photos de chaque prestataire.',
        'Ajoutez un service en favori pour le retrouver facilement.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        _SectionBanner(
          icon: Icons.menu_book_rounded,
          title: 'Comment utiliser Eco-Guide',
          subtitle: 'Suivez ces guides pas-à-pas pour maîtriser chaque fonctionnalité.',
          primary: primary,
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        ..._features.map(
          (f) => _FeatureCard(
            feature: f,
            isDark: isDark,
            surface: surface,
            textMain: textMain,
            textSub: textSub,
          ),
        ),
      ],
    );
  }
}

class _Feature {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> steps;

  const _Feature({
    required this.icon,
    required this.color,
    required this.title,
    required this.steps,
  });
}

class _FeatureCard extends StatefulWidget {
  final _Feature feature;
  final bool isDark;
  final Color surface, textMain, textSub;

  const _FeatureCard({
    required this.feature,
    required this.isDark,
    required this.surface,
    required this.textMain,
    required this.textSub,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.feature;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark
              ? AppTheme.darkBorder
              : Colors.grey.withValues(alpha: 0.15),
        ),
        boxShadow: widget.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (v) => setState(() => _expanded = v),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: f.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(f.icon, color: f.color, size: 22),
          ),
          title: Text(
            f.title,
            style: TextStyle(
              color: widget.textMain,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          trailing: AnimatedRotation(
            turns: _expanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: f.color,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: List.generate(
                  f.steps.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: f.color,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f.steps[i],
                            style: TextStyle(
                              color: widget.textSub,
                              fontSize: 13.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FAQ TAB ─────────────────────────────────────────────────────────────────

class _FaqTab extends StatelessWidget {
  final bool isDark;
  final Color surface, primary, textMain, textSub;

  const _FaqTab({
    required this.isDark,
    required this.surface,
    required this.primary,
    required this.textMain,
    required this.textSub,
  });

  static const _faqs = [
    _Faq(
      q: 'Comment utiliser l\'application sans connexion internet ?',
      a: 'Téléchargez vos sentiers et cartes depuis leur page de détail en appuyant sur l\'icône de téléchargement. Ils seront disponibles hors-ligne. Les alertes SOS peuvent aussi être envoyées hors-ligne et seront synchronisées dès le retour de la connexion.',
    ),
    _Faq(
      q: 'Comment créer un compte Eco-Guide ?',
      a: 'Depuis l\'écran de connexion, appuyez sur "Créer un compte". Renseignez votre nom, email et mot de passe. Votre compte est sécurisé via Supabase Authentication.',
    ),
    _Faq(
      q: 'Comment envoyer une alerte SOS ?',
      a: 'Maintenez le bouton SOS rouge (en bas au centre) pendant 2 secondes. Votre position GPS sera automatiquement incluse. L\'alerte fonctionne même sans internet grâce à la file d\'attente hors-ligne.',
    ),
    _Faq(
      q: 'Pourquoi le Voice-over POI ne fonctionne-t-il pas ?',
      a: 'Assurez-vous que le volume de votre appareil est activé. Sur iOS, vérifiez que le mode silencieux est désactivé. La synthèse vocale utilise la langue de l\'application (FR, EN ou AR).',
    ),
    _Faq(
      q: 'Comment changer la langue de l\'application ?',
      a: 'Allez dans Paramètres → faites défiler jusqu\'à la section "Langue" → choisissez Français, English ou العربية. L\'interface se met à jour immédiatement.',
    ),
    _Faq(
      q: 'Mes scores de quiz sont-ils sauvegardés ?',
      a: 'Oui, vos scores sont synchronisés avec votre compte en ligne. Ils sont visibles depuis votre profil et dans la page Quiz sous chaque catégorie.',
    ),
    _Faq(
      q: 'Comment activer le mode sombre ?',
      a: 'Allez dans Paramètres → section "Affichage" → activez le switch "Mode sombre". Le thème s\'applique instantanément sans redémarrage.',
    ),
    _Faq(
      q: 'Comment signaler un problème dans l\'application ?',
      a: 'Rendez-vous dans l\'onglet Contact du Centre d\'aide et envoyez-nous un email détaillant le problème. Incluez votre version d\'appareil et les étapes pour reproduire le bug.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        _SectionBanner(
          icon: Icons.help_outline_rounded,
          title: 'Questions Fréquentes',
          subtitle:
              'Retrouvez les réponses aux questions les plus posées par nos utilisateurs.',
          primary: primary,
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        ..._faqs.map(
          (faq) => _FaqCard(
            faq: faq,
            isDark: isDark,
            surface: surface,
            primary: primary,
            textMain: textMain,
            textSub: textSub,
          ),
        ),
      ],
    );
  }
}

class _Faq {
  final String q, a;
  const _Faq({required this.q, required this.a});
}

class _FaqCard extends StatefulWidget {
  final _Faq faq;
  final bool isDark;
  final Color surface, primary, textMain, textSub;

  const _FaqCard({
    required this.faq,
    required this.isDark,
    required this.surface,
    required this.primary,
    required this.textMain,
    required this.textSub,
  });

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: widget.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDark
              ? AppTheme.darkBorder
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (v) => setState(() => _expanded = v),
          leading: Icon(
            Icons.help_center_rounded,
            color: widget.primary,
            size: 22,
          ),
          title: Text(
            widget.faq.q,
            style: TextStyle(
              color: widget.textMain,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          trailing: AnimatedRotation(
            turns: _expanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: widget.primary,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.faq.a,
                  style: TextStyle(
                    color: widget.textSub,
                    fontSize: 13.5,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CONTACT TAB ─────────────────────────────────────────────────────────────

class _ContactTab extends StatelessWidget {
  final bool isDark;
  final Color surface, primary, textMain, textSub;

  const _ContactTab({
    required this.isDark,
    required this.surface,
    required this.primary,
    required this.textMain,
    required this.textSub,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        _SectionBanner(
          icon: Icons.contact_support_rounded,
          title: 'Contactez-nous',
          subtitle:
              'Notre équipe est disponible pour vous aider du lundi au vendredi.',
          primary: primary,
          isDark: isDark,
        ),
        const SizedBox(height: 24),
        _ContactCard(
          icon: Icons.email_rounded,
          color: const Color(0xFF1565C0),
          title: 'Email Support',
          subtitle: 'support@ecoguide.dz',
          detail: 'Réponse sous 24-48h en jours ouvrables.',
          isDark: isDark,
          surface: surface,
          textMain: textMain,
          textSub: textSub,
        ),
        const SizedBox(height: 12),
        _ContactCard(
          icon: Icons.bug_report_rounded,
          color: const Color(0xFFC62828),
          title: 'Signaler un Bug',
          subtitle: 'bugs@ecoguide.dz',
          detail: 'Décrivez le problème et votre modèle d\'appareil.',
          isDark: isDark,
          surface: surface,
          textMain: textMain,
          textSub: textSub,
        ),
        const SizedBox(height: 12),
        _ContactCard(
          icon: Icons.lightbulb_rounded,
          color: const Color(0xFFE65100),
          title: 'Suggérer une Fonctionnalité',
          subtitle: 'feedback@ecoguide.dz',
          detail: 'Vos idées nous aident à améliorer l\'application.',
          isDark: isDark,
          surface: surface,
          textMain: textMain,
          textSub: textSub,
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Version 1.0.0 · Eco-Guide Algeria\nDéveloppé avec ❤️ pour les randonneurs algériens.',
                  style: TextStyle(
                    color: textSub,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle, detail;
  final bool isDark;
  final Color surface, textMain, textSub;

  const _ContactCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.isDark,
    required this.surface,
    required this.textMain,
    required this.textSub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark ? AppTheme.darkBorder : Colors.grey.withValues(alpha: 0.15),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textMain,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    color: textSub,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SHARED WIDGETS ──────────────────────────────────────────────────────────

class _SectionBanner extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color primary;
  final bool isDark;

  const _SectionBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary,
            primary.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
