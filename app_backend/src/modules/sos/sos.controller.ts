import {
  Controller,
  Post,
  Get,
  Patch,
  Param,
  Body,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { SosService } from './sos.service';
import { SosAlertDto } from './dto/sos-alert.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@ApiTags('sos')
@Controller('sos')
export class SosController {
  constructor(private readonly sosService: SosService) {}

  @Post('alert')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Send an SOS emergency alert' })
  @ApiResponse({ status: 201, description: 'Alert sent successfully' })
  createAlert(@CurrentUser() user: User, @Body() alertDto: SosAlertDto) {
    return this.sosService.createAlert(user, alertDto);
  }

  @Get('alerts')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Get all SOS alerts (Admin only)' })
  @ApiResponse({ status: 200, description: 'List of all alerts' })
  getAllAlerts() {
    return this.sosService.getAllAlerts();
  }

  @Get('alerts/active')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Get active SOS alerts (Admin only)' })
  @ApiResponse({ status: 200, description: 'List of active alerts' })
  getActiveAlerts() {
    return this.sosService.getActiveAlerts();
  }

  @Patch('alerts/:id/resolve')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  @ApiBearerAuth('JWT-auth')
  @ApiOperation({ summary: 'Resolve an SOS alert (Admin only)' })
  @ApiResponse({ status: 200, description: 'Alert resolved' })
  resolveAlert(@Param('id') id: string) {
    return this.sosService.resolveAlert(id);
  }
}
