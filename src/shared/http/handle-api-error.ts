import { ApplicationError } from '@/shared/errors';

import { errorResponse } from './api-response';

export function handleApiError(error: unknown) {
  if (error instanceof ApplicationError) {
    return errorResponse(error.code, error.message, error.statusCode);
  }

  console.error(error);

  return errorResponse('INTERNAL_SERVER_ERROR', 'Ocurrió un error interno en el servidor.', 500);
}
