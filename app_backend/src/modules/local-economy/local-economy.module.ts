import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LocalEconomyService } from './local-economy.service';
import { LocalEconomyController } from './local-economy.controller';
import { LocalService } from './entities/local-service.entity';

@Module({
  imports: [TypeOrmModule.forFeature([LocalService])],
  controllers: [LocalEconomyController],
  providers: [LocalEconomyService],
  exports: [LocalEconomyService],
})
export class LocalEconomyModule {}
