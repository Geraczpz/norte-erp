import { ApplicationError } from './application-error';

export class NotFoundError extends ApplicationError {
  public readonly code = 'NOT_FOUND';
  public readonly statusCode = 404;

  public constructor(message: string, options?: ErrorOptions) {
    super(message, options);
  }
}
