import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { WeatherService } from './weather.service';
import { WeatherQueryDto } from './dto/weather-query.dto';

@ApiTags('weather')
@Controller('weather')
export class WeatherController {
  constructor(private readonly weatherService: WeatherService) {}

  @Get('current')
  @ApiOperation({ summary: 'Get current weather for coordinates' })
  @ApiResponse({ status: 200, description: 'Current weather data' })
  getCurrent(@Query() queryDto: WeatherQueryDto) {
    return this.weatherService.getCurrentWeather(queryDto.lat, queryDto.lng);
  }
}
