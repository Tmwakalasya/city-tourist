import assert from 'node:assert/strict';
import { createHandler, normalize, distance } from './adapter.mjs';
export async function runTests() {
  const passed = [];
  const check = async (name, fn) => { await fn(); passed.push(name); };
  const event = { id: '123', name: { text: 'City Fair' }, listed: true, status: 'live', organization_id: '42',
    start: { local: '2026-11-08T10:30:00' }, venue: { name: 'Hall', latitude: '38.7', longitude: '-9.1' },
    url: 'https://www.eventbrite.com/e/123', logo: { url: 'javascript:alert(1)' } };
  const request = (extra = '') => new Request(`https://adapter.test/?latitude=38.7&longitude=-9.1&radiusMeters=25000&start=2026-11-08T00:00:00Z&end=2026-11-09T00:00:00Z${extra}`);
  const handler = (options = {}) => createHandler({ token: 'test-token', organizations: ['42'], allowRequest: async () => true,
    fetcher: async () => new Response(JSON.stringify({ events: [event], pagination: { page_count: 2 } })), ...options });
  await check('Only authorized public live events are exposed', () => {
    assert.equal(normalize({ ...event, listed: false }, ['42']), null);
    assert.equal(normalize({ ...event, organization_id: '99' }, ['42']), null);
    assert.equal(normalize({ ...event, status: 'canceled' }, ['42']), null);
    assert.equal(normalize({ ...event, online_event: true }, ['42']), null);
  });
  await check('Invalid time, location and unsafe image URLs are rejected', () => {
    assert.equal(normalize(event, ['42']).imageURL, null);
    assert.equal(normalize({ ...event, venue: { latitude: null, longitude: null } }, ['42']), null);
    assert.equal(normalize({ ...event, start: { local: '2026-02-30T10:00:00' } }, ['42']), null);
    assert.equal(normalize({ ...event, start: { local: '2026-11-08T24:00:00' } }, ['42']), null);
  });
  await check('Search validates before sending upstream requests', async () => {
    let called = false;
    const response = await handler({ fetcher: async () => { called = true; throw Error(); } })(new Request('https://adapter.test/?latitude=NaN'));
    assert.equal(response.status, 400); assert.equal(called, false);
  });
  await check('Pagination and normalized schema survive filtering', async () => {
    const response = await handler()(request()); const result = await response.json();
    assert.equal(result.nextCursor, '0:2'); assert.equal(result.events[0].startMinute, 630);
    assert.equal(result.events[0].id, '123');
    assert.equal((await (await handler()(request('&cursor=0:2'))).json()).nextCursor, null);
  });
  await check('Radius filters distant events', async () => {
    assert.equal((await (await handler()(new Request(request().url.replace('latitude=38.7', 'latitude=50')))).json()).events.length, 0);
    assert.equal(distance({ latitude: 0, longitude: 0 }, { latitude: 0, longitude: 0 }), 0);
  });
  await check('Shared rate limit fails closed without an upstream call', async () => {
    const response = await handler({ allowRequest: async () => false, fetcher: async () => { throw Error('unexpected'); } })(request());
    assert.equal(response.status, 429); assert.equal(response.headers.get('Retry-After'), '60');
  });
  await check('Upstream errors and timeouts become safe responses', async () => {
    assert.equal((await handler({ fetcher: async () => new Response('private provider detail', { status: 429 }) })(request())).status, 429);
    const failed = await handler({ fetcher: async () => { throw Error('secret'); } })(request());
    assert.equal(failed.status, 503); assert.equal((await failed.text()).includes('secret'), false);
  });
  await check('Detail lookup rejects foreign organizations', async () => {
    const response = await handler({ fetcher: async () => new Response(JSON.stringify({ ...event, organization_id: '99' })) })(new Request('https://adapter.test/?id=123'));
    assert.equal(JSON.stringify((await response.json()).events), '[]');
  });
  await check('Invalid and out of range cursors cannot redirect the upstream URL', async () => {
    assert.equal((await handler()(request('&cursor=https://evil.test'))).status, 400);
    assert.equal((await handler()(request('&cursor=2:1'))).status, 400);
  });
  return passed;
}
