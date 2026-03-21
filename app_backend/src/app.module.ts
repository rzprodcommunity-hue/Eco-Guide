import { Module } from '@nestjs/common';
import { ConfigModule } from './config/config.module';
import { DatabaseModule } from './database/database.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { TrailsModule } from './modules/trails/trails.module';
import { PoisModule } from './modules/pois/pois.module';
import { QuizzesModule } from './modules/quizzes/quizzes.module';
import { LocalEconomyModule } from './modules/local-economy/local-economy.module';
import { MediaModule } from './modules/media/media.module';
import { SosModule } from './modules/sos/sos.module';
import { ActivitiesModule } from './modules/activities/activities.module';
import { OfflineModule } from './modules/offline/offline.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { AdminModule } from './modules/admin/admin.module';

@Module({
  imports: [
    // Core configuration
    ConfigModule,
    DatabaseModule,

    // Authentication & Users
    AuthModule,
    UsersModule,

    // Core domain modules
    TrailsModule,
    PoisModule,

    // Supporting modules
    QuizzesModule,
    LocalEconomyModule,
    MediaModule,
    SosModule,
    ActivitiesModule,

    // Mobile support modules
    OfflineModule,
    NotificationsModule,

    // Backoffice module
    AdminModule,
  ],
})
export class AppModule {}
