import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { QuizzesService } from './quizzes.service';
import { QuizzesController } from './quizzes.controller';
import { Quiz } from './entities/quiz.entity';
import { QuizScore } from './entities/quiz-score.entity';
import { QuizBadge } from './entities/quiz-badge.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Quiz, QuizScore, QuizBadge])],
  controllers: [QuizzesController],
  providers: [QuizzesService],
  exports: [QuizzesService],
})
export class QuizzesModule {}
