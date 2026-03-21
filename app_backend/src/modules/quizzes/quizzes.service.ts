import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Quiz } from './entities/quiz.entity';
import { CreateQuizDto } from './dto/create-quiz.dto';
import { UpdateQuizDto } from './dto/update-quiz.dto';
import { PaginationDto, PaginatedResult } from '../../common/dto/pagination.dto';

@Injectable()
export class QuizzesService {
  constructor(
    @InjectRepository(Quiz)
    private quizzesRepository: Repository<Quiz>,
  ) {}

  async create(createQuizDto: CreateQuizDto): Promise<Quiz> {
    const quiz = this.quizzesRepository.create(createQuizDto);
    return this.quizzesRepository.save(quiz);
  }

  async findAll(paginationDto: PaginationDto): Promise<PaginatedResult<Quiz>> {
    const { page, limit } = paginationDto;
    const skip = (page - 1) * limit;

    const [data, total] = await this.quizzesRepository.findAndCount({
      where: { isActive: true },
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

  async findRandom(count: number = 5): Promise<Quiz[]> {
    return this.quizzesRepository
      .createQueryBuilder('quiz')
      .where('quiz.isActive = :isActive', { isActive: true })
      .orderBy('RANDOM()')
      .take(count)
      .getMany();
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
}
