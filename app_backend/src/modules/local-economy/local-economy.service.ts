import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { LocalService, ServiceCategory } from './entities/local-service.entity';
import { CreateLocalServiceDto } from './dto/create-local-service.dto';
import { UpdateLocalServiceDto } from './dto/update-local-service.dto';
import { PaginationDto, PaginatedResult } from '../../common/dto/pagination.dto';

@Injectable()
export class LocalEconomyService {
  constructor(
    @InjectRepository(LocalService)
    private localServicesRepository: Repository<LocalService>,
  ) {}

  async create(createDto: CreateLocalServiceDto): Promise<LocalService> {
    const service = this.localServicesRepository.create(createDto);
    return this.localServicesRepository.save(service);
  }

  async findAll(
    paginationDto: PaginationDto,
    category?: ServiceCategory,
  ): Promise<PaginatedResult<LocalService>> {
    const { page, limit, includeInactive } = paginationDto;
    const skip = (page - 1) * limit;

    const queryBuilder = this.localServicesRepository
      .createQueryBuilder('service');

    if (!includeInactive) {
      queryBuilder.where('service.isActive = :isActive', { isActive: true });
    }

    if (category) {
      queryBuilder.andWhere('service.category = :category', { category });
    }

    queryBuilder.orderBy('service.createdAt', 'DESC').skip(skip).take(limit);

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

  async findNearby(
    lat: number,
    lng: number,
    radius: number = 50,
    category?: ServiceCategory,
  ): Promise<LocalService[]> {
    const radiusInMeters = radius * 1000;

    const queryBuilder = this.localServicesRepository
      .createQueryBuilder('service')
      .where('service.isActive = :isActive', { isActive: true })
      .andWhere('service.latitude IS NOT NULL')
      .andWhere('service.longitude IS NOT NULL')
      .andWhere(
        `ST_DWithin(
          ST_SetSRID(ST_MakePoint(service.longitude, service.latitude), 4326)::geography,
          ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
          :radius
        )`,
        { lat, lng, radius: radiusInMeters },
      );

    if (category) {
      queryBuilder.andWhere('service.category = :category', { category });
    }

    queryBuilder
      .orderBy(
        `ST_Distance(
          ST_SetSRID(ST_MakePoint(service.longitude, service.latitude), 4326)::geography,
          ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
        )`,
        'ASC',
      )
      .setParameters({ lat, lng });

    return queryBuilder.getMany();
  }

  async findOne(id: string): Promise<LocalService> {
    const service = await this.localServicesRepository.findOne({
      where: { id },
    });

    if (!service) {
      throw new NotFoundException(`Local service with ID ${id} not found`);
    }

    return service;
  }

  async update(id: string, updateDto: UpdateLocalServiceDto): Promise<LocalService> {
    const service = await this.findOne(id);
    Object.assign(service, updateDto);
    return this.localServicesRepository.save(service);
  }

  async remove(id: string): Promise<void> {
    const service = await this.findOne(id);
    await this.localServicesRepository.remove(service);
  }
}
