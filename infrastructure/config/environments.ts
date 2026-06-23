/**
 * NexGen Environment Configuration
 * Defines configuration for local, staging, and production environments
 */

export interface EnvironmentConfig {
  nodeEnv: 'development' | 'staging' | 'production';
  port: number;
  apiBaseUrl: string;
  frontendUrl: string;
  database: DatabaseConfig;
  jwt: JwtConfig;
  security: SecurityConfig;
  storage: StorageConfig;
  realtime: RealtimeConfig;
  jobs: JobsConfig;
  logging: LoggingConfig;
  monitoring: MonitoringConfig;
}

export interface DatabaseConfig {
  url: string;
  host: string;
  port: number;
  name: string;
  user: string;
  password: string;
  pool: {
    min: number;
    max: number;
  };
  timeout: number;
  idleTimeout: number;
}

export interface JwtConfig {
  secret: string;
  accessTokenExpiresIn: number;
  refreshTokenExpiresIn: number;
  sessionSecret: string;
  rotationEnabled: boolean;
}

export interface SecurityConfig {
  passwordMinLength: number;
  passwordRequireUppercase: boolean;
  passwordRequireNumbers: boolean;
  passwordRequireSpecialChars: boolean;
  otpExpirySeconds: number;
  otpMaxAttempts: number;
  loginThrottleWindowSeconds: number;
  loginMaxAttempts: number;
  loginLockoutDurationSeconds: number;
}

export interface StorageConfig {
  type: 's3' | 'gcs' | 'local';
  s3?: {
    region: string;
    accessKeyId: string;
    secretAccessKey: string;
    bucketName: string;
  };
  maxFileSizeMb: number;
  uploadExpiryHours: number;
  allowedFileTypes: string[];
}

export interface RealtimeConfig {
  enabled: boolean;
  provider: 'pusher' | 'socket.io';
  pusher?: {
    appId: string;
    key: string;
    secret: string;
    cluster: string;
  };
  pollingIntervalMs: number;
}

export interface JobsConfig {
  enabled: boolean;
  type: 'bull' | 'bee-queue';
  redis: string;
  concurrency: number;
  attempts: number;
  backoffDelayMs: number;
  crons: {
    checkInOpen: string;
    checkInClose: string;
    noShowScan: string;
    standingsRecalc: string;
    seasonMaintenance: string;
  };
}

export interface LoggingConfig {
  level: 'debug' | 'info' | 'warn' | 'error';
  format: 'json' | 'text';
  sentry?: {
    enabled: boolean;
    dsn: string;
  };
}

export interface MonitoringConfig {
  healthCheckEnabled: boolean;
  healthCheckIntervalMs: number;
  dbHealthCheckTimeoutMs: number;
  auditLoggingEnabled: boolean;
  auditLogRetentionDays: number;
}

