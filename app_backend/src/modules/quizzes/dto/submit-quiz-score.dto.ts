import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsInt, IsOptional, Min } from 'class-validator';
import { QuizCategory } from '../entities/quiz.entity';

export class SubmitQuizScoreDto {
  @ApiPropertyOptional({ enum: QuizCategory, description: 'Quiz category' })
  @IsOptional()
  @IsEnum(QuizCategory)
  category?: QuizCategory;

  @ApiProperty({ description: 'Score earned in this session' })
  @IsInt()
  @Min(0)
  score: number;

  @ApiProperty({ description: 'Number of correct answers' })
  @IsInt()
  @Min(0)
  correctAnswers: number;

  @ApiProperty({ description: 'Total number of questions answered' })
  @IsInt()
  @Min(1)
  totalQuestions: number;
}
