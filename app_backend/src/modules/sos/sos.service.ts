import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { SosAlertDto } from './dto/sos-alert.dto';
import { User } from '../users/entities/user.entity';
import { EventsGateway } from '../events/events.gateway';
import { SosAlert } from './entities/sos-alert.entity';

@Injectable()
export class SosService {
  private readonly logger = new Logger(SosService.name);

  constructor(
    @InjectRepository(SosAlert)
    private readonly sosRepository: Repository<SosAlert>,
    private readonly eventsGateway: EventsGateway,
  ) {}



  async createAlert(user: User | undefined, alertDto: SosAlertDto) {
    const alert = this.sosRepository.create({
      userId: user?.id || 'anonymous_user',
      userEmail: user?.email || 'anonymous',
      userName: user ? `${user.firstName || ''} ${user.lastName || ''}`.trim() || user.email : 'Anonymous Hiker',
      latitude: alertDto.latitude,
      longitude: alertDto.longitude,
      message: alertDto.message,
      emergencyContact: alertDto.emergencyContact,
      status: 'active',
    });

    const savedAlert = await this.sosRepository.save(alert);

    // Log the emergency alert
    this.logger.warn(
      `🚨 SOS ALERT from ${alert.userName} (${alert.userEmail}) at coordinates: ${alert.latitude}, ${alert.longitude}`,
    );

    // In production, you would:
    // 1. Store in database
    // 2. Send push notification to admins
    // 3. Send SMS/email to emergency contacts
    // 4. Optionally integrate with emergency services API

    // Emit real-time event to connected clients
    this.eventsGateway.broadcast('sos_alert_created', this.mapEntityToRecord(savedAlert));

    return this.mapEntityToRecord(savedAlert);
  }

  async getActiveAlerts() {
    const alerts = await this.sosRepository.find({
      where: { status: 'active' },
      order: { createdAt: 'DESC' },
    });
    return alerts.map(a => this.mapEntityToRecord(a));
  }

  async getAllAlerts() {
    const alerts = await this.sosRepository.find({
      order: { createdAt: 'DESC' },
    });
    return alerts.map(a => this.mapEntityToRecord(a));
  }

  async resolveAlert(alertId: string) {
    const alert = await this.sosRepository.findOne({ where: { id: alertId } });
    if (!alert) {
      throw new NotFoundException(`Alert with ID ${alertId} not found`);
    }

    alert.status = 'resolved';
    alert.resolvedAt = new Date();
    const savedAlert = await this.sosRepository.save(alert);
    
    this.logger.log(`✅ SOS Alert ${alertId} resolved`);

    // Emit real-time event to connected clients
    const mapped = this.mapEntityToRecord(savedAlert);
    this.eventsGateway.broadcast('sos_alert_resolved', mapped);

    return mapped;
  }

  private mapEntityToRecord(alert: SosAlert) {
    return {
      ...alert,
      timestamp: alert.createdAt,
    };
  }
}
