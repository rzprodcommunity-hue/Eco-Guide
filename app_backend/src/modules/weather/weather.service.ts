import { Injectable, ServiceUnavailableException } from '@nestjs/common';

export interface CurrentWeatherResponse {
  temperature: number;
  humidity: number;
  windSpeed: number;
  weatherCode: number;
  isDay: boolean;
  condition: string;
  summary: string;
  latitude: number;
  longitude: number;
}

@Injectable()
export class WeatherService {
  private readonly DEFAULT_LAT = 36.9544; // Tabarka Coast
  private readonly DEFAULT_LNG = 8.7580;    // Tabarka, Tunisia

  async getCurrentWeather(lat?: number, lng?: number): Promise<CurrentWeatherResponse> {
    const latitude = lat ?? this.DEFAULT_LAT;
    const longitude = lng ?? this.DEFAULT_LNG;

    const url = new URL('https://api.open-meteo.com/v1/forecast');
    url.searchParams.set('latitude', latitude.toString());
    url.searchParams.set('longitude', longitude.toString());
    url.searchParams.set(
      'current',
      'temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,is_day',
    );

    let response: Response;
    try {
      response = await fetch(url);
    } catch (error) {
      throw new ServiceUnavailableException('Weather provider unavailable');
    }

    if (!response.ok) {
      throw new ServiceUnavailableException('Unable to fetch weather data');
    }

    const payload = (await response.json()) as {
      current?: {
        temperature_2m?: number;
        relative_humidity_2m?: number;
        wind_speed_10m?: number;
        weather_code?: number;
        is_day?: number;
      };
    };

    const current = payload.current;
    if (!current) {
      throw new ServiceUnavailableException('Invalid weather response');
    }

    const weatherCode = current.weather_code ?? 0;
    const condition = this.mapCondition(weatherCode);
    const temperature = current.temperature_2m ?? 0;
    const humidity = current.relative_humidity_2m ?? 0;
    const windSpeed = current.wind_speed_10m ?? 0;

    return {
      temperature,
      humidity,
      windSpeed,
      weatherCode,
      isDay: (current.is_day ?? 1) === 1,
      condition,
      summary: this.buildSummary(condition, temperature, windSpeed),
      latitude,
      longitude,
    };
  }

  private mapCondition(code: number): string {
    if (code === 0) return 'Clear';
    if ([1, 2, 3].includes(code)) return 'Partly cloudy';
    if ([45, 48].includes(code)) return 'Fog';
    if ([51, 53, 55, 56, 57].includes(code)) return 'Drizzle';
    if ([61, 63, 65, 66, 67, 80, 81, 82].includes(code)) return 'Rain';
    if ([71, 73, 75, 77, 85, 86].includes(code)) return 'Snow';
    if ([95, 96, 99].includes(code)) return 'Thunderstorm';
    return 'Variable';
  }

  private buildSummary(condition: string, temperature: number, windSpeed: number): string {
    if (condition === 'Clear' && temperature >= 18 && windSpeed < 20) {
      return 'Perfect for hiking';
    }
    if (condition === 'Rain' || condition === 'Thunderstorm') {
      return 'Trail caution recommended';
    }
    if (temperature < 8) {
      return 'Cold conditions expected';
    }
    return 'Good outdoor conditions';
  }
}
