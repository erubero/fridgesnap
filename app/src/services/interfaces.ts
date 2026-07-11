// Service protocols, ported from the Swift *Servicing protocols. Every remote
// dependency sits behind an interface with a mock, so the app always runs end
// to end with no secrets (AppServices picks real vs mock). Real Supabase-backed
// implementations arrive in the backend-wiring phase.
import {
  ScanResponse,
  Recipe,
  LazinessLevel,
  GenerateRequestIngredient,
} from "../core/types";

// One captured, already-compressed photo ready for upload. In RN this is the
// file uri from expo-image-manipulator; the mock ignores the contents.
export interface CompressedImage {
  uri: string;
  width: number;
  height: number;
}

export interface AuthUser {
  id: string;
  email?: string;
}

export interface AuthServicing {
  currentUser(): Promise<AuthUser | null>;
  signInWithApple(identityToken: string, rawNonce: string): Promise<void>;
  signInWithGoogle(idToken: string): Promise<void>;
  signOut(): Promise<void>;
}

export interface ScanServicing {
  scan(images: CompressedImage[]): Promise<ScanResponse>;
}

export interface GenerationServicing {
  generate(args: {
    scanId: string;
    ingredients: GenerateRequestIngredient[];
    level: LazinessLevel;
    servings: number;
  }): Promise<Recipe[]>;
}

export interface ProfileServicing {
  updatePreferences(args: {
    dietaryPrefs: string[];
    allergies: string;
    staples: boolean;
  }): Promise<void>;
}

export interface AnalyticsServicing {
  log(name: string, props?: Record<string, unknown>): void;
}

export interface AppServices {
  auth: AuthServicing;
  scan: ScanServicing;
  generation: GenerationServicing;
  profile: ProfileServicing;
  analytics: AnalyticsServicing;
  isUsingMocks: boolean;
}
