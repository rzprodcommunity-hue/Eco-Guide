import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsEnum, IsString } from 'class-validator';
import { PaginationDto } from '../../../common/dto/pagination.dto';
import { ServiceCategory } from '../entities/local-service.entity';

export class LocalServiceQueryDto extends PaginationDto {
  @ApiPropertyOptional({
    example: 'eco',
    description: 'Search by name, description, address, or category (starts with, case-insensitive)',
  })
  @IsOptional()
  @IsString()
  search?: string;

  @ApiPropertyOptional({ enum: ServiceCategory, description: 'Filter by category' })
  @IsOptional()
  @IsEnum(ServiceCategory)
  category?: ServiceCategory;
}
