import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsEnum,
  IsOptional,
  IsNumber,
  IsEmail,
  IsArray,
  IsUrl,
  IsBoolean,
  MaxLength,
} from 'class-validator';
import { ServiceCategory } from '../entities/local-service.entity';

export class CreateLocalServiceDto {
  @ApiProperty({ example: 'Mountain Guide Services' })
  @IsString()
  @MaxLength(200)
  name: string;

  @ApiProperty({ enum: ServiceCategory, example: ServiceCategory.GUIDE })
  @IsEnum(ServiceCategory)
  category: ServiceCategory;

  @ApiProperty({ example: 'Professional mountain guide with 10 years of experience' })
  @IsString()
  description: string;

  @ApiPropertyOptional({ example: '+212 600 123456' })
  @IsOptional()
  @IsString()
  contact?: string;

  @ApiPropertyOptional({ example: 'guide@example.com' })
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiPropertyOptional({ example: 'https://example.com' })
  @IsOptional()
  @IsUrl()
  website?: string;

  @ApiPropertyOptional({ example: '123 Mountain Street, Marrakech' })
  @IsOptional()
  @IsString()
  address?: string;

  @ApiPropertyOptional({ example: 31.6295 })
  @IsOptional()
  @IsNumber()
  latitude?: number;

  @ApiPropertyOptional({ example: -7.9811 })
  @IsOptional()
  @IsNumber()
  longitude?: number;

  @ApiPropertyOptional({ example: 'https://example.com/service.jpg' })
  @IsOptional()
  @IsString()
  imageUrl?: string;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  additionalImages?: string[];

  @ApiPropertyOptional({ type: [String], example: ['French', 'Arabic', 'English'] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  languages?: string[];

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
