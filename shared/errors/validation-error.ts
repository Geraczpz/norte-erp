import { ApplicationError } from './application-error';

export class ValidationError extends ApplicationError {
  public readonly code = 'VALIDATION_ERROR';
  public readonly statusCode = 400;

  public constructor(message: string, options?: ErrorOptions) {
    super(message, options);
  }
}
