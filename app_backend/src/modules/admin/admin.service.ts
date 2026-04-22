import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../users/entities/user.entity';
import { Trail } from '../trails/entities/trail.entity';
import { Poi } from '../pois/entities/poi.entity';
import { Quiz } from '../quizzes/entities/quiz.entity';
import { LocalService } from '../local-economy/entities/local-service.entity';
import { Activity } from '../activities/entities/activity.entity';
import { SosService } from '../sos/sos.service';

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(Trail)
    private readonly trailRepository: Repository<Trail>,
    @InjectRepository(Poi)
    private readonly poiRepository: Repository<Poi>,
    @InjectRepository(Quiz)
    private readonly quizRepository: Repository<Quiz>,
    @InjectRepository(LocalService)
    private readonly localServiceRepository: Repository<LocalService>,
    @InjectRepository(Activity)
    private readonly activityRepository: Repository<Activity>,
    private readonly sosService: SosService,
  ) {}

  async getDashboardOverview() {
    const [
      users,
      trails,
      pois,
      quizzes,
      localServices,
      activities,
      recentActivities,
      activeSosAlerts,
    ] = await Promise.all([
      this.userRepository.count(),
      this.trailRepository.count(),
      this.poiRepository.count(),
      this.quizRepository.count(),
      this.localServiceRepository.count(),
      this.activityRepository.count(),
      this.activityRepository.find({
        order: { createdAt: 'DESC' },
        take: 10,
      }),
      this.sosService.getActiveAlerts(),
    ]);

    return {
      summary: {
        users,
        trails,
        pois,
        quizzes,
        localServices,
        activities,
        activeSosAlerts: activeSosAlerts.length,
      },
      recentActivities,
    };
  }
}
