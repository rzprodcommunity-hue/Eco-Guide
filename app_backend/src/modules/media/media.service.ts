import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { v2 as cloudinary, UploadApiResponse } from 'cloudinary';

@Injectable()
export class MediaService {
  constructor(private configService: ConfigService) {
    cloudinary.config({
      cloud_name: this.configService.get('cloudinary.cloudName'),
      api_key: this.configService.get('cloudinary.apiKey'),
      api_secret: this.configService.get('cloudinary.apiSecret'),
    });
  }

  private getActualMimeType(file: Express.Multer.File): string {
    if (!file.mimetype || file.mimetype === 'application/octet-stream') {
      const ext = file.originalname?.split('.').pop()?.toLowerCase();
      if (ext === 'jpg' || ext === 'jpeg') return 'image/jpeg';
      if (ext === 'png') return 'image/png';
      if (ext === 'gif') return 'image/gif';
      if (ext === 'webp') return 'image/webp';
      if (ext === 'mp4') return 'video/mp4';
      if (ext === 'mov') return 'video/quicktime';
      if (ext === 'avi') return 'video/x-msvideo';
      if (ext === 'mp3') return 'audio/mpeg';
      if (ext === 'wav') return 'audio/wav';
      if (ext === 'ogg') return 'audio/ogg';
    }
    return file.mimetype;
  }

  async uploadImage(
    file: Express.Multer.File,
    folder: string = 'eco-guide',
  ): Promise<{ url: string; publicId: string }> {
    if (!file) {
      throw new BadRequestException('No file provided');
    }

    const actualMimeType = this.getActualMimeType(file);
    const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
    if (!allowedMimeTypes.includes(actualMimeType)) {
      throw new BadRequestException(`Invalid file type. Only JPEG, PNG, GIF, and WebP are allowed. Got ${actualMimeType} from ${file.originalname}`);
    }

    try {
      const result = await this.uploadToCloudinary(file.buffer, folder, 'image');
      return {
        url: result.secure_url,
        publicId: result.public_id,
      };
    } catch (error) {
      throw new BadRequestException(`Failed to upload image: ${error.message}`);
    }
  }

  async uploadVideo(
    file: Express.Multer.File,
    folder: string = 'eco-guide/videos',
  ): Promise<{ url: string; publicId: string }> {
    if (!file) {
      throw new BadRequestException('No file provided');
    }

    const actualMimeType = this.getActualMimeType(file);
    const allowedMimeTypes = ['video/mp4', 'video/quicktime', 'video/x-msvideo'];
    if (!allowedMimeTypes.includes(actualMimeType)) {
      throw new BadRequestException(`Invalid file type. Only MP4, MOV, and AVI are allowed. Got ${actualMimeType}`);
    }

    // Check file size (max 100MB for videos)
    const maxSize = 100 * 1024 * 1024;
    if (file.size > maxSize) {
      throw new BadRequestException('File size exceeds 100MB limit.');
    }

    try {
      const result = await this.uploadToCloudinary(file.buffer, folder, 'video');
      return {
        url: result.secure_url,
        publicId: result.public_id,
      };
    } catch (error) {
      throw new BadRequestException(`Failed to upload video: ${error.message}`);
    }
  }

  async uploadAudio(
    file: Express.Multer.File,
    folder: string = 'eco-guide/audio',
  ): Promise<{ url: string; publicId: string }> {
    if (!file) {
      throw new BadRequestException('No file provided');
    }

    const actualMimeType = this.getActualMimeType(file);
    const allowedMimeTypes = ['audio/mpeg', 'audio/wav', 'audio/ogg'];
    if (!allowedMimeTypes.includes(actualMimeType)) {
      throw new BadRequestException(`Invalid file type. Only MP3, WAV, and OGG are allowed. Got ${actualMimeType}`);
    }

    try {
      const result = await this.uploadToCloudinary(file.buffer, folder, 'auto');
      return {
        url: result.secure_url,
        publicId: result.public_id,
      };
    } catch (error) {
      throw new BadRequestException(`Failed to upload audio: ${error.message}`);
    }
  }

  async deleteFile(publicId: string): Promise<void> {
    try {
      await cloudinary.uploader.destroy(publicId);
    } catch (error) {
      throw new BadRequestException(`Failed to delete file: ${error.message}`);
    }
  }

  private uploadToCloudinary(
    buffer: Buffer,
    folder: string,
    resourceType: 'image' | 'video' | 'auto',
  ): Promise<UploadApiResponse> {
    return new Promise((resolve, reject) => {
      cloudinary.uploader
        .upload_stream(
          {
            folder,
            resource_type: resourceType,
          },
          (error, result) => {
            if (error) {
              reject(error);
            } else if (result) {
              resolve(result);
            } else {
              reject(new Error('Upload failed: no result returned'));
            }
          },
        )
        .end(buffer);
    });
  }
}
