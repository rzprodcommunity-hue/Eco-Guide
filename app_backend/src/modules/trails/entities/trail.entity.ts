import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';

export enum TrailDifficulty {
  EASY = 'easy',
  MODERATE = 'moderate',
  DIFFICULT = 'difficult',
}

@Entity('trails')
export class Trail {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column('text')
  description: string;

  @Column('decimal', { precision: 10, scale: 2 })
  distance: number; // in kilometers

  @Column({
    type: 'enum',
    enum: TrailDifficulty,
    default: TrailDifficulty.MODERATE,
  })
  difficulty: TrailDifficulty;

  @Column('jsonb', { nullable: true })
  geojson: object; // GeoJSON LineString for the trail path

  @Column('geometry', {
    spatialFeatureType: 'LineString',
    srid: 4326,
    nullable: true,
  })
  geometry: string; // PostGIS geometry for spatial queries

  @Column({ nullable: true })
  estimatedDuration: number; // in minutes

  @Column({ nullable: true })
  elevationGain: number; // in meters

  @Column('simple-array', { nullable: true })
  imageUrls: string[];

  @Column({ nullable: true })
  region: string;

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  // Start point coordinates for proximity searches
  @Column('decimal', { precision: 10, scale: 7, nullable: true })
  startLatitude: number;

  @Column('decimal', { precision: 10, scale: 7, nullable: true })
  startLongitude: number;
}
