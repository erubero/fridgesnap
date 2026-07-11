// Central service container, ported from Swift AppServices. Picks real
// Supabase-backed services when configured, mocks otherwise, so the whole app
// runs with zero secrets. Real implementations are added in the backend phase;
// until then this always resolves to mocks.
import { AppServices } from "./interfaces";
import {
  MockAuthService,
  MockScanService,
  MockGenerationService,
  MockProfileService,
  MockAnalyticsService,
} from "./mocks";

// True once Supabase env vars are present (added with the real services).
export const isConfigured = (): boolean =>
  !!process.env.EXPO_PUBLIC_SUPABASE_URL &&
  !!process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

export const createAppServices = (): AppServices => {
  // if (isConfigured()) { return realServices() }  // backend-wiring phase
  return {
    auth: new MockAuthService(),
    scan: new MockScanService(),
    generation: new MockGenerationService(),
    profile: new MockProfileService(),
    analytics: new MockAnalyticsService(),
    isUsingMocks: true,
  };
};

export * from "./interfaces";
