import { ApiProperty } from '@nestjs/swagger';

export class UploadResponseDto {
  @ApiProperty({ example: 'https://res.cloudinary.com/xxx/image/upload/v123/eco-guide/abc.jpg' })
  url: string;

  @ApiProperty({ example: 'eco-guide/abc' })
  publicId: string;
}
