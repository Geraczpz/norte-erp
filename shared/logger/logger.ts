import 'server-only';

import pino, { type LoggerOptions } from 'pino';

const options: LoggerOptions = {
  level: process.env.LOG_LEVEL ?? 'info',
  redact: {
    paths: [
      'password',
      '*.password',
      'token',
      '*.token',
      'access_token',
      '*.access_token',
      'refresh_token',
      '*.refresh_token',
      'authorization',
      '*.authorization',
      'SUPABASE_SERVICE_ROLE_KEY',
    ],
    censor: '[REDACTED]',
  },
};

if (process.env.NODE_ENV === 'development') {
  options.transport = {
    target: 'pino-pretty',
    options: {
      colorize: true,
      translateTime: 'SYS:standard',
      ignore: 'pid,hostname',
    },
  };
}

export const logger = pino(options);
