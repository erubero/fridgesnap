// Mock services, ported from the Swift Mock*Service classes. They keep the
// app fully usable with no backend: fixture data, realistic delays, and the
// same regeneration limit so the rate-limit UI is exercised too.
import { ScanResponse, Recipe, ServiceError } from "../core/types";
import { mockScanResponse, mockGenerateResponse } from "../core/mockData";
import {
  AuthServicing,
  AuthUser,
  ScanServicing,
  GenerationServicing,
  ProfileServicing,
  AnalyticsServicing,
  CompressedImage,
} from "./interfaces";

// Realistic delays in the app, but instant under jest so the rate-limit test
// does not run through seven real 1.5s waits.
const delay = (seconds: number) =>
  process.env.JEST_WORKER_ID
    ? Promise.resolve()
    : new Promise((resolve) => setTimeout(resolve, seconds * 1000));

let counter = 0;
const mockUuid = () =>
  `mock-${(counter++).toString(16).padStart(8, "0")}-0000-0000-0000-000000000000`;

export class MockAuthService implements AuthServicing {
  private user: AuthUser | null = { id: "mock-user", email: "chef@example.com" };
  async currentUser() {
    return this.user;
  }
  async signInWithApple() {
    this.user = { id: "mock-user", email: "chef@example.com" };
  }
  async signInWithGoogle() {
    this.user = { id: "mock-user", email: "chef@example.com" };
  }
  async signOut() {
    this.user = null;
  }
}

export class MockScanService implements ScanServicing {
  async scan(_images: CompressedImage[]): Promise<ScanResponse> {
    await delay(1.2);
    return structuredClone(mockScanResponse);
  }
}

export class MockGenerationService implements GenerationServicing {
  private generationsPerScan = new Map<string, number>();

  async generate({
    scanId,
    level,
  }: {
    scanId: string;
    level: Recipe["level"];
  }): Promise<Recipe[]> {
    // Mirror the backend limit (1 initial + 5 regenerations) so the
    // rate-limit UI is exercised in the app too.
    const used = this.generationsPerScan.get(scanId) ?? 0;
    if (used >= 6) {
      throw new ServiceError(
        "rate_limited",
        "Regeneration limit reached for this scan.",
      );
    }
    this.generationsPerScan.set(scanId, used + 1);

    await delay(1.5);
    return structuredClone(mockGenerateResponse).recipes.map((r) => ({
      ...r,
      level,
      id: mockUuid(),
    }));
  }
}

export class MockProfileService implements ProfileServicing {
  async updatePreferences() {
    await delay(0.3);
  }
}

export class MockAnalyticsService implements AnalyticsServicing {
  log(name: string, props?: Record<string, unknown>) {
    if (__DEV__) console.log(`[analytics] ${name}`, props ?? {});
  }
}
