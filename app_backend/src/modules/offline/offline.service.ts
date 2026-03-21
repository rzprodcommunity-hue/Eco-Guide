import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { OfflineCache, CacheResourceType } from './entities/offline-cache.entity';
import { CacheRequestDto } from './dto/cache-request.dto';
import { TrailsService } from '../trails/trails.service';
import { PoisService } from '../pois/pois.service';

@Injectable()
export class OfflineService {
  constructor(
    @InjectRepository(OfflineCache)
    private cacheRepository: Repository<OfflineCache>,
    private trailsService: TrailsService,
    private poisService: PoisService,
  ) {}

  async markAsDownloaded(userId: string, dto: CacheRequestDto): Promise<OfflineCache> {
    // Check if already cached
    let cache = await this.cacheRepository.findOne({
      where: {
        userId,
        resourceType: dto.resourceType,
        resourceId: dto.resourceId,
      },
    });

    if (cache) {
      // Update existing cache entry
      cache.version += 1;
      cache.downloadedAt = new Date();
      cache.expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days
      if (dto.sizeBytes) {
        cache.sizeBytes = dto.sizeBytes;
      }
    } else {
      // Create new cache entry
      cache = this.cacheRepository.create({
        userId,
        resourceType: dto.resourceType,
        resourceId: dto.resourceId,
        sizeBytes: dto.sizeBytes || 0,
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
      });
    }

    return this.cacheRepository.save(cache);
  }

  async getUserDownloads(userId: string): Promise<OfflineCache[]> {
    return this.cacheRepository.find({
      where: { userId },
      order: { downloadedAt: 'DESC' },
    });
  }

  async getSyncStatus(userId: string): Promise<{
    totalCached: number;
    totalSizeBytes: number;
    byType: Record<string, number>;
    expiringSoon: number;
  }> {
    const downloads = await this.getUserDownloads(userId);
    const now = new Date();
    const sevenDaysFromNow = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

    const byType: Record<string, number> = {};
    let totalSizeBytes = 0;
    let expiringSoon = 0;

    downloads.forEach((d) => {
      byType[d.resourceType] = (byType[d.resourceType] || 0) + 1;
      totalSizeBytes += Number(d.sizeBytes);
      if (d.expiresAt && d.expiresAt < sevenDaysFromNow) {
        expiringSoon++;
      }
    });

    return {
      totalCached: downloads.length,
      totalSizeBytes,
      byType,
      expiringSoon,
    };
  }

  async getAvailablePackages(): Promise<{
    trails: { id: string; name: string; size: number }[];
    regions: { name: string; trailCount: number; totalSize: number }[];
  }> {
    // Get all active trails for offline download
    const trailsResult = await this.trailsService.findAll({
      page: 1,
      limit: 100,
    });

    const trails = trailsResult.data.map((trail) => ({
      id: trail.id,
      name: trail.name,
      size: 1024 * 1024 * 5, // Estimated 5MB per trail with map tiles
    }));

    // Group by region
    const regionMap = new Map<string, { trailCount: number; totalSize: number }>();
    trailsResult.data.forEach((trail) => {
      const region = trail.region || 'Unknown';
      const current = regionMap.get(region) || { trailCount: 0, totalSize: 0 };
      current.trailCount++;
      current.totalSize += 1024 * 1024 * 5;
      regionMap.set(region, current);
    });

    const regions = Array.from(regionMap.entries()).map(([name, data]) => ({
      name,
      ...data,
    }));

    return { trails, regions };
  }

  async removeDownload(userId: string, cacheId: string): Promise<void> {
    await this.cacheRepository.delete({ id: cacheId, userId });
  }

  async clearAllDownloads(userId: string): Promise<void> {
    await this.cacheRepository.delete({ userId });
  }
}
