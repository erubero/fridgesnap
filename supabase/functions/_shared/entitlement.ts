// Server-side entitlement checks. The subscriptions row is written only by
// the rc-sync function after verifying against the RevenueCat REST API (M4);
// client claims are never trusted. The lifetime scan count is the free-tier
// gate: scan rows are never deleted, so it survives app reinstalls.
import type { SupabaseClient } from 'npm:@supabase/supabase-js@2';

export const FREE_SCAN_LIMIT = 3;

export async function hasActiveSubscription(
  admin: SupabaseClient,
  userId: string,
): Promise<boolean> {
  const { data, error } = await admin
    .from('subscriptions')
    .select('is_active, expires_at')
    .eq('user_id', userId)
    .maybeSingle();
  if (error || !data || !data.is_active) return false;
  if (data.expires_at && new Date(data.expires_at) < new Date()) return false;
  return true;
}

export async function lifetimeScanCount(
  admin: SupabaseClient,
  userId: string,
): Promise<number> {
  const { count, error } = await admin
    .from('scans')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId);
  if (error) throw new Error(`scan count failed: ${error.message}`);
  return count ?? 0;
}
