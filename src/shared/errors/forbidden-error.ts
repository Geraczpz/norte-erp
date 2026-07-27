import { ApplicationError } from './application-error';

export class ForbiddenError extends ApplicationError {
  public readonly code = 'FORBIDDEN';
  public readonly statusCode = 403;

  public constructor(
    message = 'No tienes permiso para realizar esta acción.',
    options?: ErrorOptions,
  ) {
    super(message, options);
  }
}
