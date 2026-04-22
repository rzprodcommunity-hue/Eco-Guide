import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { OfflineService } from './offline.service';
import { CacheRequestDto } from './dto/cache-request.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@ApiTags('offline')
@Controller('offline')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('JWT-auth')
export class OfflineController {
  constructor(private readonly offlineService: OfflineService) {}

  @Get('packages')
  @ApiOperation({ summary: 'Get available offline packages' })
  @ApiResponse({ status: 200, description: 'Available offline packages' })
  getAvailablePackages() {
    return this.offlineService.getAvailablePackages();
  }

  @Get('downloads')
  @ApiOperation({ summary: 'Get user downloaded resources' })
  @ApiResponse({ status: 200, description: 'User downloads' })
  getDownloads(@CurrentUser() user: User) {
    return this.offlineService.getUserDownloads(user.id);
  }

  @Get('sync')
  @ApiOperation({ summary: 'Get sync status for offline data' })
  @ApiResponse({ status: 200, description: 'Sync status' })
  getSyncStatus(@CurrentUser() user: User) {
    return this.offlineService.getSyncStatus(user.id);
  }

  @Post('download')
  @ApiOperation({ summary: 'Mark a resource as downloaded' })
  @ApiResponse({ status: 201, description: 'Download recorded' })
  markDownloaded(@CurrentUser() user: User, @Body() dto: CacheRequestDto) {
    return this.offlineService.markAsDownloaded(user.id, dto);
  }

  @Delete('download/:id')
  @ApiOperation({ summary: 'Remove a downloaded resource' })
  @ApiResponse({ status: 200, description: 'Download removed' })
  removeDownload(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.offlineService.removeDownload(user.id, id);
  }

  @Delete('downloads')
  @ApiOperation({ summary: 'Clear all downloaded resources' })
  @ApiResponse({ status: 200, description: 'All downloads cleared' })
  clearDownloads(@CurrentUser() user: User) {
    return this.offlineService.clearAllDownloads(user.id);
  }
}
