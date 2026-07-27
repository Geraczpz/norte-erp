import {
  AUTH_ERROR_CODES,
  type AuthErrorCode,
} from './auth.constants';

export class AuthenticationError extends Error {
  public readonly code: AuthErrorCode;
  public readonly statusCode: number;

  public constructor(
    message: string,
    code: AuthErrorCode = AUTH_ERROR_CODES.authenticationFailed,
    statusCode = 401,
  ) {
    super(message);

    this.name = 'AuthenticationError';
    this.code = code;
    this.statusCode = statusCode;
  }
}

export class InvalidCredentialsError extends AuthenticationError {
  public constructor() {
    super(
      'La matrícula o contraseña son incorrectas.',
      AUTH_ERROR_CODES.invalidCredentials,
      401,
    );

    this.name = 'InvalidCredentialsError';
  }
}

export class UnauthorizedError extends AuthenticationError {
  public constructor(message = 'La sesión no es válida.') {
    super(message, AUTH_ERROR_CODES.unauthorized, 401);

    this.name = 'UnauthorizedError';
  }
}

export class ForbiddenError extends AuthenticationError {
  public constructor(message = 'No tienes permiso para realizar esta acción.') {
    super(message, AUTH_ERROR_CODES.forbidden, 403);

    this.name = 'ForbiddenError';
  }
}

export class InactiveEmployeeError extends AuthenticationError {
  public constructor() {
    super(
      'El empleado se encuentra inactivo.',
      AUTH_ERROR_CODES.inactiveEmployee,
      403,
    );

    this.name = 'InactiveEmployeeError';
  }
}