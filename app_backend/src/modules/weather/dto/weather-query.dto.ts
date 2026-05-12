import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsNumber, IsOptional } from 'class-validator';
import { Type } from 'class-transformer';

export class WeatherQueryDto {
  @ApiPropertyOptional({ example: 31.6295, description: 'Latitude' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  lat?: number;

  @ApiPropertyOptional({ example: -7.9811, description: 'Longitude' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  lng?: number;
}
