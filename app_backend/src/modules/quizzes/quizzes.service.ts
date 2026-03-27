import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { Quiz, QuizCategory } from './entities/quiz.entity';
import { QuizScore } from './entities/quiz-score.entity';
import { QuizBadge } from './entities/quiz-badge.entity';
import { CreateQuizDto } from './dto/create-quiz.dto';
import { UpdateQuizDto } from './dto/update-quiz.dto';
import { SubmitQuizScoreDto } from './dto/submit-quiz-score.dto';
import { PaginationDto, PaginatedResult } from '../../common/dto/pagination.dto';

type BadgeRule = {
  key: string;
  label: string;
  description: string;
  threshold: number;
  icon: string;
  color: string;
  category?: QuizCategory;
};

const TOTAL_BADGE_RULES: BadgeRule[] = [
  {
    key: 'quiz_rookie_100',
    label: 'Quiz Rookie',
    description: 'Atteindre 100 points en quiz.',
    threshold: 100,
    icon: 'military_tech',
    color: '#66BB6A',
  },
  {
    key: 'quiz_explorer_300',
    label: 'Quiz Explorer',
    description: 'Atteindre 300 points en quiz.',
    threshold: 300,
    icon: 'emoji_events',
    color: '#42A5F5',
  },
  {
    key: 'quiz_master_600',
    label: 'Quiz Master',
    description: 'Atteindre 600 points en quiz.',
    threshold: 600,
    icon: 'workspace_premium',
    color: '#FFA726',
  },
];

const CATEGORY_BADGE_RULES: BadgeRule[] = [
  QuizCategory.FLORA,
  QuizCategory.FAUNA,
  QuizCategory.ECOLOGY,
  QuizCategory.HISTORY,
  QuizCategory.GEOGRAPHY,
  QuizCategory.SAFETY,
].map((category) => ({
  key: `quiz_${category}_100`,
  label: `Expert ${category}`,
  description: `Atteindre 100 points dans la categorie ${category}.`,
  threshold: 100,
  icon: 'verified',
  color: '#26A69A',
  category,
}));

@Injectable()
export class QuizzesService {
  constructor(
    @InjectRepository(Quiz)
    private quizzesRepository: Repository<Quiz>,
    @InjectRepository(QuizScore)
    private quizScoresRepository: Repository<QuizScore>,
    @InjectRepository(QuizBadge)
    private quizBadgesRepository: Repository<QuizBadge>,
  ) {}

  async create(createQuizDto: CreateQuizDto): Promise<Quiz> {
    const quiz = this.quizzesRepository.create(createQuizDto);
    return this.quizzesRepository.save(quiz);
  }

