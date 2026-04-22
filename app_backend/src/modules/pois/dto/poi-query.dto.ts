import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsNumber, IsEnum, IsUUID, IsString } from 'class-validator';
import { Type } from 'class-transformer';
import { PoiType } from '../entities/poi.entity';
import { PaginationDto } from '../../../common/dto/pagination.dto';

export class PoiQueryDto extends PaginationDto {
  @ApiPropertyOptional({
    example: 'sou',
    description: 'Search by name, description, badge, or type (starts with, case-insensitive)',
  })
  @IsOptional()
  @IsString()
  search?: string;

  @ApiPropertyOptional({ enum: PoiType })
  @IsOptional()
  @IsEnum(PoiType)
  type?: PoiType;

  @ApiPropertyOptional({ description: 'Filter by trail ID' })
  @IsOptional()
  @IsUUID()
  trailId?: string;
}

export class PoiNearbyQueryDto {
  @ApiPropertyOptional({ example: 31.6295, description: 'Latitude' })
  @Type(() => Number)
  @IsNumber()
  lat: number;

  @ApiPropertyOptional({ example: -7.9811, description: 'Longitude' })
  @Type(() => Number)
  @IsNumber()
  lng: number;

  @ApiPropertyOptional({ example: 5, description: 'Radius in kilometers' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  radius: number = 5;

  @ApiPropertyOptional({ enum: PoiType })
  @IsOptional()
  @IsEnum(PoiType)
  type?: PoiType;
}
