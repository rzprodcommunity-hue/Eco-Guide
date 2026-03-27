import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { QuizCategory } from './quiz.entity';

@Entity('quiz_badges')
@Index(['userId', 'key'], { unique: true })
export class QuizBadge {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column()
  userId: string;

  @Column()
  key: string;

  @Column()
  label: string;

  @Column({ nullable: true })
  description: string;

  @Column({ nullable: true })
  icon: string;

  @Column({ nullable: true })
  color: string;

  @Column('int')
  threshold: number;

  @Column({
    type: 'enum',
    enum: QuizCategory,
    nullable: true,
  })
  category: QuizCategory | null;

  @CreateDateColumn()
  unlockedAt: Date;
}