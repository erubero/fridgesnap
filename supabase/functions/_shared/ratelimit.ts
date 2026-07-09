// Per-user rate limiting backed by the rate_limits table (service role only).
// Pattern from MyPursefolio's identifyPurseImage: fails open if the limiter
// itself errors, so an outage never blocks paying users.
import type { SupabaseClient } from 'npm:@supabase/supabase-js@2';

export async function checkAndRecord(
  admin: SupabaseClient,
  userId: string,
  action: string,
  limit: number,
  windowMs: number,
): Promise<{ allowed: boolean }> {
  try {
    const windowStart = new Date(Math.floor(Date.now() / windowMs) * windowMs).toISOString();

    const { data: existing, error: readError } = await admin
      .from('rate_limits')
      .select('count')
      .eq('user_id', userId)
      .eq('action', action)
      .eq('window_start', windowStart)
      .maybeSingle();
    if (readError) return { allowed: true };

    const count = existing?.count ?? 0;
    if (count >= limit) return { allowed: false };

    const { error: writeError } = await admin
      .from('rate_limits')
      .upsert(
        { user_id: userId, action, window_start: windowStart, count: count + 1 },
        { onConflict: 'user_id,action,window_start' },
      );
    if (writeError) return { allowed: true };

    return { allowed: true };
  } catch (_err) {
    return { allowed: true };
  }
}
