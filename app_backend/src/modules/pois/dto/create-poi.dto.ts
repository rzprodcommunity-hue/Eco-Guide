import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsNumber,
  IsEnum,
  IsOptional,
  IsArray,
  IsUUID,
  IsBoolean,
  IsUrl,
  MaxLength,
} from 'class-validator';
import { PoiType } from '../entities/poi.entity';

export class CreatePoiDto {
  @ApiProperty({ example: 'Scenic Viewpoint' })
  @IsString()
  @MaxLength(200)
  name: string;

  @ApiProperty({ enum: PoiType, example: PoiType.VIEWPOINT })
  @IsEnum(PoiType)
  type: PoiType;

  @ApiProperty({ example: 'A beautiful viewpoint overlooking the valley' })
  @IsString()
  description: string;

  @ApiPropertyOptional({ example: 'Protected species' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  badge?: string;

  @ApiPropertyOptional({ example: 'https://example.com/pois/scenic-viewpoint' })
  @IsOptional()
  @IsUrl()
  learnMoreUrl?: string;

  @ApiProperty({ example: 31.6295 })
  @IsNumber()
  latitude: number;

  @ApiProperty({ example: -7.9811 })
  @IsNumber()
  longitude: number;

  @ApiPropertyOptional({ example: 'https://example.com/poi.jpg' })
  @IsOptional()
  @IsString()
  mediaUrl?: string;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  additionalMediaUrls?: string[];

  @ApiPropertyOptional({ example: 'https://example.com/audio.mp3' })
  @IsOptional()
  @IsString()
  audioGuideUrl?: string;

  @ApiPropertyOptional({ description: 'Associated trail ID' })
  @IsOptional()
  @IsUUID()
  trailId?: string;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
