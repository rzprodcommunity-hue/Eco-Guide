import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsUUID, IsOptional, IsArray, IsObject } from 'class-validator';

export class SendNotificationDto {
  @ApiProperty({ example: 'New Trail Alert!' })
  @IsString()
  title: string;

  @ApiProperty({ example: 'A new trail has been added in your region.' })
  @IsString()
  body: string;

  @ApiPropertyOptional({ description: 'Specific user IDs to notify' })
  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  userIds?: string[];

  @ApiPropertyOptional({ description: 'Send to all users', default: false })
  @IsOptional()
  broadcast?: boolean;

  @ApiPropertyOptional({ description: 'Additional data payload' })
  @IsOptional()
  @IsObject()
  data?: Record<string, string>;
}
