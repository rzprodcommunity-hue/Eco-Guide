import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Trail } from '../../trails/entities/trail.entity';
import { Poi } from '../../pois/entities/poi.entity';

export enum ActivityType {
  TRAIL_STARTED = 'trail_started',
  TRAIL_COMPLETED = 'trail_completed',
  POI_VISITED = 'poi_visited',
  QUIZ_ANSWERED = 'quiz_answered',
  DOWNLOAD = 'download',
}

@Entity('activities')
export class Activity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column()
  userId: string;

  @Column({
    type: 'enum',
    enum: ActivityType,
  })
  type: ActivityType;

  @ManyToOne(() => Trail, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'trailId' })
  trail: Trail;

  @Column({ nullable: true })
  trailId: string;

  @ManyToOne(() => Poi, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'poiId' })
  poi: Poi;

  @Column({ nullable: true })
  poiId: string;

  @Column('jsonb', { nullable: true })
  metadata: Record<string, any>; // Additional data: quiz score, duration, distance covered, etc.

  @CreateDateColumn()
  createdAt: Date;
}
