import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/quiz_provider.dart';

class QuizGameScreen extends StatefulWidget {
  final String? category;

  const QuizGameScreen({super.key, this.category});

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizProvider>().loadRandomQuizzes(
        count: 10,
        category: widget.category,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuizProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : provider.quizzes.isEmpty
            ? _buildEmptyState()
            : provider.isFinished
            ? _buildResultScreen(provider)
            : _buildQuizContent(provider),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Aucun quiz disponible',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Revenez plus tard pour de nouveaux quiz.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen(QuizProvider provider) {
    final percentage = provider.totalQuestions > 0
        ? (provider.correctAnswers / provider.totalQuestions * 100).round()
        : 0;
    final isGreat = percentage >= 70;

    // Submit score when showing results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.finishQuiz();
    });

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
              const Expanded(
                child: Text(
                  'Resultats',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isGreat
                          ? Colors.amber.withValues(alpha: 0.1)
                          : AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isGreat ? Icons.emoji_events : Icons.psychology,
                      size: 80,
                      color: isGreat ? Colors.amber : AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    isGreat ? 'Félicitations!' : 'Bien joué!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vous avez terminé le quiz',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildResultStat(
                              'Score',
                              '${provider.score}',
                              Icons.star,
                              Colors.amber,
                            ),
                            Container(
                              width: 1,
                              height: 50,
                              color: Colors.grey[200],
                            ),
                            _buildResultStat(
                              'Correct',
                              '${provider.correctAnswers}/${provider.totalQuestions}',
                              Icons.check_circle,
                              Colors.green,
                            ),
                            Container(
                              width: 1,
                              height: 50,
                              color: Colors.grey[200],
                            ),
                            _buildResultStat(
                              'Taux',
                              '$percentage%',
                              Icons.percent,
                              AppTheme.primaryColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          child: const Text(
                            'Retour',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            provider.restart();
                            provider.loadRandomQuizzes(
                              count: 10,
                              category: widget.category,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Rejouer',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildQuizContent(QuizProvider provider) {
    final quiz = provider.currentQuiz!;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.only(
            top: 16,
            bottom: 8,
            left: 16,
            right: 16,
          ),
          color: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Column(
                children: [
                  Text(
                    'Nature Quiz',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Question ${provider.currentIndex + 1} of ${provider.totalQuestions}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => _showHelpDialog(),
                icon: Icon(
                  Icons.help_outline,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),

        // Progress Dots
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              provider.totalQuestions,
              (index) => Container(
                width: 24,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: index <= provider.currentIndex
                      ? AppTheme.primaryColor
                      : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Container for Image + Question + Answers
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      // Image
                      if (quiz.imageUrl != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: quiz.imageUrl!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  height: 180,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  height: 180,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image, size: 48),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE67E22),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  quiz.categoryDisplayName,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Container(
                          height: 180,
                          decoration: const BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.quiz,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        ),

                      // Question & Options
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quiz.question,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Options
                            ...List.generate(quiz.answers.length, (index) {
                              final isSelected =
                                  provider.selectedAnswer == index;
                              final isCorrect =
                                  index == quiz.correctAnswerIndex;
                              final showResult = provider.answered;

                              Color backgroundColor = Theme.of(
                                context,
                              ).cardColor;
                              Color borderColor = Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.1);
                              Color textColor = Theme.of(
                                context,
                              ).colorScheme.onSurface;
                              Color letterBgColor = Theme.of(
                                context,
                              ).scaffoldBackgroundColor;
                              Color letterColor = Theme.of(
                                context,
                              ).colorScheme.onSurface;

                              if (showResult) {
                                if (isCorrect) {
                                  backgroundColor = Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.15);
                                  borderColor = Theme.of(context).primaryColor;
                                  letterBgColor = Theme.of(
                                    context,
                                  ).primaryColor;
                                  letterColor = Colors.white;
                                } else if (isSelected && !isCorrect) {
                                  backgroundColor = Colors.red.withValues(
                                    alpha: 0.15,
                                  );
                                  borderColor = Colors.red;
                                  letterBgColor = Colors.red;
                                  letterColor = Colors.white;
                                }
                              } else if (isSelected) {
                                backgroundColor = Theme.of(context).cardColor;
                                borderColor = Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5);
                                letterBgColor = Theme.of(
                                  context,
                                ).colorScheme.onSurface;
                                letterColor = Theme.of(
                                  context,
                                ).colorScheme.surface;
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GestureDetector(
                                  onTap: provider.answered
                                      ? null
                                      : () => provider.selectAnswer(index),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: backgroundColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: borderColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: letterBgColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: borderColor,
                                              width: 1,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              String.fromCharCode(65 + index),
                                              style: TextStyle(
                                                color: letterColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            quiz.answers[index],
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                        if (showResult && isCorrect)
                                          Icon(
                                            Icons.check_circle,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            size: 24,
                                          ),
                                        if (showResult &&
                                            isSelected &&
                                            !isCorrect)
                                          const Icon(
                                            Icons.cancel,
                                            color: Colors.red,
                                            size: 24,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Eco-Guide Tip (Explanation)
                if (provider.answered && quiz.explanation != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Eco-Guide Tip',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                quiz.explanation!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.8),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),

        // Bottom Actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: provider.answered
                          ? null
                          : provider.skipQuestion,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      child: Text(
                        'Skip Question',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: !provider.answered
                          ? (provider.selectedAnswer != null
                                ? provider.submitAnswer
                                : null)
                          : (provider.hasNext
                                ? provider.nextQuestion
                                : () {
                                    provider.nextQuestion();
                                  }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        disabledBackgroundColor: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            !provider.answered
                                ? 'Confirm Answer'
                                : (provider.hasNext
                                      ? 'Next Question'
                                      : 'View Results'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.eco,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Learn more about the park',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: AppTheme.primaryColor),
            SizedBox(width: 12),
            Text('Aide'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Selectionnez la bonne reponse parmi les options'),
            SizedBox(height: 8),
            Text('• Vous pouvez passer une question'),
            SizedBox(height: 8),
            Text('• Chaque bonne reponse rapporte 10 points'),
            SizedBox(height: 8),
            Text('• Lisez les conseils Eco-Guide pour apprendre plus'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }
}
