import {
  Controller,
  Get,
  Post,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';
import { ActivitiesService } from './activities.service';
import { CreateActivityDto } from './dto/create-activity.dto';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@ApiTags('activities')
@Controller('activities')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('JWT-auth')
export class ActivitiesController {
  constructor(private readonly activitiesService: ActivitiesService) {}

  @Post()
  @ApiOperation({ summary: 'Log a new activity' })
  @ApiResponse({ status: 201, description: 'Activity logged successfully' })
  create(@CurrentUser() user: User, @Body() createDto: CreateActivityDto) {
    return this.activitiesService.create(user.id, createDto);
  }

  @Get('me')
  @ApiOperation({ summary: 'Get current user activity history' })
  @ApiResponse({ status: 200, description: 'User activities' })
  findMyActivities(
    @CurrentUser() user: User,
    @Query() paginationDto: PaginationDto,
  ) {
    return this.activitiesService.findByUser(user.id, paginationDto);
  }

  @Get('me/stats')
  @ApiOperation({ summary: 'Get current user statistics' })
  @ApiResponse({ status: 200, description: 'User statistics' })
  getMyStats(@CurrentUser() user: User) {
    return this.activitiesService.getUserStats(user.id);
  }

  @Get('me/recent')
  @ApiOperation({ summary: 'Get current user recent activities' })
  @ApiQuery({ name: 'limit', required: false, type: Number, description: 'Number of recent activities (default: 10)' })
  @ApiResponse({ status: 200, description: 'Recent activities' })
  getRecentActivities(
    @CurrentUser() user: User,
    @Query('limit') limit?: number,
  ) {
    return this.activitiesService.getRecentActivity(user.id, limit || 10);
  }
}
