import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

export enum CacheResourceType {
  TRAIL = 'trail',
  POI = 'poi',
  QUIZ = 'quiz',
  FULL_REGION = 'full_region',
}

@Entity('offline_cache')
export class OfflineCache {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column()
  userId: string;

  @Column({
    type: 'enum',
    enum: CacheResourceType,
  })
  resourceType: CacheResourceType;

  @Column('varchar')
  resourceId: string;

  @Column({ default: 1 })
  version: number;

  @CreateDateColumn()
  downloadedAt: Date;

  @Column({ nullable: true })
  expiresAt: Date;

  @Column('bigint', { default: 0 })
  sizeBytes: number;
}
