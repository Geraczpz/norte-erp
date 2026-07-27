import { ApplicationError } from './application-error';

export class UnauthorizedError extends ApplicationError {
  public readonly code = 'UNAUTHORIZED';
  public readonly statusCode = 401;

  public constructor(message = 'No autenticado.', options?: ErrorOptions) {
    super(message, options);
  }
}
