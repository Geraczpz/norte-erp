export const AUTH_COOKIE_NAMES = {
  accessToken: 'norte-erp-access-token',
  refreshToken: 'norte-erp-refresh-token',
} as const;

export const AUTH_ERROR_CODES = {
  invalidCredentials: 'INVALID_CREDENTIALS',
  inactiveEmployee: 'INACTIVE_EMPLOYEE',
  employeeNotFound: 'EMPLOYEE_NOT_FOUND',
  identityNotFound: 'IDENTITY_NOT_FOUND',
  unauthorized: 'UNAUTHORIZED',
  forbidden: 'FORBIDDEN',
  sessionExpired: 'SESSION_EXPIRED',
  authenticationFailed: 'AUTHENTICATION_FAILED',
} as const;

export const NORTE_ERP_SYSTEM_CODE = 'NORTE_ERP';

export type AuthErrorCode =
  (typeof AUTH_ERROR_CODES)[keyof typeof AUTH_ERROR_CODES];