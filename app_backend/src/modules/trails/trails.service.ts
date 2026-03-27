import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Brackets, Repository } from 'typeorm';
import { Trail } from './entities/trail.entity';
import { CreateTrailDto } from './dto/create-trail.dto';
import { UpdateTrailDto } from './dto/update-trail.dto';
import { TrailQueryDto, NearbyQueryDto } from './dto/trail-query.dto';
import { PaginatedResult } from '../../common/dto/pagination.dto';

@Injectable()
export class TrailsService {
  constructor(
    @InjectRepository(Trail)
    private trailsRepository: Repository<Trail>,
  ) {}

  async create(createTrailDto: CreateTrailDto): Promise<Trail> {
    const trail = this.trailsRepository.create(createTrailDto);
    return this.trailsRepository.save(trail);
  }

  async findAll(queryDto: TrailQueryDto): Promise<PaginatedResult<Trail>> {
    const {
      page,
      limit,
      search,
      difficulty,
      region,
      minDistance,
      maxDistance,
      maxDuration,
      sortBy,
      sortOrder,
      includeInactive,
    } = queryDto;
    const skip = (page - 1) * limit;

    const queryBuilder = this.trailsRepository.createQueryBuilder('trail');

    // Apply filters
    if (!includeInactive) {
      queryBuilder.where('trail.isActive = :isActive', { isActive: true });
    }

    if (difficulty) {
      queryBuilder.andWhere('trail.difficulty = :difficulty', { difficulty });
    }

    if (search?.trim()) {
      const startsWith = `${search.trim()}%`;
      queryBuilder.andWhere(
        new Brackets((qb) => {
          qb.where('trail.name ILIKE :startsWith', { startsWith })
            .orWhere('trail.region ILIKE :startsWith', { startsWith })
            .orWhere('trail.description ILIKE :startsWith', { startsWith });
        }),
      );
    }

    if (region) {
      queryBuilder.andWhere('trail.region ILIKE :region', { region: `%${region}%` });
    }

    if (minDistance !== undefined) {
      queryBuilder.andWhere('trail.distance >= :minDistance', { minDistance });
    }

    if (maxDistance !== undefined) {
      queryBuilder.andWhere('trail.distance <= :maxDistance', { maxDistance });
    }

    if (maxDuration !== undefined) {
      queryBuilder.andWhere('trail.estimatedDuration <= :maxDuration', { maxDuration });
    }

    // Apply sorting
    const validSortFields = ['name', 'distance', 'difficulty', 'createdAt', 'estimatedDuration'];
    const sortField = sortBy && validSortFields.includes(sortBy) ? sortBy : 'createdAt';
    const order = sortOrder === 'ASC' ? 'ASC' : 'DESC';
    queryBuilder.orderBy(`trail.${sortField}`, order);

    // Apply pagination
    queryBuilder.skip(skip).take(limit);

    const [data, total] = await queryBuilder.getManyAndCount();

    return {
      data,
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async findNearby(queryDto: NearbyQueryDto): Promise<Trail[]> {
    const { lat, lng, radius } = queryDto;
    const radiusInMeters = radius * 1000;

    // Using PostGIS ST_DWithin for efficient proximity search
    const trails = await this.trailsRepository
      .createQueryBuilder('trail')
      .where('trail.isActive = :isActive', { isActive: true })
      .andWhere(
        `ST_DWithin(
          ST_SetSRID(ST_MakePoint(trail."startLongitude", trail."startLatitude"), 4326)::geography,
          ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
          :radius
        )`,
        { lat, lng, radius: radiusInMeters },
      )
      .orderBy(
        `ST_Distance(
          ST_SetSRID(ST_MakePoint(trail."startLongitude", trail."startLatitude"), 4326)::geography,
          ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
        )`,
        'ASC',
      )
      .setParameters({ lat, lng })
      .getMany();

    return trails;
  }

  async findOne(id: string): Promise<Trail> {
    const trail = await this.trailsRepository.findOne({
      where: { id },
    });

    if (!trail) {
      throw new NotFoundException(`Trail with ID ${id} not found`);
    }

    return trail;
  }

  async update(id: string, updateTrailDto: UpdateTrailDto): Promise<Trail> {
    const trail = await this.findOne(id);
    Object.assign(trail, updateTrailDto);
    return this.trailsRepository.save(trail);
  }

  async remove(id: string): Promise<void> {
    const trail = await this.findOne(id);
    await this.trailsRepository.remove(trail);
  }
}
