// No Eventbrite bearer token is sent to the app. Only explicitly authorized, public events leave this adapter.
const json = (value, status = 200, extra = {}) => new Response(JSON.stringify(value), {
  status, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', ...extra },
});
const https = value => {
  try { const url = new URL(value); return url.protocol === 'https:' ? url.href : null; } catch { return null; }
};
export function normalize(event, organizations) {
  if (!event || event.listed !== true || event.status !== 'live' || event.online_event === true ||
      !organizations.includes(String(event.organization_id)) || !/^\d+$/.test(String(event.id)) ||
      typeof event.name?.text !== 'string' || !event.name.text.trim()) return null;
  const local = event.start?.local;
  const parts = typeof local === 'string' && /^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):\d{2}$/.exec(local);
  if (!parts || !Number.isFinite(Date.parse(`${local}Z`)) || Number(parts[2]) > 23 || Number(parts[3]) > 59) return null;
  if (new Date(`${local}Z`).toISOString().slice(0, 10) !== parts[1]) return null;
  const lat = event.venue?.latitude, lon = event.venue?.longitude;
  if (lat == null || lon == null || lat === '' || lon === '') return null;
  const latitude = Number(lat), longitude = Number(lon);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return null;
  return { id: String(event.id), name: event.name.text.slice(0, 300), localDate: parts[1],
    startMinute: Number(parts[2]) * 60 + Number(parts[3]), venue: String(event.venue?.name ?? '').slice(0, 300),
    latitude, longitude, ticketURL: https(event.url), imageURL: https(event.logo?.url) };
}
export function distance(a, b) {
  const rad = x => x * Math.PI / 180;
  const dLat = rad(b.latitude - a.latitude), dLon = rad(b.longitude - a.longitude);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.sin(dLon / 2) ** 2;
  return 6371000 * 2 * Math.asin(Math.sqrt(Math.min(1, Math.max(0, h))));
}
export function createHandler({ token, organizations, allowRequest, fetcher = fetch }) {
  return async request => {
    if (request.method !== 'GET') return json({ error: 'Method not allowed' }, 405);
    if (!token || !organizations.length || !organizations.every(id => /^\d+$/.test(id))) return json({ error: 'Provider not configured' }, 503);
    try {
      const params = new URL(request.url).searchParams;
      const id = params.get('id');
      let index = 0, page = 1, center, radius, start, end;
      if (id !== null) {
        if (!/^\d{1,30}$/.test(id)) return json({ error: 'Invalid event ID' }, 400);
      } else {
        const required = ['latitude', 'longitude', 'radiusMeters', 'start', 'end'];
        if (required.some(key => !params.get(key))) return json({ error: 'Missing search parameters' }, 400);
        center = { latitude: Number(params.get('latitude')), longitude: Number(params.get('longitude')) };
        radius = Number(params.get('radiusMeters'));
        start = Date.parse(params.get('start')); end = Date.parse(params.get('end'));
        if (![center.latitude, center.longitude, radius, start, end].every(Number.isFinite) ||
            Math.abs(center.latitude) > 90 || Math.abs(center.longitude) > 180 || radius <= 0 || radius > 100000 ||
            end < start || end - start > 366 * 86400000) return json({ error: 'Invalid search parameters' }, 400);
        const cursor = params.get('cursor');
        if (cursor) {
          if (!/^\d{1,3}:\d{1,4}$/.test(cursor)) return json({ error: 'Invalid cursor' }, 400);
          [index, page] = cursor.split(':').map(Number);
          if (index >= organizations.length || page < 1 || page > 1000) return json({ error: 'Invalid cursor' }, 400);
        }
      }
      // Fail closed if the shared quota store is unavailable.
      if (!await allowRequest()) return json({ error: 'Please try later' }, 429, { 'Retry-After': '60' });
      const url = new URL(id ? `https://www.eventbriteapi.com/v3/events/${id}/` :
        `https://www.eventbriteapi.com/v3/organizations/${organizations[index]}/events/`);
      url.searchParams.set('expand', 'venue,logo');
      if (!id) {
        url.searchParams.set('status', 'live'); url.searchParams.set('order_by', 'start_asc');
        url.searchParams.set('page_size', '50'); url.searchParams.set('page', String(page));
      }
      const response = await fetcher(url, { headers: { Authorization: `Bearer ${token}` }, signal: AbortSignal.timeout(12000) });
      if (!response.ok) return json({ error: 'Event provider unavailable' }, response.status === 429 ? 429 : 502,
        response.status === 429 ? { 'Retry-After': '60' } : {});
      const payload = await response.json();
      if (!id && !Array.isArray(payload.events)) return json({ error: 'Invalid provider response' }, 502);
      let events = (id ? [payload] : payload.events).map(e => normalize(e, organizations)).filter(Boolean);
      if (!id) events = events.filter(e => distance(center, e) <= radius &&
        Date.parse(`${e.localDate}T00:00:00Z`) >= start - 86400000 && Date.parse(`${e.localDate}T00:00:00Z`) <= end + 86400000);
      events.sort((a, b) => a.localDate.localeCompare(b.localDate) || a.startMinute - b.startMinute || a.id.localeCompare(b.id));
      const pageCount = Number(payload.pagination?.page_count ?? 1);
      const hasMore = payload.pagination?.has_more_items === true || page < pageCount;
      const nextCursor = id ? null : hasMore && page < 1000 ? `${index}:${page + 1}` :
        index + 1 < organizations.length ? `${index + 1}:1` : null;
      return json({ events, nextCursor });
    } catch (error) {
      return json({ error: error?.name === 'TimeoutError' ? 'Event provider timed out' : 'Events temporarily unavailable' }, 503);
    }
  };
}
