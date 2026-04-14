import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SosService } from './sos.service';
import { SosController } from './sos.controller';
import { SosAlert } from './entities/sos-alert.entity';

@Module({
  imports: [TypeOrmModule.forFeature([SosAlert])],
  controllers: [SosController],
  providers: [SosService],
  exports: [SosService],
})
export class SosModule {}
