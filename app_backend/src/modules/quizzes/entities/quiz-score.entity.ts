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

@Entity('quiz_scores')
@Index(['userId', 'category'], { unique: true })
export class QuizScore {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column()
  userId: string;

  @Column({
    type: 'enum',
    enum: QuizCategory,
    nullable: true,
  })
  category: QuizCategory | null;

  @Column({ default: 0 })
  totalScore: number;

  @Column({ default: 0 })
  quizzesCompleted: number;

  @Column({ default: 0 })
  correctAnswers: number;

  @Column({ default: 0 })
  totalQuestions: number;

  @Column({ type: 'float', default: 0 })
  bestPercentage: number;

  @CreateDateColumn()
  createdAt: Date;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  lastPlayedAt: Date;
}
