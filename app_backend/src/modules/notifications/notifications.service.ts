import { Injectable, Logger } from '@nestjs/common';
import { SendNotificationDto } from './dto/send-notification.dto';

export interface NotificationRecord {
  id: string;
  title: string;
  body: string;
  recipients: string[];
  broadcast: boolean;
  data?: Record<string, string>;
  sentAt: Date;
  status: 'sent' | 'failed';
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private notifications: NotificationRecord[] = [];

  /**
   * Send a push notification
   * Note: This is a placeholder. In production, integrate with FCM or similar service.
   */
  async send(dto: SendNotificationDto): Promise<NotificationRecord> {
    const notification: NotificationRecord = {
      id: this.generateId(),
      title: dto.title,
      body: dto.body,
      recipients: dto.userIds || [],
      broadcast: dto.broadcast || false,
      data: dto.data,
      sentAt: new Date(),
      status: 'sent',
    };

    this.notifications.push(notification);

    this.logger.log(
      `📱 Notification sent: "${dto.title}" to ${dto.broadcast ? 'all users' : dto.userIds?.length || 0} recipients`,
    );

    // In production, implement FCM integration:
    // await this.fcmService.sendMulticast({
    //   notification: { title: dto.title, body: dto.body },
    //   data: dto.data,
    //   tokens: userTokens,
    // });

    return notification;
  }

  /**
   * Send proximity notification (when user is near a POI)
   */
  async sendProximityAlert(
    userId: string,
    poiName: string,
    distance: number,
  ): Promise<void> {
    await this.send({
      title: 'Point of Interest Nearby!',
      body: `You are ${Math.round(distance)}m from ${poiName}`,
      userIds: [userId],
      data: {
        type: 'proximity_alert',
        poi_name: poiName,
        distance: distance.toString(),
      },
    });
  }

  /**
   * Send trail completion notification
   */
  async sendTrailCompletionNotification(
    userId: string,
    trailName: string,
    duration: number,
  ): Promise<void> {
    const hours = Math.floor(duration / 3600);
    const minutes = Math.floor((duration % 3600) / 60);
    const timeStr = hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;

    await this.send({
      title: 'Trail Completed! 🎉',
      body: `Congratulations! You completed ${trailName} in ${timeStr}`,
      userIds: [userId],
      data: {
        type: 'trail_completed',
        trail_name: trailName,
        duration: duration.toString(),
      },
    });
  }

  /**
   * Get notification history (admin)
   */
  async getHistory(limit: number = 50): Promise<NotificationRecord[]> {
    return this.notifications
      .sort((a, b) => b.sentAt.getTime() - a.sentAt.getTime())
      .slice(0, limit);
  }

  private generateId(): string {
    return `notif_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}
