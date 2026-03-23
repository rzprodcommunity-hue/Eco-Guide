import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsEnum } from 'class-validator';
import { PaginationDto } from '../../../common/dto/pagination.dto';
import { ServiceCategory } from '../entities/local-service.entity';

export class LocalServiceQueryDto extends PaginationDto {
  @ApiPropertyOptional({ enum: ServiceCategory, description: 'Filter by category' })
  @IsOptional()
  @IsEnum(ServiceCategory)
  category?: ServiceCategory;
}
