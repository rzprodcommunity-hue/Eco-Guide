import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Quiz, QuizCategory } from './entities/quiz.entity';
import { QuizScore } from './entities/quiz-score.entity';
import { CreateQuizDto } from './dto/create-quiz.dto';
import { UpdateQuizDto } from './dto/update-quiz.dto';
import { SubmitQuizScoreDto } from './dto/submit-quiz-score.dto';
import { PaginationDto, PaginatedResult } from '../../common/dto/pagination.dto';

@Injectable()
export class QuizzesService {
  constructor(
    @InjectRepository(Quiz)
    private quizzesRepository: Repository<Quiz>,
    @InjectRepository(QuizScore)
    private quizScoresRepository: Repository<QuizScore>,
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

  // Quiz Score Methods
  async submitScore(userId: string, dto: SubmitQuizScoreDto): Promise<QuizScore> {
    const percentage = (dto.correctAnswers / dto.totalQuestions) * 100;

    let score = await this.quizScoresRepository.findOne({
      where: { userId, category: dto.category || null },
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

    return this.quizScoresRepository.save(score);
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
    return this.quizScoresRepository.findOne({
      where: { userId, category: category || null },
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
}
