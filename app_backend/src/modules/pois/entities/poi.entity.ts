import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Trail } from '../../trails/entities/trail.entity';

export enum PoiType {
  VIEWPOINT = 'viewpoint',
  FLORA = 'flora',
  FAUNA = 'fauna',
  HISTORICAL = 'historical',
  WATER = 'water',
  CAMPING = 'camping',
  DANGER = 'danger',
  REST_AREA = 'rest_area',
  INFORMATION = 'information',
}

@Entity('pois')
export class Poi {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({
    type: 'enum',
    enum: PoiType,
    default: PoiType.VIEWPOINT,
  })
  type: PoiType;

  @Column('text')
  description: string;

  @Column({ nullable: true })
  badge: string;

  @Column({ nullable: true })
  learnMoreUrl: string;

  @Column('decimal', { precision: 10, scale: 7 })
  latitude: number;

  @Column('decimal', { precision: 10, scale: 7 })
  longitude: number;

  @Column('geometry', {
    spatialFeatureType: 'Point',
    srid: 4326,
    nullable: true,
  })
  location: string; // PostGIS Point

  @Column({ nullable: true })
  mediaUrl: string;

  @Column('simple-array', { nullable: true })
  additionalMediaUrls: string[];

  @Column({ nullable: true })
  audioGuideUrl: string;

  @ManyToOne(() => Trail, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'trailId' })
  trail: Trail;

  @Column({ nullable: true })
  trailId: string;

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
