import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsUUID, IsOptional, IsNumber } from 'class-validator';
import { CacheResourceType } from '../entities/offline-cache.entity';

export class CacheRequestDto {
  @ApiProperty({ enum: CacheResourceType, example: CacheResourceType.TRAIL })
  @IsEnum(CacheResourceType)
  resourceType: CacheResourceType;

  @ApiProperty({ description: 'Resource ID to cache' })
  @IsUUID()
  resourceId: string;

  @ApiPropertyOptional({ description: 'Size in bytes' })
  @IsOptional()
  @IsNumber()
  sizeBytes?: number;
}