  async findAll(paginationDto: PaginationDto): Promise<PaginatedResult<Quiz>> {
    const { page, limit, includeInactive } = paginationDto;
    const skip = (page - 1) * limit;

    const whereCondition = includeInactive ? {} : { isActive: true };

    const [data, total] = await this.quizzesRepository.findAndCount({
      where: whereCondition,
      relations: ['trail', 'poi'],
      skip,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    return {
      data,
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async findRandom(count: number = 5, category?: QuizCategory): Promise<Quiz[]> {
    const query = this.quizzesRepository
      .createQueryBuilder('quiz')
      .where('quiz.isActive = :isActive', { isActive: true });

    if (category) {
      query.andWhere('quiz.category = :category', { category });
    }

    return query.orderBy('RANDOM()').take(count).getMany();
  }

  async findByCategory(category: QuizCategory): Promise<Quiz[]> {
    return this.quizzesRepository.find({
      where: { category, isActive: true },
      order: { createdAt: 'DESC' },
    });
  }

  async findByTrail(trailId: string): Promise<Quiz[]> {
    return this.quizzesRepository.find({
      where: { trailId, isActive: true },
      relations: ['poi'],
    });
  }

  async findByPoi(poiId: string): Promise<Quiz[]> {
    return this.quizzesRepository.find({
      where: { poiId, isActive: true },
    });
  }

  async findOne(id: string): Promise<Quiz> {
    const quiz = await this.quizzesRepository.findOne({
      where: { id },
      relations: ['trail', 'poi'],
    });

    if (!quiz) {
      throw new NotFoundException(`Quiz with ID ${id} not found`);
    }

    return quiz;
  }

  async update(id: string, updateQuizDto: UpdateQuizDto): Promise<Quiz> {
    const quiz = await this.findOne(id);
    Object.assign(quiz, updateQuizDto);
    return this.quizzesRepository.save(quiz);
  }

  async remove(id: string): Promise<void> {
    const quiz = await this.findOne(id);
    await this.quizzesRepository.remove(quiz);
  }

  async submitScore(userId: string, dto: SubmitQuizScoreDto): Promise<QuizScore> {
    const percentage = (dto.correctAnswers / dto.totalQuestions) * 100;
    const categoryFilter = dto.category ?? IsNull();

    let score = await this.quizScoresRepository.findOne({
      where: { userId, category: categoryFilter },
    });

    if (score) {
      score.totalScore += dto.score;
      score.quizzesCompleted += 1;
      score.correctAnswers += dto.correctAnswers;
      score.totalQuestions += dto.totalQuestions;
      score.bestPercentage = Math.max(score.bestPercentage, percentage);
      score.lastPlayedAt = new Date();
    } else {
      score = this.quizScoresRepository.create({
        userId,
        category: dto.category || null,
        totalScore: dto.score,
        quizzesCompleted: 1,
        correctAnswers: dto.correctAnswers,
        totalQuestions: dto.totalQuestions,
        bestPercentage: percentage,
        lastPlayedAt: new Date(),
      });
    }

    const savedScore = await this.quizScoresRepository.save(score);
    await this.unlockBadgesForUser(userId);
    return savedScore;
  }

  async getUserScores(userId: string): Promise<QuizScore[]> {
    return this.quizScoresRepository.find({
      where: { userId },
      order: { totalScore: 'DESC' },
    });
  }

  async getUserScoreByCategory(
    userId: string,
    category?: QuizCategory,
  ): Promise<QuizScore | null> {
    const categoryFilter = category ?? IsNull();

    return this.quizScoresRepository.findOne({
      where: { userId, category: categoryFilter },
    });
  }

  async getLeaderboard(category?: QuizCategory, limit: number = 10): Promise<QuizScore[]> {
    const where = category ? { category } : {};
    return this.quizScoresRepository.find({
      where,
      relations: ['user'],
      order: { totalScore: 'DESC' },
      take: limit,
    });
  }

  async getCategoryStats(): Promise<{ category: string; quizCount: number }[]> {
    const stats = await this.quizzesRepository
      .createQueryBuilder('quiz')
      .select('quiz.category', 'category')
      .addSelect('COUNT(*)', 'quizCount')
      .where('quiz.isActive = :isActive', { isActive: true })
      .groupBy('quiz.category')
      .getRawMany();

    return stats;
  }

  async getUserQuizSummary(userId: string): Promise<{
    totals: {
      totalScore: number;
      quizzesCompleted: number;
      correctAnswers: number;
      totalQuestions: number;
      averagePercentage: number;
      bestPercentage: number;
    };
    categoryScores: QuizScore[];
    badges: QuizBadge[];
  }> {
    const scores = await this.getUserScores(userId);
    const badges = await this.quizBadgesRepository.find({
      where: { userId },
      order: { unlockedAt: 'ASC' },
    });

    const totals = scores.reduce(
      (acc, score) => {
        acc.totalScore += score.totalScore;
        acc.quizzesCompleted += score.quizzesCompleted;
        acc.correctAnswers += score.correctAnswers;
        acc.totalQuestions += score.totalQuestions;
        acc.bestPercentage = Math.max(acc.bestPercentage, score.bestPercentage);
        return acc;
      },
      {
        totalScore: 0,
        quizzesCompleted: 0,
        correctAnswers: 0,
        totalQuestions: 0,
        averagePercentage: 0,
        bestPercentage: 0,
      },
    );

    totals.averagePercentage =
      totals.totalQuestions > 0
        ? Number(((totals.correctAnswers / totals.totalQuestions) * 100).toFixed(2))
        : 0;

    return {
      totals,
      categoryScores: scores,
      badges,
    };
  }

  private async unlockBadgesForUser(userId: string): Promise<void> {
    const scores = await this.getUserScores(userId);
    if (scores.length === 0) return;

    const totalScore = scores.reduce((sum, item) => sum + item.totalScore, 0);
    const categoryMap = new Map<QuizCategory, QuizScore>();

    for (const score of scores) {
      if (score.category) {
        categoryMap.set(score.category, score);
      }
    }

    const unlocked = await this.quizBadgesRepository.find({ where: { userId } });
    const unlockedKeys = new Set(unlocked.map((badge) => badge.key));

    const toCreate: QuizBadge[] = [];

    for (const rule of TOTAL_BADGE_RULES) {
      if (totalScore >= rule.threshold && !unlockedKeys.has(rule.key)) {
        toCreate.push(this.toQuizBadgeEntity(userId, rule));
      }
    }

    for (const rule of CATEGORY_BADGE_RULES) {
      const categoryScore = rule.category ? categoryMap.get(rule.category) : undefined;
      if (
        categoryScore &&
        categoryScore.totalScore >= rule.threshold &&
        !unlockedKeys.has(rule.key)
      ) {
        toCreate.push(this.toQuizBadgeEntity(userId, rule));
      }
    }

    if (toCreate.length > 0) {
      await this.quizBadgesRepository.save(toCreate);
    }
  }

  private toQuizBadgeEntity(userId: string, rule: BadgeRule): QuizBadge {
    return this.quizBadgesRepository.create({
      userId,
      key: rule.key,
      label: rule.label,
      description: rule.description,
      icon: rule.icon,
      color: rule.color,
      threshold: rule.threshold,
      category: rule.category ?? null,
    });
  }
}
