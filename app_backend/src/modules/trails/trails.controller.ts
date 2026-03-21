import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  Query,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { TrailsService } from './trails.service';
import { CreateTrailDto } from './dto/create-trail.dto';
import { UpdateTrailDto } from './dto/update-trail.dto';
import { TrailQueryDto, NearbyQueryDto } from './dto/trail-query.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';

@ApiTags('trails')
@Controller('trails')
export class TrailsController {
  constructor(private readonly trailsService: TrailsService) {}

  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Create a new trail (Admin only)' })
  @ApiResponse({ status: 201, description: 'Trail created successfully' })
  create(@Body() createTrailDto: CreateTrailDto) {
    return this.trailsService.create(createTrailDto);
  }

  @Get()
  @ApiOperation({ summary: 'Get all trails with filters' })
  @ApiResponse({ status: 200, description: 'List of trails' })
  findAll(@Query() queryDto: TrailQueryDto) {
    return this.trailsService.findAll(queryDto);
  }

  @Get('nearby')
  @ApiOperation({ summary: 'Find trails near a location' })
  @ApiResponse({ status: 200, description: 'List of nearby trails' })
  findNearby(@Query() queryDto: NearbyQueryDto) {
    return this.trailsService.findNearby(queryDto);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get trail by ID' })
  @ApiResponse({ status: 200, description: 'Trail details' })
  @ApiResponse({ status: 404, description: 'Trail not found' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.trailsService.findOne(id);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Update trail (Admin only)' })
  @ApiResponse({ status: 200, description: 'Trail updated successfully' })
  @ApiResponse({ status: 404, description: 'Trail not found' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updateTrailDto: UpdateTrailDto,
  ) {
    return this.trailsService.update(id, updateTrailDto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Delete trail (Admin only)' })
  @ApiResponse({ status: 200, description: 'Trail deleted successfully' })
  @ApiResponse({ status: 404, description: 'Trail not found' })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.trailsService.remove(id);
  }
}
