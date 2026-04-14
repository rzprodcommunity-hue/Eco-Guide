import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Brackets, Repository } from 'typeorm';
import { Poi } from './entities/poi.entity';
import { CreatePoiDto } from './dto/create-poi.dto';
import { UpdatePoiDto } from './dto/update-poi.dto';
import { PoiQueryDto, PoiNearbyQueryDto } from './dto/poi-query.dto';
import { PaginatedResult } from '../../common/dto/pagination.dto';
import { EventsGateway } from '../events/events.gateway';

@Injectable()
export class PoisService {
  constructor(
    @InjectRepository(Poi)
    private poisRepository: Repository<Poi>,
    private readonly eventsGateway: EventsGateway,
  ) {}

  async create(createPoiDto: CreatePoiDto): Promise<Poi> {
    const poi = this.poisRepository.create(createPoiDto);
    const savedPoi = await this.poisRepository.save(poi);
    this.eventsGateway.broadcast('poi_updated', { action: 'create', data: savedPoi });
    return savedPoi;
  }

  async findAll(queryDto: PoiQueryDto): Promise<PaginatedResult<Poi>> {
    const { page, limit, search, type, trailId, includeInactive } = queryDto;
    const skip = (page - 1) * limit;

    const queryBuilder = this.poisRepository
      .createQueryBuilder('poi')
      .leftJoinAndSelect('poi.trail', 'trail');

    if (!includeInactive) {
      queryBuilder.where('poi.isActive = :isActive', { isActive: true });
    }

    if (type) {
      queryBuilder.andWhere('poi.type = :type', { type });
    }

    if (search?.trim()) {
      const startsWith = `${search.trim()}%`;
      queryBuilder.andWhere(
        new Brackets((qb) => {
          qb.where('poi.name ILIKE :startsWith', { startsWith })
            .orWhere('poi.description ILIKE :startsWith', { startsWith })
            .orWhere('poi.badge ILIKE :startsWith', { startsWith })
            .orWhere('CAST(poi.type AS TEXT) ILIKE :startsWith', { startsWith });
        }),
      );
    }

    if (trailId) {
      queryBuilder.andWhere('poi.trailId = :trailId', { trailId });
    }

    queryBuilder.orderBy('poi.createdAt', 'DESC').skip(skip).take(limit);

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

  async findNearby(queryDto: PoiNearbyQueryDto): Promise<Poi[]> {
    const { lat, lng, radius, type } = queryDto;
    const radiusInMeters = radius * 1000;

    const queryBuilder = this.poisRepository
      .createQueryBuilder('poi')
      .leftJoinAndSelect('poi.trail', 'trail')
      .where('poi.isActive = :isActive', { isActive: true })
      .andWhere(
        `ST_DWithin(
          ST_SetSRID(ST_MakePoint(poi.longitude, poi.latitude), 4326)::geography,
          ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
          :radius
        )`,
        { lat, lng, radius: radiusInMeters },
      );

    if (type) {
      queryBuilder.andWhere('poi.type = :type', { type });
    }

    queryBuilder
      .orderBy(
        `ST_Distance(
          ST_SetSRID(ST_MakePoint(poi.longitude, poi.latitude), 4326)::geography,
          ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
        )`,
        'ASC',
      )
      .setParameters({ lat, lng });

    return queryBuilder.getMany();
  }

  async findByTrail(trailId: string): Promise<Poi[]> {
    return this.poisRepository.find({
      where: { trailId, isActive: true },
      order: { createdAt: 'ASC' },
    });
  }

  async findOne(id: string): Promise<Poi> {
    const poi = await this.poisRepository.findOne({
      where: { id },
      relations: ['trail'],
    });

    if (!poi) {
      throw new NotFoundException(`POI with ID ${id} not found`);
    }

    return poi;
  }

  async update(id: string, updatePoiDto: UpdatePoiDto): Promise<Poi> {
    const poi = await this.findOne(id);
    Object.assign(poi, updatePoiDto);
    const updatedPoi = await this.poisRepository.save(poi);
    this.eventsGateway.broadcast('poi_updated', { action: 'update', data: updatedPoi });
    return updatedPoi;
  }

  async remove(id: string): Promise<void> {
    const poi = await this.findOne(id);
    await this.poisRepository.remove(poi);
    this.eventsGateway.broadcast('poi_updated', { action: 'delete', id });
  }
}
