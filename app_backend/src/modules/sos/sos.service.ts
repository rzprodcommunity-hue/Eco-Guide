import { Injectable, Logger } from '@nestjs/common';
import { SosAlertDto } from './dto/sos-alert.dto';
import { User } from '../users/entities/user.entity';

export interface SosAlertRecord {
  id: string;
  userId: string;
  userEmail: string;
  userName: string;
  latitude: number;
  longitude: number;
  message?: string;
  emergencyContact?: string;
  timestamp: Date;
  status: 'active' | 'resolved';
}

@Injectable()
export class SosService {
  private readonly logger = new Logger(SosService.name);
  private alerts: SosAlertRecord[] = []; // In-memory storage for demo; use database in production

  async createAlert(user: User, alertDto: SosAlertDto): Promise<SosAlertRecord> {
    const alert: SosAlertRecord = {
      id: this.generateId(),
      userId: user.id,
      userEmail: user.email,
      userName: `${user.firstName || ''} ${user.lastName || ''}`.trim() || user.email,
      latitude: alertDto.latitude,
      longitude: alertDto.longitude,
      message: alertDto.message,
      emergencyContact: alertDto.emergencyContact,
      timestamp: new Date(),
      status: 'active',
    };

    this.alerts.push(alert);

    // Log the emergency alert
    this.logger.warn(
      `🚨 SOS ALERT from ${alert.userName} (${alert.userEmail}) at coordinates: ${alert.latitude}, ${alert.longitude}`,
    );

    // In production, you would:
    // 1. Store in database
    // 2. Send push notification to admins
    // 3. Send SMS/email to emergency contacts
    // 4. Optionally integrate with emergency services API

    return alert;
  }

  async getActiveAlerts(): Promise<SosAlertRecord[]> {
    return this.alerts.filter((alert) => alert.status === 'active');
  }

  async getAllAlerts(): Promise<SosAlertRecord[]> {
    return this.alerts.sort(
      (a, b) => b.timestamp.getTime() - a.timestamp.getTime(),
    );
  }

  async resolveAlert(alertId: string): Promise<SosAlertRecord> {
    const alert = this.alerts.find((a) => a.id === alertId);
    if (!alert) {
      throw new Error(`Alert with ID ${alertId} not found`);
    }

    alert.status = 'resolved';
    this.logger.log(`✅ SOS Alert ${alertId} resolved`);

    return alert;
  }

  private generateId(): string {
    return `sos_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}
