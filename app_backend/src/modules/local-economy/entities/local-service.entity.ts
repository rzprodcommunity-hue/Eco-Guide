import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum ServiceCategory {
  GUIDE = 'guide',
  ARTISAN = 'artisan',
  ACCOMMODATION = 'accommodation',
  RESTAURANT = 'restaurant',
  TRANSPORT = 'transport',
  EQUIPMENT = 'equipment',
}

@Entity('local_services')
export class LocalService {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({
    type: 'enum',
    enum: ServiceCategory,
  })
  category: ServiceCategory;

  @Column('text')
  description: string;

  @Column({ nullable: true })
  contact: string; // phone number

  @Column({ nullable: true })
  email: string;

  @Column({ nullable: true })
  website: string;

  @Column({ nullable: true })
  address: string;

  @Column('decimal', { precision: 10, scale: 7, nullable: true })
  latitude: number;

  @Column('decimal', { precision: 10, scale: 7, nullable: true })
  longitude: number;

  @Column('geometry', {
    spatialFeatureType: 'Point',
    srid: 4326,
    nullable: true,
  })
  location: string; // PostGIS Point

  @Column({ nullable: true })
  imageUrl: string;

  @Column('simple-array', { nullable: true })
  additionalImages: string[];

  @Column('simple-array', { nullable: true })
  languages: string[]; // Languages spoken

  @Column('decimal', { precision: 3, scale: 2, nullable: true })
  rating: number;

  @Column({ default: 0 })
  reviewCount: number;

  @Column({ default: true })
  isActive: boolean;

  @Column({ default: false })
  isVerified: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
