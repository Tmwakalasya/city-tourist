-- Additive migration. Run in the Supabase SQL editor before deploying the adapter.
-- Auth users/phone identities are managed by Supabase Auth; no application OTP table.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 1000000, array['image/jpeg'])
on conflict (id) do nothing;

create policy "avatar owner reads" on storage.objects for select to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "avatar owner creates" on storage.objects for insert to authenticated
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text and storage.filename(name) = 'avatar.jpg');
create policy "avatar owner updates" on storage.objects for update to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text and storage.filename(name) = 'avatar.jpg');
create policy "avatar owner deletes" on storage.objects for delete to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Shared global allowance bounds paid upstream traffic across edge instances.
-- Only the server's service role can spend it; no raw IPs or phone numbers are stored.
create table if not exists public.event_proxy_budget (
    bucket text primary key,
    window_start timestamptz not null,
    requests integer not null check (requests >= 0)
);
alter table public.event_proxy_budget enable row level security;
revoke all on public.event_proxy_budget from anon, authenticated;
create or replace function public.spend_event_proxy_budget() returns boolean
language plpgsql security definer set search_path = '' as $$
declare used integer;
begin
    insert into public.event_proxy_budget as budget (bucket, window_start, requests)
    values ('eventbrite', date_trunc('minute', now()), 1)
    on conflict (bucket) do update set
        requests = case when budget.window_start < date_trunc('minute', now()) then 1 else budget.requests + 1 end,
        window_start = date_trunc('minute', now())
    returning requests into used;
    return used <= 60;
end;
$$;
revoke all on function public.spend_event_proxy_budget() from public, anon, authenticated;
grant execute on function public.spend_event_proxy_budget() to service_role;
