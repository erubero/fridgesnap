// Hourly cron: delete scan photos past their 24h expiry, keeping only the
// ingredient JSON. This is what makes the App Store privacy label statement
// ("photos are deleted after processing") true. Deploy with --no-verify-jwt;
// guarded by CRON_SECRET instead (Warraya send-expiry-push pattern).
import { createClient } from 'npm:@supabase/supabase-js@2';

const BATCH_SIZE = 200;

// Constant-time compare so a mistimed response can't leak how many leading
// bytes of CRON_SECRET a guess got right.
function timingSafeEqualStrings(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const aBytes = enc.encode(a);
  const bBytes = enc.encode(b);
  if (aBytes.length !== bBytes.length) return false;
  let diff = 0;
  for (let i = 0; i < aBytes.length; i++) diff |= aBytes[i] ^ bBytes[i];
  return diff === 0;
}

Deno.serve(async (req) => {
  const cronSecret = Deno.env.get('CRON_SECRET') ?? '';
  const provided = req.headers.get('Authorization') ?? '';
  if (cronSecret === '' || !timingSafeEqualStrings(provided, `Bearer ${cronSecret}`)) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: expired, error: queryError } = await admin
      .from('scans')
      .select('id, image_paths')
      .lt('expires_at', new Date().toISOString())
      .eq('images_deleted', false)
      .limit(BATCH_SIZE);
    if (queryError) {
      return Response.json({ error: queryError.message }, { status: 500 });
    }

    let scansCleaned = 0;
    let filesDeleted = 0;
    for (const scan of expired ?? []) {
      const paths = (scan.image_paths ?? []) as string[];
      if (paths.length > 0) {
        const { error: removeError } = await admin.storage.from('scan-images').remove(paths);
        if (removeError) continue; // retry this scan on the next run
        filesDeleted += paths.length;
      }
      const { error: updateError } = await admin
        .from('scans')
        .update({ images_deleted: true, image_paths: [] })
        .eq('id', scan.id);
      if (!updateError) scansCleaned += 1;
    }

    return Response.json({ success: true, scans_cleaned: scansCleaned, files_deleted: filesDeleted });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return Response.json({ error: message }, { status: 500 });
  }
});
