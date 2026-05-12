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
import { PoisService } from './pois.service';
import { CreatePoiDto } from './dto/create-poi.dto';
import { UpdatePoiDto } from './dto/update-poi.dto';
import { PoiQueryDto, PoiNearbyQueryDto } from './dto/poi-query.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';

@ApiTags('pois')
@Controller('pois')
export class PoisController {
  constructor(private readonly poisService: PoisService) {}

  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Create a new POI (Admin only)' })
  @ApiResponse({ status: 201, description: 'POI created successfully' })
  create(@Body() createPoiDto: CreatePoiDto) {
    return this.poisService.create(createPoiDto);
  }

  @Get()
  @ApiOperation({ summary: 'Get all POIs with filters' })
  @ApiResponse({ status: 200, description: 'List of POIs' })
  findAll(@Query() queryDto: PoiQueryDto) {
    return this.poisService.findAll(queryDto);
  }

  @Get('nearby')
  @ApiOperation({ summary: 'Find POIs near a location' })
  @ApiResponse({ status: 200, description: 'List of nearby POIs' })
  findNearby(@Query() queryDto: PoiNearbyQueryDto) {
    return this.poisService.findNearby(queryDto);
  }

  @Get('trail/:trailId')
  @ApiOperation({ summary: 'Get all POIs for a specific trail' })
  @ApiResponse({ status: 200, description: 'List of POIs for the trail' })
  findByTrail(@Param('trailId', ParseUUIDPipe) trailId: string) {
    return this.poisService.findByTrail(trailId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get POI by ID' })
  @ApiResponse({ status: 200, description: 'POI details' })
  @ApiResponse({ status: 404, description: 'POI not found' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.poisService.findOne(id);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Update POI (Admin only)' })
  @ApiResponse({ status: 200, description: 'POI updated successfully' })
  @ApiResponse({ status: 404, description: 'POI not found' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updatePoiDto: UpdatePoiDto,
  ) {
    return this.poisService.update(id, updatePoiDto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Delete POI (Admin only)' })
  @ApiResponse({ status: 200, description: 'POI deleted successfully' })
  @ApiResponse({ status: 404, description: 'POI not found' })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.poisService.remove(id);
  }
}
