import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsArray,
  IsInt,
  IsOptional,
  IsEnum,
  IsUUID,
  IsBoolean,
  Min,
  ArrayMinSize,
} from 'class-validator';
import { QuizCategory } from '../entities/quiz.entity';

export class CreateQuizDto {
  @ApiProperty({ example: 'What is the endemic plant of the Atlas Mountains?' })
  @IsString()
  question: string;

  @ApiProperty({ example: ['Cedar', 'Oak', 'Pine', 'Olive'] })
  @IsArray()
  @IsString({ each: true })
  @ArrayMinSize(2)
  answers: string[];

  @ApiProperty({ example: 0, description: 'Index of the correct answer (0-based)' })
  @IsInt()
  @Min(0)
  correctAnswerIndex: number;

  @ApiPropertyOptional({ example: 'The Atlas Cedar is endemic to the Atlas Mountains.' })
  @IsOptional()
  @IsString()
  explanation?: string;

  @ApiPropertyOptional({ enum: QuizCategory })
  @IsOptional()
  @IsEnum(QuizCategory)
  category?: QuizCategory;

  @ApiPropertyOptional({ example: 'https://example.com/quiz-image.jpg' })
  @IsOptional()
  @IsString()
  imageUrl?: string;

  @ApiPropertyOptional({ description: 'Associated trail ID' })
  @IsOptional()
  @IsUUID()
  trailId?: string;

  @ApiPropertyOptional({ description: 'Associated POI ID' })
  @IsOptional()
  @IsUUID()
  poiId?: string;

  @ApiPropertyOptional({ example: 10, description: 'Points for correct answer' })
  @IsOptional()
  @IsInt()
  @Min(1)
  points?: number;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
