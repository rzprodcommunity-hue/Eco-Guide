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
import { QuizzesService } from './quizzes.service';
import { CreateQuizDto } from './dto/create-quiz.dto';
import { UpdateQuizDto } from './dto/update-quiz.dto';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';

@ApiTags('quizzes')
@Controller('quizzes')
export class QuizzesController {
  constructor(private readonly quizzesService: QuizzesService) {}

  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Create a new quiz (Admin only)' })
  @ApiResponse({ status: 201, description: 'Quiz created successfully' })
  create(@Body() createQuizDto: CreateQuizDto) {
    return this.quizzesService.create(createQuizDto);
  }

  @Get()
  @ApiOperation({ summary: 'Get all quizzes' })
  @ApiResponse({ status: 200, description: 'List of quizzes' })
  findAll(@Query() paginationDto: PaginationDto) {
    return this.quizzesService.findAll(paginationDto);
  }

  @Get('random')
  @ApiOperation({ summary: 'Get random quizzes' })
  @ApiQuery({ name: 'count', required: false, type: Number, description: 'Number of random quizzes (default: 5)' })
  @ApiResponse({ status: 200, description: 'Random quizzes' })
  findRandom(@Query('count') count?: number) {
    return this.quizzesService.findRandom(count || 5);
  }

  @Get('trail/:trailId')
  @ApiOperation({ summary: 'Get quizzes for a specific trail' })
  @ApiResponse({ status: 200, description: 'Quizzes for the trail' })
  findByTrail(@Param('trailId', ParseUUIDPipe) trailId: string) {
    return this.quizzesService.findByTrail(trailId);
  }

  @Get('poi/:poiId')
  @ApiOperation({ summary: 'Get quizzes for a specific POI' })
  @ApiResponse({ status: 200, description: 'Quizzes for the POI' })
  findByPoi(@Param('poiId', ParseUUIDPipe) poiId: string) {
    return this.quizzesService.findByPoi(poiId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get quiz by ID' })
  @ApiResponse({ status: 200, description: 'Quiz details' })
  @ApiResponse({ status: 404, description: 'Quiz not found' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.quizzesService.findOne(id);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Update quiz (Admin only)' })
  @ApiResponse({ status: 200, description: 'Quiz updated successfully' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updateQuizDto: UpdateQuizDto,
  ) {
    return this.quizzesService.update(id, updateQuizDto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Delete quiz (Admin only)' })
  @ApiResponse({ status: 200, description: 'Quiz deleted successfully' })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.quizzesService.remove(id);
  }
}
