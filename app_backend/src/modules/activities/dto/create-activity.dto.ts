import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsOptional, IsUUID, IsObject } from 'class-validator';
import { ActivityType } from '../entities/activity.entity';

export class CreateActivityDto {
  @ApiProperty({ enum: ActivityType, example: ActivityType.TRAIL_STARTED })
  @IsEnum(ActivityType)
  type: ActivityType;

  @ApiPropertyOptional({ description: 'Associated trail ID' })
  @IsOptional()
  @IsUUID()
  trailId?: string;

  @ApiPropertyOptional({ description: 'Associated POI ID' })
  @IsOptional()
  @IsUUID()
  poiId?: string;

  @ApiPropertyOptional({
    description: 'Additional metadata',
    example: { duration: 3600, distance: 5.5, quizScore: 8 },
  })
  @IsOptional()
  @IsObject()
  metadata?: Record<string, any>;
}
