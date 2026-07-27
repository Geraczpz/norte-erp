export interface LoginCredentials {
  employeeNumber: string;
  password: string;
}

export interface AuthenticatedEmployee {
  id: string;
  authUserId: string;
  employeeNumber: string;
  firstName: string;
  middleName: string | null;
  paternalLastName: string | null;
  maternalLastName: string;
  institutionalEmail: string;
  mustChangePassword: boolean;
}

export interface AuthenticatedSystem {
  id: string;
  code: string;
  name: string;
}

export interface AuthenticatedRole {
  id: string;
  code: string;
  name: string;
  systemId: string;
}

export interface AuthenticatedPermission {
  id: string;
  code: string;
  resource: string;
  action: string;
  systemId: string;
}

export interface AuthenticationContext {
  employee: AuthenticatedEmployee;
  systems: AuthenticatedSystem[];
  roles: AuthenticatedRole[];
  permissions: AuthenticatedPermission[];
}

export interface AuthenticationTokens {
  accessToken: string;
  refreshToken: string;
  expiresAt: number | null;
}

export interface AuthenticationResult {
  context: AuthenticationContext;
  tokens: AuthenticationTokens;
}

export interface AuthenticatedSession {
  context: AuthenticationContext;
  expiresAt: number | null;
}