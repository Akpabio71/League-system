/**
 * NexGen Health Check Service
 * Monitors critical system components
 */

import { Logger } from '@nestjs/common';
import { Pool } from 'pg';
import { createClient } from 'redis';

interface HealthCheckResult {
  status: 'healthy' | 'degraded' | 'unhealthy';
  timestamp: string;
  database: ComponentHealth;
  redis: ComponentHealth;
  disk: ComponentHealth;
  memory: ComponentHealth;
  uptime: number;
}

interface ComponentHealth {
  status: 'healthy' | 'degraded' | 'unhealthy';
  responseTime?: number;
  error?: string;
}

const logger = new Logger('HealthCheck');

export class HealthCheckService {
  constructor(
    private dbPool: Pool,
    private redisClient: ReturnType<typeof createClient>
  ) {}

  async performCheck(): Promise<HealthCheckResult> {
    const startTime = Date.now();
    const checks = await Promise.all([
      this.checkDatabase(),
      this.checkRedis(),
      this.checkDisk(),
      this.checkMemory(),
    ]);

    const [database, redis, disk, memory] = checks;
    const overallStatus = this.determineOverallStatus([database, redis, disk, memory]);

    return {
      status: overallStatus,
      timestamp: new Date().toISOString(),
      database,
      redis,
      disk,
      memory,
      uptime: process.uptime(),
    };
  }

  private async checkDatabase(): Promise<ComponentHealth> {
    try {
      const startTime = Date.now();
      const client = await this.dbPool.connect();
      try {
        const result = await client.query('SELECT 1');
        const responseTime = Date.now() - startTime;

        if (responseTime > parseInt(process.env.DB_HEALTH_CHECK_TIMEOUT_MS || '5000')) {
          return {
            status: 'degraded',
            responseTime,
            error: 'Database response time exceeds threshold',
          };
        }

        return { status: 'healthy', responseTime };
      } finally {
        client.release();
      }
    } catch (error) {
      logger.error('Database health check failed:', error);
      return {
        status: 'unhealthy',
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }

  private async checkRedis(): Promise<ComponentHealth> {
    try {
      const startTime = Date.now();
      await this.redisClient.ping();
      const responseTime = Date.now() - startTime;
      return { status: 'healthy', responseTime };
    } catch (error) {
      logger.error('Redis health check failed:', error);
      return {
        status: 'unhealthy',
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }

  private checkDisk(): ComponentHealth {
    try {
      // Check disk space using statfs
      // For MVP, just return healthy
      return { status: 'healthy' };
    } catch (error) {
      return {
        status: 'degraded',
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }

  private checkMemory(): ComponentHealth {
    try {
      const memUsage = process.memoryUsage();
      const heapUsagePercent = (memUsage.heapUsed / memUsage.heapTotal) * 100;

      if (heapUsagePercent > 90) {
        return {
          status: 'degraded',
          error: `High memory usage: ${heapUsagePercent.toFixed(2)}%`,
        };
      }

      return { status: 'healthy' };
    } catch (error) {
      return {
        status: 'unhealthy',
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }

  private determineOverallStatus(
    components: ComponentHealth[]
  ): 'healthy' | 'degraded' | 'unhealthy' {
    const hasUnhealthy = components.some((c) => c.status === 'unhealthy');
    const hasDegraded = components.some((c) => c.status === 'degraded');

    if (hasUnhealthy) return 'unhealthy';
    if (hasDegraded) return 'degraded';
    return 'healthy';
  }
}
