import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsString, IsOptional, IsNumber } from 'class-validator';
import { CacheResourceType } from '../entities/offline-cache.entity';

export class CacheRequestDto {
  @ApiProperty({ enum: CacheResourceType, example: CacheResourceType.TRAIL })
  @IsEnum(CacheResourceType)
  resourceType: CacheResourceType;

  @ApiProperty({ description: 'Resource ID to cache' })
  @IsString()
  resourceId: string;

  @ApiPropertyOptional({ description: 'Size in bytes' })
  @IsOptional()
  @IsNumber()
  sizeBytes?: number;
}
