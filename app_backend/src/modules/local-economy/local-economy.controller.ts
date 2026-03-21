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
  ApiQuery,
} from '@nestjs/swagger';
import { LocalEconomyService } from './local-economy.service';
import { CreateLocalServiceDto } from './dto/create-local-service.dto';
import { UpdateLocalServiceDto } from './dto/update-local-service.dto';
import { ServiceCategory } from './entities/local-service.entity';
import { PaginationDto } from '../../common/dto/pagination.dto';
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
  @ApiQuery({ name: 'category', required: false, enum: ServiceCategory })
  @ApiResponse({ status: 200, description: 'List of local services' })
  findAll(
    @Query() paginationDto: PaginationDto,
    @Query('category') category?: ServiceCategory,
  ) {
    return this.localEconomyService.findAll(paginationDto, category);
  }

  @Get('nearby')
  @ApiOperation({ summary: 'Find local services near a location' })
  @ApiQuery({ name: 'lat', required: true, type: Number })
  @ApiQuery({ name: 'lng', required: true, type: Number })
  @ApiQuery({ name: 'radius', required: false, type: Number, description: 'Radius in km (default: 50)' })
  @ApiQuery({ name: 'category', required: false, enum: ServiceCategory })
  @ApiResponse({ status: 200, description: 'List of nearby services' })
  findNearby(
    @Query('lat') lat: number,
    @Query('lng') lng: number,
    @Query('radius') radius?: number,
    @Query('category') category?: ServiceCategory,
  ) {
    return this.localEconomyService.findNearby(lat, lng, radius || 50, category);
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
