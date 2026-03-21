import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Trail } from '../../trails/entities/trail.entity';
import { Poi } from '../../pois/entities/poi.entity';

export enum QuizCategory {
  FLORA = 'flora',
  FAUNA = 'fauna',
  ECOLOGY = 'ecology',
  HISTORY = 'history',
  GEOGRAPHY = 'geography',
  SAFETY = 'safety',
}

@Entity('quizzes')
export class Quiz {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  question: string;

  @Column('jsonb')
  answers: string[]; // Array of answer options

  @Column('int')
  correctAnswerIndex: number;

  @Column({ nullable: true })
  explanation: string;

  @Column({
    type: 'enum',
    enum: QuizCategory,
    nullable: true,
  })
  category: QuizCategory;

  @Column({ nullable: true })
  imageUrl: string;

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

  @Column({ default: 10 })
  points: number;

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;
}
