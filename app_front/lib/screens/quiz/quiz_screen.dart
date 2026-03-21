import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_banner.dart';
import '../../providers/quiz_provider.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizProvider>().loadRandomQuizzes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final quizProvider = context.watch<QuizProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Eco'),
        actions: [
          if (quizProvider.quizzes.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  'Score: ${quizProvider.score}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (quizProvider.error != null && quizProvider.error!.isNotEmpty)
            ErrorBanner(
              message: quizProvider.error!,
              onRetry: () => quizProvider.loadRandomQuizzes(),
              onDismiss: quizProvider.clearError,
            ),
          Expanded(
            child: quizProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : quizProvider.quizzes.isEmpty
                    ? _buildEmptyState()
                    : quizProvider.isFinished
                        ? _buildResultScreen(quizProvider)
                        : _buildQuizContent(quizProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.quiz, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Aucun quiz disponible'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<QuizProvider>().loadRandomQuizzes();
            },
            child: const Text('Recharger'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen(QuizProvider provider) {
    final percentage = (provider.score / (provider.totalQuestions * 10) * 100).round();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              percentage >= 70 ? Icons.emoji_events : Icons.psychology,
              size: 80,
              color: percentage >= 70 ? Colors.amber : AppTheme.primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              percentage >= 70 ? 'Felicitations!' : 'Bien joue!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Vous avez obtenu',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${provider.score} points',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$percentage% de reussite',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                provider.restart();
                provider.loadRandomQuizzes();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Nouveau quiz'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizContent(QuizProvider provider) {
    final quiz = provider.currentQuiz!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress indicator
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: (provider.currentIndex + 1) / provider.totalQuestions,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${provider.currentIndex + 1}/${provider.totalQuestions}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Category badge
          if (quiz.category != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  quiz.categoryDisplayName,
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Image if available
          if (quiz.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: quiz.imageUrl!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          if (quiz.imageUrl != null) const SizedBox(height: 16),

          // Question
          Text(
            quiz.question,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Answers
          Expanded(
            child: ListView.builder(
              itemCount: quiz.answers.length,
              itemBuilder: (context, index) {
                final isSelected = provider.selectedAnswer == index;
                final isCorrect = index == quiz.correctAnswerIndex;
                final showResult = provider.answered;

                Color? backgroundColor;
                Color? borderColor;

                if (showResult) {
                  if (isCorrect) {
                    backgroundColor = Colors.green.withValues(alpha: 0.1);
                    borderColor = Colors.green;
                  } else if (isSelected && !isCorrect) {
                    backgroundColor = Colors.red.withValues(alpha: 0.1);
                    borderColor = Colors.red;
                  }
                } else if (isSelected) {
                  backgroundColor = AppTheme.primaryColor.withValues(alpha: 0.1);
                  borderColor = AppTheme.primaryColor;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: provider.answered
                        ? null
                        : () => provider.selectAnswer(index),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: backgroundColor ?? Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor ?? Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? (borderColor ?? AppTheme.primaryColor)
                                  : Colors.grey[300],
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + index),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              quiz.answers[index],
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          if (showResult && isCorrect)
                            const Icon(Icons.check_circle, color: Colors.green),
                          if (showResult && isSelected && !isCorrect)
                            const Icon(Icons.cancel, color: Colors.red),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Explanation
          if (provider.answered && quiz.explanation != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      quiz.explanation!,
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action buttons
          if (!provider.answered)
            ElevatedButton(
              onPressed: provider.selectedAnswer != null
                  ? provider.submitAnswer
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Valider'),
            )
          else
            ElevatedButton(
              onPressed: provider.hasNext
                  ? provider.nextQuestion
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(provider.hasNext ? 'Question suivante' : 'Voir le resultat'),
            ),
        ],
      ),
    );
  }
}
