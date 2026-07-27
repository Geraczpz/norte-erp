import { successResponse } from '@/shared/http';

export const dynamic = 'force-dynamic';

export async function GET() {
  return successResponse({
    application: 'NORTE-ERP',
    status: 'ok',
    timestamp: new Date().toISOString(),
  });
}
