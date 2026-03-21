import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Activity, ActivityType } from './entities/activity.entity';
import { CreateActivityDto } from './dto/create-activity.dto';
import { PaginationDto, PaginatedResult } from '../../common/dto/pagination.dto';

@Injectable()
export class ActivitiesService {
  constructor(
    @InjectRepository(Activity)
    private activitiesRepository: Repository<Activity>,
  ) {}

  async create(userId: string, createDto: CreateActivityDto): Promise<Activity> {
    const activity = this.activitiesRepository.create({
      ...createDto,
      userId,
    });
    return this.activitiesRepository.save(activity);
  }

  async findByUser(
    userId: string,
    paginationDto: PaginationDto,
  ): Promise<PaginatedResult<Activity>> {
    const { page, limit } = paginationDto;
    const skip = (page - 1) * limit;

    const [data, total] = await this.activitiesRepository.findAndCount({
      where: { userId },
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

  async getUserStats(userId: string): Promise<{
    totalTrailsStarted: number;
    totalTrailsCompleted: number;
    totalPoisVisited: number;
    totalQuizzesAnswered: number;
    totalDistance: number;
    totalDuration: number;
  }> {
    const activities = await this.activitiesRepository.find({
      where: { userId },
    });

    const stats = {
      totalTrailsStarted: 0,
      totalTrailsCompleted: 0,
      totalPoisVisited: 0,
      totalQuizzesAnswered: 0,
      totalDistance: 0,
      totalDuration: 0,
    };

    activities.forEach((activity) => {
      switch (activity.type) {
        case ActivityType.TRAIL_STARTED:
          stats.totalTrailsStarted++;
          break;
        case ActivityType.TRAIL_COMPLETED:
          stats.totalTrailsCompleted++;
          if (activity.metadata?.distance) {
            stats.totalDistance += activity.metadata.distance;
          }
          if (activity.metadata?.duration) {
            stats.totalDuration += activity.metadata.duration;
          }
          break;
        case ActivityType.POI_VISITED:
          stats.totalPoisVisited++;
          break;
        case ActivityType.QUIZ_ANSWERED:
          stats.totalQuizzesAnswered++;
          break;
      }
    });

    return stats;
  }

  async getRecentActivity(userId: string, limit: number = 10): Promise<Activity[]> {
    return this.activitiesRepository.find({
      where: { userId },
      relations: ['trail', 'poi'],
      order: { createdAt: 'DESC' },
      take: limit,
    });
  }
}
