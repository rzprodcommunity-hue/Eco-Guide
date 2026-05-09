import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsNumber,
  IsEnum,
  IsOptional,
  IsArray,
  IsObject,
  IsBoolean,
  Min,
  Max,
  MaxLength,
} from 'class-validator';
import { TrailDifficulty } from '../entities/trail.entity';

export class CreateTrailDto {
  @ApiProperty({ example: 'Mountain Trail' })
  @IsString()
  @MaxLength(200)
  name: string;

  @ApiProperty({ example: 'A beautiful mountain trail with scenic views' })
  @IsString()
  description: string;

  @ApiProperty({ example: 5.5, description: 'Distance in kilometers' })
  @IsNumber()
  @Min(0)
  distance: number;

  @ApiProperty({ enum: TrailDifficulty, example: TrailDifficulty.MODERATE })
  @IsEnum(TrailDifficulty)
  difficulty: TrailDifficulty;

  @ApiPropertyOptional({ description: 'GeoJSON LineString object' })
  @IsOptional()
  @IsObject()
  geojson?: object;

  @ApiPropertyOptional({ example: 120, description: 'Estimated duration in minutes' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  estimatedDuration?: number;

  @ApiPropertyOptional({ example: 350, description: 'Elevation gain in meters' })
  @IsOptional()
  @IsNumber()
  elevationGain?: number;

  @ApiPropertyOptional({ type: [String], example: ['https://example.com/trail1.jpg'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  imageUrls?: string[];

  @ApiPropertyOptional({ example: 'Atlas Mountains' })
  @IsOptional()
  @IsString()
  region?: string;

  @ApiPropertyOptional({ example: 4.8, description: 'Average rating (0 to 5)' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(5)
  averageRating?: number;

  @ApiPropertyOptional({ example: 240, description: 'Total number of reviews' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  reviewCount?: number;

  @ApiPropertyOptional({ example: 31.6295, description: 'Start point latitude' })
  @IsOptional()
  @IsNumber()
  startLatitude?: number;

  @ApiPropertyOptional({ example: -7.9811, description: 'Start point longitude' })
  @IsOptional()
  @IsNumber()
  startLongitude?: number;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
