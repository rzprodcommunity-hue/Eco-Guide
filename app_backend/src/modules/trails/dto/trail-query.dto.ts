import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsNumber, IsEnum, IsString } from 'class-validator';
import { Type } from 'class-transformer';
import { TrailDifficulty } from '../entities/trail.entity';
import { PaginationDto } from '../../../common/dto/pagination.dto';

export class TrailQueryDto extends PaginationDto {
  @ApiPropertyOptional({ enum: TrailDifficulty })
  @IsOptional()
  @IsEnum(TrailDifficulty)
  difficulty?: TrailDifficulty;

  @ApiPropertyOptional({ example: 'Atlas' })
  @IsOptional()
  @IsString()
  region?: string;

  @ApiPropertyOptional({ example: 0, description: 'Minimum distance in km' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  minDistance?: number;

  @ApiPropertyOptional({ example: 20, description: 'Maximum distance in km' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  maxDistance?: number;

  @ApiPropertyOptional({ example: 'name', description: 'Sort field' })
  @IsOptional()
  @IsString()
  sortBy?: string;

  @ApiPropertyOptional({ enum: ['ASC', 'DESC'], default: 'ASC' })
  @IsOptional()
  @IsString()
  sortOrder?: 'ASC' | 'DESC';
}

export class NearbyQueryDto {
  @ApiPropertyOptional({ example: 31.6295, description: 'Latitude' })
  @Type(() => Number)
  @IsNumber()
  lat: number;

  @ApiPropertyOptional({ example: -7.9811, description: 'Longitude' })
  @Type(() => Number)
  @IsNumber()
  lng: number;

  @ApiPropertyOptional({ example: 50, description: 'Radius in kilometers' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  radius: number = 50;
}
