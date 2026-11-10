// The shared-itinerary viewer. A separate file because the site's
// Content-Security-Policy only runs scripts served from here.
(function () {
  var root = document.getElementById('root');

  function state(title, message) {
    root.innerHTML =
      '<div class="state"><h1></h1><p></p></div>';
    root.querySelector('h1').textContent = title;
    root.querySelector('p').textContent = message;
  }

  // base64url -> UTF-8 string. TextDecoder keeps accents intact (Belém, São Jorge).
  function decodePayload(raw) {
    var s = raw.replace(/-/g, '+').replace(/_/g, '/');
    while (s.length % 4) s += '=';
    var bin = atob(s);
    var bytes = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return JSON.parse(new TextDecoder().decode(bytes));
  }

  function timeLabel(minutes) {
    var d = new Date();
    d.setHours(Math.floor(minutes / 60), minutes % 60, 0, 0);
    return d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
  }

  function dayLabel(iso) {
    var parts = String(iso).split('-');
    if (parts.length !== 3) return iso;
    var d = new Date(+parts[0], +parts[1] - 1, +parts[2]);
    if (isNaN(d)) return iso;
    return d.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' });
  }

  function durationLabel(m) {
    var h = Math.floor(m / 60), min = m % 60;
    if (!h) return min + ' min';
    return min ? h + ' hr ' + min + ' min' : h + ' hr';
  }

  // Deterministic hero colour, so a trip always looks the same.
  function hue(text) {
    var h = 0;
    for (var i = 0; i < text.length; i++) h = (h * 31 + text.charCodeAt(i)) % 360;
    return h;
  }

  function el(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }

  function render(data) {
    document.title = data.title + ' · City Tourist';
    root.innerHTML = '';

    var wrap = el('div', 'wrap');

    var h = hue(data.title + data.city);
    var hero = el('div', 'hero');
    hero.style.background =
      'linear-gradient(135deg,hsl(' + h + ',62%,58%),hsl(' + ((h + 40) % 360) + ',58%,38%))';
    hero.appendChild(el('span', 'badge', 'Shared itinerary'));
    hero.appendChild(el('h1', null, data.title));

    var dayCount = (data.days || []).length;
    var subtitle = data.city;
    if (dayCount) subtitle += ' · ' + dayCount + (dayCount === 1 ? ' day' : ' days');
    hero.appendChild(el('p', null, subtitle));
    wrap.appendChild(hero);

    (data.days || []).forEach(function (day, index) {
      var section = el('div', 'day');
      section.appendChild(el('div', 'day-label', 'Day ' + (index + 1)));
      section.appendChild(el('h2', null, dayLabel(day.d)));

      var stops = day.stops || [];
      if (!stops.length) {
        section.appendChild(el('div', 'empty-day', 'Nothing planned.'));
        wrap.appendChild(section);
        return;
      }

      stops.forEach(function (stop, i) {
        var row = el('div', 'stop');

        var rail = el('div', 'rail');
        rail.appendChild(el('div', 'time', timeLabel(stop.t)));
        rail.appendChild(el('div', 'dot'));
        if (i < stops.length - 1) rail.appendChild(el('div', 'line'));
        row.appendChild(rail);

        var card = el('div', 'card');
        card.appendChild(el('h3', null, stop.n));
        if (stop.b) card.appendChild(el('p', 'blurb', stop.b));
        card.appendChild(el('div', 'meta', durationLabel(stop.m)));
        if (stop.note) card.appendChild(el('div', 'note', stop.note));

        if (stop.lat != null && stop.lon != null) {
          var a = el('a', 'maps', 'Open in Maps');
          a.href = 'https://www.google.com/maps/search/?api=1&query=' + stop.lat + ',' + stop.lon;
          a.rel = 'noopener noreferrer';
          a.target = '_blank';
          card.appendChild(a);
        }
        row.appendChild(card);
        section.appendChild(row);
      });

      wrap.appendChild(section);
    });

    // Everyone a trip is shared with ends up here, so this is where they
    // find out they can plan their own. The launch page knows where the app
    // is currently available.
    var invite = el('div', 'invite');
    invite.appendChild(el('h2', null, 'Plan your own trip like this'));
    invite.appendChild(el('p', null,
      'City Tourist plans each day around what you like, checks it against opening hours and travel times, and tells you when to leave. Free on iPhone.'));
    var get = el('a', null, 'Get City Tourist');
    get.href = '/';
    invite.appendChild(get);
    wrap.appendChild(invite);

    var foot = el('footer');
    foot.appendChild(el('span', 'mark'));
    foot.appendChild(el('span', null, 'Planned with City Tourist'));
    wrap.appendChild(foot);

    root.appendChild(wrap);
  }

  function load() {
    var hash = location.hash || '';
    var match = hash.match(/[#&]i=([A-Za-z0-9\-_]+)/);
    if (!match) {
      state('Nothing to show yet',
            'This page displays an itinerary shared from the City Tourist app. Open the link you were sent — it carries the plan inside it.');
      return;
    }
    try {
      var data = decodePayload(match[1]);
      if (!data || !data.days) throw new Error('malformed');
      render(data);
    } catch (e) {
      state('This link looks broken',
            'The itinerary could not be read. It may have been shortened or cut off in transit — ask for the full link again.');
    }
  }

  window.addEventListener('hashchange', load);
  load();
})();
