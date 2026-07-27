import { NextResponse } from 'next/server';

interface SuccessResponse<T> {
  success: true;
  data: T;
}

interface ErrorResponse {
  success: false;
  error: {
    code: string;
    message: string;
  };
}

export function successResponse<T>(data: T, status = 200): NextResponse<SuccessResponse<T>> {
  return NextResponse.json(
    {
      success: true,
      data,
    },
    {
      status,
    },
  );
}

export function errorResponse(
  code: string,
  message: string,
  status: number,
): NextResponse<ErrorResponse> {
  return NextResponse.json(
    {
      success: false,
      error: {
        code,
        message,
      },
    },
    {
      status,
    },
  );
}
