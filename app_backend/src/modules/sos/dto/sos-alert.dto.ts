import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNumber, IsString, IsOptional } from 'class-validator';

export class SosAlertDto {
  @ApiProperty({ example: 31.6295, description: 'Current latitude' })
  @IsNumber()
  latitude: number;

  @ApiProperty({ example: -7.9811, description: 'Current longitude' })
  @IsNumber()
  longitude: number;

  @ApiPropertyOptional({ example: 'I am injured and need help', description: 'Emergency message' })
  @IsOptional()
  @IsString()
  message?: string;

  @ApiPropertyOptional({ example: '+212 600 123456', description: 'Emergency contact phone' })
  @IsOptional()
  @IsString()
  emergencyContact?: string;
}
