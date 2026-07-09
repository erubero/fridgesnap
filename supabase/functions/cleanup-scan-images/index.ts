// Hourly cron: delete scan photos past their 24h expiry, keeping only the
// ingredient JSON. This is what makes the App Store privacy label statement
// ("photos are deleted after processing") true. Deploy with --no-verify-jwt;
// guarded by CRON_SECRET instead (Warraya send-expiry-push pattern).
import { createClient } from 'npm:@supabase/supabase-js@2';

const BATCH_SIZE = 200;

Deno.serve(async (req) => {
  const cronSecret = Deno.env.get('CRON_SECRET') ?? '';
  if (req.headers.get('Authorization') !== `Bearer ${cronSecret}` || cronSecret === '') {
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
