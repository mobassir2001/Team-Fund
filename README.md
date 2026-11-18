# Team Fund (free Supabase database)

Files:
- `index.html` — the whole app (team page at `/`, admin page at `/admin`)
- `_redirects` — tells Netlify to serve the app at `/admin` too
- `setup.sql` — one-time database setup

## Setup (about 10 minutes, all free)
1. Sign up at https://supabase.com, then create a **New project** (free plan).
2. Open `setup.sql`, replace `YOUR_EMAIL_HERE` with your email, and copy everything.
   Supabase → **SQL Editor** → New query → paste → **Run**.
3. Supabase → **Authentication → Users → Add user → Create new user**:
   the same email + a password, tick **Auto Confirm User**.
4. Supabase → **Project Settings → API**: copy the **Project URL** and the **anon public** key.
   In `index.html`, find `PASTE_YOUR_PROJECT_URL` and `PASTE_YOUR_ANON_PUBLIC_KEY` and paste them in.
5. Go to https://app.netlify.com/drop and drag the folder containing `index.html`.
   You get a public link, for example `https://xyz.netlify.app`.

## Links
- Team page: `https://<your-site>.netlify.app`
- Admin page: `https://<your-site>.netlify.app/admin` (log in with the email/password from step 3)

## Optional
- Supabase → Authentication → Sign In / Providers: turn off **Allow new users to sign up**.
  (Not required: only emails listed in the `admins` table can manage the collection.)
- Free Supabase projects pause after 7 days with no activity; open the dashboard and click **Restore** if that happens.
