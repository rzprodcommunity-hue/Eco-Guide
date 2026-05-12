import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { User } from '../users/entities/user.entity';
import { Trail } from '../trails/entities/trail.entity';
import { Poi } from '../pois/entities/poi.entity';
import { Quiz } from '../quizzes/entities/quiz.entity';
import { LocalService } from '../local-economy/entities/local-service.entity';
import { Activity } from '../activities/entities/activity.entity';
import { SosModule } from '../sos/sos.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, Trail, Poi, Quiz, LocalService, Activity]),
    SosModule,
  ],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
