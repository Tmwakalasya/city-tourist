import { createHandler } from './adapter.mjs';

const supabaseURL = Deno.env.get('SUPABASE_URL');
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
Deno.serve(createHandler({
  token: Deno.env.get('EVENTBRITE_TOKEN'),
  organizations: (Deno.env.get('EVENTBRITE_ORGANIZATION_IDS') ?? '').split(',').map(s => s.trim()).filter(Boolean),
  allowRequest: async () => {
    if (!supabaseURL || !serviceKey) return false;
    const response = await fetch(`${supabaseURL}/rest/v1/rpc/spend_event_proxy_budget`, {
      method: 'POST', headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json' },
      body: '{}', signal: AbortSignal.timeout(3000),
    });
    return response.ok && await response.json() === true;
  },
}));
