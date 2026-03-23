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
  Request,
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
import { SubmitQuizScoreDto } from './dto/submit-quiz-score.dto';
import { QuizCategory } from './entities/quiz.entity';
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
  @ApiQuery({
    name: 'count',
    required: false,
    type: Number,
    description: 'Number of random quizzes (default: 5)',
  })
  @ApiQuery({
    name: 'category',
    required: false,
    enum: QuizCategory,
    description: 'Filter by category',
  })
  @ApiResponse({ status: 200, description: 'Random quizzes' })
  findRandom(
    @Query('count') count?: number,
    @Query('category') category?: QuizCategory,
  ) {
    return this.quizzesService.findRandom(count || 5, category);
  }

  @Get('categories')
  @ApiOperation({ summary: 'Get quiz categories with stats' })
  @ApiResponse({ status: 200, description: 'Category statistics' })
  getCategoryStats() {
    return this.quizzesService.getCategoryStats();
  }

  @Get('category/:category')
  @ApiOperation({ summary: 'Get quizzes by category' })
  @ApiResponse({ status: 200, description: 'Quizzes for the category' })
  findByCategory(@Param('category') category: QuizCategory) {
    return this.quizzesService.findByCategory(category);
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

  // Score endpoints
  @Post('scores')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Submit quiz score' })
  @ApiResponse({ status: 201, description: 'Score submitted successfully' })
  submitScore(@Request() req, @Body() dto: SubmitQuizScoreDto) {
    return this.quizzesService.submitScore(req.user.id, dto);
  }

  @Get('scores/me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Get current user scores' })
  @ApiResponse({ status: 200, description: 'User quiz scores' })
  getMyScores(@Request() req) {
    return this.quizzesService.getUserScores(req.user.id);
  }

  @Get('scores/leaderboard')
  @ApiOperation({ summary: 'Get quiz leaderboard' })
  @ApiQuery({
    name: 'category',
    required: false,
    enum: QuizCategory,
    description: 'Filter by category',
  })
  @ApiQuery({
    name: 'limit',
    required: false,
    type: Number,
    description: 'Number of results (default: 10)',
  })
  @ApiResponse({ status: 200, description: 'Leaderboard' })
  getLeaderboard(
    @Query('category') category?: QuizCategory,
    @Query('limit') limit?: number,
  ) {
    return this.quizzesService.getLeaderboard(category, limit || 10);
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
