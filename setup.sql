-- Team Fund: one-time database setup for Supabase (free plan)
-- 1) Replace YOUR_EMAIL_HERE below with the organiser's login email.
-- 2) Supabase → SQL Editor → New query → paste all of this → Run.
-- Safe to run again.

-- All data (settings, people, activity) lives in one table.
create table if not exists public.items (
  col        text not null,              -- 'config' | 'people' | 'activity'
  id         text not null,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (col, id)
);
alter table public.items replica identity full;

-- Organisers (only these emails can manage the collection)
create table if not exists public.admins (email text primary key);
insert into public.admins(email) values (lower('YOUR_EMAIL_HERE')) on conflict do nothing;
alter table public.admins enable row level security;   -- no policies: nobody can read it from the page

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins
                 where lower(email) = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;

-- Everyone can read the list; only organisers can change it.
alter table public.items enable row level security;
drop policy if exists "items read"   on public.items;
drop policy if exists "items insert" on public.items;
drop policy if exists "items update" on public.items;
drop policy if exists "items delete" on public.items;
create policy "items read"   on public.items for select using (true);
create policy "items insert" on public.items for insert with check (public.is_admin());
create policy "items update" on public.items for update using (public.is_admin()) with check (public.is_admin());
create policy "items delete" on public.items for delete using (public.is_admin());

-- Team members mark their own payment only through this function
-- (they cannot change names, amounts or anything else).
create or replace function public.self_pay(pid text, amt integer) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  cur jsonb; due int; paid int; total int; nm text; nxt jsonb;
  now_ms bigint := (extract(epoch from now()) * 1000)::bigint;
begin
  if amt is null or amt <= 0 or amt > 1000000 then raise exception 'Invalid amount'; end if;
  select data into cur from items where col = 'people' and id = pid for update;
  if cur is null then raise exception 'Person not found'; end if;
  due  := coalesce((cur ->> 'due')::numeric, 0)::int;
  paid := coalesce((cur ->> 'paid')::numeric, 0)::int;
  if due > 0 and paid >= due then return cur; end if;      -- already fully paid
  total := paid + amt;
  nm := coalesce(cur ->> 'name', 'Someone');
  nxt := cur || jsonb_build_object('paid', total, 'claimed', false, 'paidAt', now_ms,
                                   'selfMarked', true, 'verified', false);
  update items set data = nxt, updated_at = now() where col = 'people' and id = pid;
  insert into items(col, id, data) values ('activity', gen_random_uuid()::text,
    jsonb_build_object('kind', 'paid', 'at', now_ms, 'text',
      nm || ' paid ₹' || to_char(amt, 'FM99,99,99,999') ||
      case when total >= due then ' · fully paid'
           else ' · ₹' || to_char(due - total, 'FM99,99,99,999') || ' left' end));
  return nxt;
end $$;

revoke all on function public.self_pay(text, integer) from public;
grant execute on function public.self_pay(text, integer) to anon, authenticated;
grant execute on function public.is_admin() to anon, authenticated;

-- Live updates
do $$ begin
  alter publication supabase_realtime add table public.items;
exception when duplicate_object then null; end $$;

-- QR code image storage (public to view, only organisers upload)
insert into storage.buckets (id, name, public) values ('qr', 'qr', true) on conflict (id) do nothing;
drop policy if exists "qr read"   on storage.objects;
drop policy if exists "qr upload" on storage.objects;
drop policy if exists "qr update" on storage.objects;
create policy "qr read"   on storage.objects for select using (bucket_id = 'qr');
create policy "qr upload" on storage.objects for insert with check (bucket_id = 'qr' and public.is_admin());
create policy "qr update" on storage.objects for update using (bucket_id = 'qr' and public.is_admin());
