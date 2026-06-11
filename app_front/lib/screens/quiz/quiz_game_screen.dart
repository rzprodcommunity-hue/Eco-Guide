import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/locale_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../services/badge_service.dart';

class QuizGameScreen extends StatefulWidget {
  final String? category;

  const QuizGameScreen({super.key, this.category});

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen> {
  int _currentIndex = 0;
  int? _selectedOption;
  bool _confirmed = false;
  int _score = 0;
  int _correctCount = 0;
  bool _finished = false;

  late final List<_NatureQuestion> _questions;

  @override
  void initState() {
    super.initState();
    _questions = _NatureQuestion.bank();
  }

  void _selectOption(int idx) {
    if (_confirmed) return;
    setState(() => _selectedOption = idx);
  }

  void _confirmAnswer() {
    if (_selectedOption == null) return;
    final correct =
        _selectedOption == _questions[_currentIndex].correctIndex;
    setState(() {
      _confirmed = true;
      if (correct) {
        _correctCount++;
        _score += 10;
      }
    });
  }

  void _skip() {
    if (_currentIndex >= _questions.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedOption = null;
      _confirmed = false;
    });
  }

  void _next() {
    if (_currentIndex >= _questions.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedOption = null;
      _confirmed = false;
    });
  }

  Future<void> _finish() async {
    final lp = context.read<LocaleProvider>();
    final isEn = lp.languageCode == 'en';

    // Persist the result so points + badges actually count (offline-first).
    List<UserBadge> earned = const [];
    if (!_finished) {
      _finished = true;
      try {
        earned = await context.read<QuizProvider>().recordResult(
              score: _score,
              correctAnswers: _correctCount,
              totalQuestions: _questions.length,
              category: 'nature',
            );
      } catch (_) {
        // Persistence is best-effort; never block the result screen.
      }
    }
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              _correctCount >= _questions.length * 0.7
                  ? Icons.emoji_events_rounded
                  : Icons.psychology_rounded,
              color: _correctCount >= _questions.length * 0.7
                  ? Colors.amber
                  : AppTheme.primaryColor,
              size: 30,
            ),
            const SizedBox(width: 10),
            Text(lp.t('quiz.complete')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(lp.t('quiz.completeMsg'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            _statRow(lp.t('quiz.score'), '$_score'),
            _statRow(lp.t('quiz.correct'),
                '$_correctCount/${_questions.length}'),
            _statRow(lp.t('quiz.rate'),
                '${(_correctCount / _questions.length * 100).round()}%'),
            if (earned.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.military_tech_rounded,
                      color: Colors.amber, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isEn ? 'New badges!' : 'Nouveaux badges !',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...earned.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppTheme.primaryColor, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(b.label,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: Text(lp.t('quiz.back')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _currentIndex = 0;
                _selectedOption = null;
                _confirmed = false;
                _score = 0;
                _correctCount = 0;
                _finished = false;
              });
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor),
            child: Text(lp.t('quiz.replay'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LocaleProvider>();
    final isEn = lp.languageCode == 'en';
    final q = _questions[_currentIndex];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          isEn ? 'Nature Quiz' : 'Quiz Nature',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${lp.t('quiz.question')} ${_currentIndex + 1} ${lp.t('quiz.of')} ${_questions.length}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.help_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Progress dashes
              Row(
                children: List.generate(_questions.length, (i) {
                  final done = i <= _currentIndex;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: done
                              ? AppTheme.primaryColor
                              : const Color(0xFFE0CCAB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // Image with category badge
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: q.imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                          height: 200, color: Colors.grey[300]),
                      errorWidget: (_, _, _) => Container(
                        height: 200,
                        color: Colors.green.withValues(alpha: 0.2),
                        child: const Icon(Icons.image_not_supported,
                            size: 50, color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isEn ? q.categoryEn : q.categoryFr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Question
              Text(
                isEn ? q.questionEn : q.questionFr,
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800, height: 1.3),
              ),
              const SizedBox(height: 16),

              // Options
              ...List.generate(q.options.length, (i) {
                final letter = String.fromCharCode(65 + i); // A, B, C, D
                final isSelected = _selectedOption == i;
                final isCorrect = q.correctIndex == i;
                final showResult = _confirmed;
                Color borderColor =
                    Theme.of(context).dividerColor.withValues(alpha: 0.3);
                Color bgColor = Theme.of(context).cardColor;
                Color letterBg = Colors.white;
                Color letterColor =
                    Theme.of(context).colorScheme.onSurface;

                if (showResult) {
                  if (isCorrect) {
                    borderColor = AppTheme.primaryColor;
                    bgColor =
                        AppTheme.primaryColor.withValues(alpha: 0.08);
                    letterBg = AppTheme.primaryColor;
                    letterColor = Colors.white;
                  } else if (isSelected && !isCorrect) {
                    borderColor = const Color(0xFFE53935);
                    bgColor =
                        const Color(0xFFE53935).withValues(alpha: 0.08);
                    letterBg = const Color(0xFFE53935);
                    letterColor = Colors.white;
                  }
                } else if (isSelected) {
                  borderColor = AppTheme.primaryColor;
                  bgColor = AppTheme.primaryColor.withValues(alpha: 0.08);
                  letterBg = AppTheme.primaryColor;
                  letterColor = Colors.white;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => _selectOption(i),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: letterBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: borderColor, width: 1),
                            ),
                            child: Text(
                              letter,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: letterColor,
                                  fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isEn ? q.options[i].en : q.options[i].fr,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                          if (showResult && isCorrect)
                            const Icon(Icons.check_circle_rounded,
                                color: AppTheme.primaryColor, size: 22),
                          if (showResult && isSelected && !isCorrect)
                            const Icon(Icons.cancel_rounded,
                                color: Color(0xFFE53935), size: 22),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Eco-Guide Tip (shown after confirm)
              if (_confirmed)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                            AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded,
                          color: AppTheme.primaryColor, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEn ? 'Eco-Guide Tip' : 'Astuce Eco-Guide',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEn ? q.tipEn : q.tipFr,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  if (!_confirmed)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _skip,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                            isEn ? 'Skip Question' : 'Passer la question'),
                      ),
                    ),
                  if (!_confirmed) const SizedBox(width: 12),
                  Expanded(
                    flex: _confirmed ? 1 : 1,
                    child: ElevatedButton(
                      onPressed: _selectedOption == null
                          ? null
                          : (_confirmed ? _next : _confirmAnswer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _confirmed
                                ? (_currentIndex >= _questions.length - 1
                                    ? lp.t('quiz.finish')
                                    : lp.t('quiz.next'))
                                : (isEn ? 'Confirm Answer' : 'Confirmer'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.eco,
                        size: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                    Text(
                      isEn
                          ? 'Learn more about nature'
                          : 'En savoir plus sur la nature',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Option {
  final String fr;
  final String en;
  const _Option(this.fr, this.en);
}

class _NatureQuestion {
  final String imageUrl;
  final String categoryFr;
  final String categoryEn;
  final String questionFr;
  final String questionEn;
  final List<_Option> options;
  final int correctIndex;
  final String tipFr;
  final String tipEn;

  const _NatureQuestion({
    required this.imageUrl,
    required this.categoryFr,
    required this.categoryEn,
    required this.questionFr,
    required this.questionEn,
    required this.options,
    required this.correctIndex,
    required this.tipFr,
    required this.tipEn,
  });

  static List<_NatureQuestion> bank() => const [
        _NatureQuestion(
          imageUrl:
              'https://images.unsplash.com/photo-1465146344425-f00d5f5c8f07?w=800',
          categoryFr: 'Flore & Faune',
          categoryEn: 'Flora & Fauna',
          questionFr:
              "Laquelle de ces fleurs alpines protégées est connue sous le nom d'« Étoile d'argent » et pousse en haute altitude ?",
          questionEn:
              "Which of these protected alpine flowers is known as the 'Silver Star' and grows in high altitudes?",
          options: [
            _Option('Gentiana Verna (Gentiane printanière)',
                'Gentiana Verna (Spring Gentian)'),
            _Option(
                'Leontopodium nivale (Edelweiss)', 'Leontopodium nivale (Edelweiss)'),
            _Option('Aster des Alpes', 'Alpine Aster'),
            _Option('Lis martagon', 'Martagon Lily'),
          ],
          correctIndex: 1,
          tipFr:
              "L'Edelweiss est un symbole des Alpes. Elle est strictement protégée; la cueillir peut entraîner de lourdes amendes pour préserver l'écosystème.",
          tipEn:
              "The Edelweiss is a symbol of the Alps. It is strictly protected; picking it can result in heavy fines to preserve the ecosystem.",
        ),
        _NatureQuestion(
          imageUrl:
              'https://images.unsplash.com/photo-1444930694458-01babe71870c?w=800',
          categoryFr: 'Faune',
          categoryEn: 'Fauna',
          questionFr:
              "Quel animal emblématique des montagnes peut sauter jusqu'à 6 mètres de haut ?",
          questionEn:
              "Which iconic mountain animal can jump up to 6 meters high?",
          options: [
            _Option('Le chamois', 'The chamois'),
            _Option('Le bouquetin', 'The ibex'),
            _Option('Le lynx', 'The lynx'),
            _Option('La marmotte', 'The marmot'),
          ],
          correctIndex: 1,
          tipFr:
              "Le bouquetin est un excellent grimpeur. Observez-le toujours à distance pour ne pas le perturber.",
          tipEn:
              "The ibex is an excellent climber. Always observe it from a distance to avoid disturbing it.",
        ),
        _NatureQuestion(
          imageUrl:
              'https://images.unsplash.com/photo-1518608774889-b04d2abe7702?w=800',
          categoryFr: 'Écologie',
          categoryEn: 'Ecology',
          questionFr:
              "Quel pourcentage de l'eau douce mondiale provient des montagnes ?",
          questionEn:
              "What percentage of the world's freshwater comes from mountains?",
          options: [
            _Option('20%', '20%'),
            _Option('40%', '40%'),
            _Option('60%', '60%'),
            _Option('80%', '80%'),
          ],
          correctIndex: 2,
          tipFr:
              "Les montagnes sont les « châteaux d'eau » du monde. Protégez les cours d'eau en évitant tout déchet ou pollution.",
          tipEn:
              "Mountains are the 'water towers' of the world. Protect waterways by avoiding any waste or pollution.",
        ),
        _NatureQuestion(
          imageUrl:
              'https://images.unsplash.com/photo-1448375240586-882707db888b?w=800',
          categoryFr: 'Flore',
          categoryEn: 'Flora',
          questionFr:
              "Quel arbre méditerranéen peut vivre plus de 2000 ans ?",
          questionEn: "Which Mediterranean tree can live over 2000 years?",
          options: [
            _Option('Le chêne-liège', 'The cork oak'),
            _Option('Le pin parasol', 'The umbrella pine'),
            _Option('L\'olivier', 'The olive tree'),
            _Option('Le cyprès', 'The cypress'),
          ],
          correctIndex: 2,
          tipFr:
              "L'olivier est un témoin du temps. Certains spécimens en Méditerranée ont plus de 2000 ans !",
          tipEn:
              "The olive tree is a witness of time. Some specimens in the Mediterranean are over 2000 years old!",
        ),
        _NatureQuestion(
          imageUrl:
              'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800',
          categoryFr: 'Randonnée éco',
          categoryEn: 'Eco hiking',
          questionFr:
              "Quel est le principe N°1 d'une randonnée éco-responsable ?",
          questionEn:
              "What is the #1 principle of eco-responsible hiking?",
          options: [
            _Option('Marcher vite', 'Walk fast'),
            _Option('Ne laisser aucune trace', 'Leave no trace'),
            _Option('Prendre des souvenirs', 'Take souvenirs'),
            _Option('Crier dans la nature', 'Shout in nature'),
          ],
          correctIndex: 1,
          tipFr:
              "« Ne laisser aucune trace » : ramenez tous vos déchets, restez sur les sentiers, ne cueillez rien.",
          tipEn:
              "'Leave no trace': bring back all your waste, stay on trails, pick nothing.",
        ),
      ];
}
