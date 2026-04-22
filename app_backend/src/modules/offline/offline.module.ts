import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { OfflineService } from './offline.service';
import { OfflineController } from './offline.controller';
import { OfflineCache } from './entities/offline-cache.entity';
import { TrailsModule } from '../trails/trails.module';
import { PoisModule } from '../pois/pois.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([OfflineCache]),
    TrailsModule,
    PoisModule,
  ],
  controllers: [OfflineController],
  providers: [OfflineService],
  exports: [OfflineService],
})
export class OfflineModule {}
