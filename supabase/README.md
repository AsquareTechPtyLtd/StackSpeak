# Supabase — cross-platform progress sync

Backend for the Pro-gated cross-platform sync (iPhone ↔ iPad ↔ Android). The app
talks to Supabase over its **REST API via `URLSession`** — no SDK, no SPM
dependency (see `CLAUDE.md` → "Backend & Sync"). Everything goes behind the
`BackendService` protocol; `SupabaseBackendService` is the only conformer that
knows it's Supabase.

## One-time setup

1. **Create a free project** at supabase.com.
2. **Apply the schema:** dashboard → SQL Editor → paste `migrations/0001_init_progress.sql` → Run. (Or `supabase db push` if using the CLI.)
3. **Enable anonymous sign-in:** Auth → Providers → enable "Allow anonymous sign-ins".
4. **Configure the client:** copy `ios/StackSpeak/Resources/Supabase.example.plist` → `Supabase.plist` (same folder), fill in:
   - `SUPABASE_URL` — Project URL (Settings → API)
   - `SUPABASE_ANON_KEY` — the **anon / publishable** key (Settings → API)

   Then `cd ios && xcodegen generate`. `Supabase.plist` is git-ignored.

If `Supabase.plist` is absent, the app runs local-only (`NoOpBackendService`) — no sync, no crash.

## Security

- The **anon key** ships in the client; it's safe **only because** Row Level
  Security (in the migration) restricts every user to their own row.
- The **service_role key** and **database password** must never be in the app,
  this repo, or any commit.

## Data model

One row per user in `public.progress`:

| column | type | meaning |
|---|---|---|
| `user_id` | uuid (PK → `auth.users`) | the signed-in (anonymous) user |
| `data` | jsonb | the platform-neutral `ProgressSnapshot` |
| `schema_version` | int | bump when the snapshot shape changes |
| `updated_at` | timestamptz | last write (sync/merge decisions) |

The `data` blob is the **cross-platform contract** — iOS and Android serialize
the identical `ProgressSnapshot` shape so progress is portable between platforms.
