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
import { LocalEconomyService } from './local-economy.service';
import { CreateLocalServiceDto } from './dto/create-local-service.dto';
import { UpdateLocalServiceDto } from './dto/update-local-service.dto';
import { LocalServiceQueryDto } from './dto/local-service-query.dto';
import { NearbyServiceQueryDto } from './dto/nearby-service-query.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';

@ApiTags('local-services')
@Controller('local-services')
export class LocalEconomyController {
  constructor(private readonly localEconomyService: LocalEconomyService) {}

  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Create a new local service (Admin only)' })
  @ApiResponse({ status: 201, description: 'Service created successfully' })
  create(@Body() createDto: CreateLocalServiceDto) {
    return this.localEconomyService.create(createDto);
  }

  @Get()
  @ApiOperation({ summary: 'Get all local services' })
  @ApiResponse({ status: 200, description: 'List of local services' })
  findAll(@Query() queryDto: LocalServiceQueryDto) {
    return this.localEconomyService.findAll(queryDto, queryDto.category);
  }

  @Get('nearby')
  @ApiOperation({ summary: 'Find local services near a location' })
  @ApiResponse({ status: 200, description: 'List of nearby services' })
  findNearby(@Query() queryDto: NearbyServiceQueryDto) {
    return this.localEconomyService.findNearby(
      queryDto.lat,
      queryDto.lng,
      queryDto.radius || 50,
      queryDto.category,
    );
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get local service by ID' })
  @ApiResponse({ status: 200, description: 'Service details' })
  @ApiResponse({ status: 404, description: 'Service not found' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.localEconomyService.findOne(id);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Update local service (Admin only)' })
  @ApiResponse({ status: 200, description: 'Service updated successfully' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updateDto: UpdateLocalServiceDto,
  ) {
    return this.localEconomyService.update(id, updateDto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Delete local service (Admin only)' })
  @ApiResponse({ status: 200, description: 'Service deleted successfully' })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.localEconomyService.remove(id);
  }
}