export const loadEnvironmentConfig = (): EnvironmentConfig => {
  const nodeEnv = (process.env.NODE_ENV || 'development') as
    | 'development'
    | 'staging'
    | 'production';

  const baseConfig: EnvironmentConfig = {
    nodeEnv,
    port: parseInt(process.env.PORT || '3000', 10),
    apiBaseUrl: process.env.API_BASE_URL || 'http://localhost:3000',
    frontendUrl: process.env.FRONTEND_URL || 'http://localhost:3001',
    database: {
      url: process.env.DATABASE_URL || '',
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432', 10),
      name: process.env.DB_NAME || 'nexgen_mvp_local',
      user: process.env.DB_USER || 'nexgen_user',
      password: process.env.DB_PASSWORD || 'password',
      pool: {
        min: parseInt(process.env.DB_POOL_MIN || '2', 10),
        max: parseInt(process.env.DB_POOL_MAX || '10', 10),
      },
      timeout: parseInt(process.env.DB_CONNECTION_TIMEOUT || '5000', 10),
      idleTimeout: parseInt(process.env.DB_IDLE_TIMEOUT || '30000', 10),
    },
    jwt: {
      secret: process.env.JWT_SECRET || 'default-secret-change-in-production',
      accessTokenExpiresIn: parseInt(
        process.env.JWT_ACCESS_TOKEN_EXPIRES_IN || '900',
        10
      ),
      refreshTokenExpiresIn: parseInt(
        process.env.JWT_REFRESH_TOKEN_EXPIRES_IN || '2592000',
        10
      ),
      sessionSecret: process.env.SESSION_SECRET || 'session-secret-change-in-production',
      rotationEnabled: process.env.REFRESH_TOKEN_ROTATION_ENABLED !== 'false',
    },
    security: {
      passwordMinLength: parseInt(process.env.PASSWORD_MIN_LENGTH || '8', 10),
      passwordRequireUppercase: process.env.PASSWORD_REQUIRE_UPPERCASE !== 'false',
      passwordRequireNumbers: process.env.PASSWORD_REQUIRE_NUMBERS !== 'false',
      passwordRequireSpecialChars: process.env.PASSWORD_REQUIRE_SPECIAL_CHARS !== 'false',
      otpExpirySeconds: parseInt(process.env.OTP_EXPIRY_SECONDS || '300', 10),
      otpMaxAttempts: parseInt(process.env.OTP_MAX_ATTEMPTS || '5', 10),
      loginThrottleWindowSeconds: parseInt(
        process.env.LOGIN_THROTTLE_WINDOW_SECONDS || '900',
        10
      ),
      loginMaxAttempts: parseInt(process.env.LOGIN_MAX_ATTEMPTS || '5', 10),
      loginLockoutDurationSeconds: parseInt(
        process.env.LOGIN_LOCKOUT_DURATION_SECONDS || '900',
        10
      ),
    },
    storage: {
      type: (process.env.STORAGE_TYPE || 's3') as 's3' | 'gcs' | 'local',
      s3: {
        region: process.env.S3_REGION || 'us-east-1',
        accessKeyId: process.env.S3_ACCESS_KEY_ID || '',
        secretAccessKey: process.env.S3_SECRET_ACCESS_KEY || '',
        bucketName: process.env.S3_BUCKET_NAME || 'nexgen-mvp-uploads',
      },
      maxFileSizeMb: parseInt(process.env.MAX_FILE_SIZE_MB || '50', 10),
      uploadExpiryHours: parseInt(process.env.S3_UPLOAD_EXPIRY_HOURS || '24', 10),
      allowedFileTypes: (process.env.ALLOWED_FILE_TYPES || 'image/jpeg,image/png,video/mp4')
        .split(','),
    },
    realtime: {
      enabled: process.env.PUSHER_ENABLED !== 'false',
      provider: 'pusher',
      pusher: {
        appId: process.env.PUSHER_APP_ID || '',
        key: process.env.PUSHER_KEY || '',
        secret: process.env.PUSHER_SECRET || '',
        cluster: process.env.PUSHER_CLUSTER || 'mt1',
      },
      pollingIntervalMs: parseInt(
        process.env.REALTIME_FALLBACK_POLLING_INTERVAL_MS || '15000',
        10
      ),
    },
    jobs: {
      enabled: process.env.JOB_QUEUE_ENABLED !== 'false',
      type: 'bull',
      redis: process.env.REDIS_URL || 'redis://localhost:6379',
      concurrency: parseInt(process.env.JOB_QUEUE_CONCURRENCY || '5', 10),
      attempts: parseInt(process.env.JOB_ATTEMPTS || '3', 10),
      backoffDelayMs: parseInt(process.env.JOB_BACKOFF_DELAY_MS || '5000', 10),
      crons: {
        checkInOpen: process.env.CHECK_IN_OPEN_CRON || '0 0 * * *',
        checkInClose: process.env.CHECK_IN_CLOSE_CRON || '30 23 * * *',
        noShowScan: process.env.NO_SHOW_SCAN_CRON || '0 1 * * *',
        standingsRecalc: process.env.STANDINGS_RECALC_CRON || '0 2 * * *',
        seasonMaintenance: process.env.SEASON_MAINTENANCE_CRON || '0 3 * * *',
      },
    },
    logging: {
      level: (process.env.LOG_LEVEL || 'debug') as 'debug' | 'info' | 'warn' | 'error',
      format: (process.env.LOG_FORMAT || 'json') as 'json' | 'text',
      sentry: {
        enabled: process.env.SENTRY_ENABLED === 'true',
        dsn: process.env.SENTRY_DSN || '',
      },
    },
    monitoring: {
      healthCheckEnabled: process.env.HEALTH_CHECK_ENABLED !== 'false',
      healthCheckIntervalMs: parseInt(
        process.env.HEALTH_CHECK_INTERVAL_MS || '30000',
        10
      ),
      dbHealthCheckTimeoutMs: parseInt(
        process.env.DB_HEALTH_CHECK_TIMEOUT_MS || '5000',
        10
      ),
      auditLoggingEnabled: process.env.AUDIT_LOGGING_ENABLED !== 'false',
      auditLogRetentionDays: parseInt(
        process.env.AUDIT_LOG_RETENTION_DAYS || '365',
        10
      ),
    },
  };

  // Validate required environment variables
  validateEnvironmentConfig(baseConfig);

  return baseConfig;
};

const validateEnvironmentConfig = (config: EnvironmentConfig): void => {
  const errors: string[] = [];

  if (!config.database.url && !config.database.host) {
    errors.push('DATABASE_URL or DB_HOST is required');
  }

  if (!config.jwt.secret || config.jwt.secret.includes('change_in_production')) {
    if (config.nodeEnv === 'production') {
      errors.push('JWT_SECRET must be set and secure in production');
    }
  }

  if (config.storage.type === 's3' && !config.storage.s3?.accessKeyId) {
    if (config.nodeEnv === 'production') {
      errors.push('S3 credentials are required in production');
    }
  }

  if (errors.length > 0) {
    throw new Error(`Environment configuration errors:\n${errors.join('\n')}`);
  }
};
