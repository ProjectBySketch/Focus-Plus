# Focus Plus

A feature-rich, MIT-licensed browser for iPhone and iPad from
**ProjectBySketch™**. It grew out of Focus Lite's engine and adds its own
interface, a dedicated History page, a Flags page, a much richer start page and
an optional JIT pairing flow.

## What's in it

- **Settings that read like an index** — one header that says what the app is
  set to (look, accent, engine, version, incognito or not, JIT or not), then one
  row per subject, each opening its own page: Appearance, Start page, Command
  bar, Search, Privacy, JIT & Pairing, Personal VPN, Extensions, About. Nothing
  is a fourteen-section scroll any more, and every page ends with what is
  actually in use.
- **Eight looks, ten accents** — Midnight, Christmas, Aurora, Ocean, Plum,
  Ember, Sand, Mono. Each paints the chrome, the start page and the tab
  switcher; Christmas adds the pine-green night, falling snow and a holiday
  greeting, and picking any other look switches it off. Purple is the default
  accent and sits on top of whichever look you choose.
- **More interface options** — accent glow behind the start page (off leaves
  the plain gradient), spring or plain motion, minimalistic mode, the loading
  bar, the tracker counter in the address bar, and a command bar that is a
  preset rather than a drag: top or bottom, auto-hiding on scroll, floating
  glass panel or docked strip. It always steps aside for the keyboard, so the
  space bar is never covered.
- **A decorated start page** — a layered wash with accent glow, a greeting that
  follows the time of day, a live clock, the favorites grid you add to from the
  page and long-press to prune, the other open tabs, what you read last,
  one-tap History, Flags, Private and Settings tiles, a session read-out, and a
  strip of chips under the search field naming the engine, the look and the JIT
  state. Every block can be switched off in Settings.
- **History** — its own page (`focus://history`), opened inside the tab like
  any other page: visits grouped by day, live counts, a search field, and
  deletion at every scale — one visit, one whole day, one site's entire trail,
  or everything. Nothing is capped or trimmed. Incognito never records.
- **Flags** — also a page (`focus://flags`): eleven switches grouped into
  Appearance, Browsing, Privacy and Advanced, each showing its stage (Stable,
  Beta, Experimental) and the key it is stored under, filterable, with
  enable-all-experimental and reset in one tap.
- **Browsing that is saved** — normal browsing uses the persistent store, so
  history, sign-ins and site data survive relaunches, and tabs are restored at
  launch. Incognito is the only mode that saves nothing.
- **Tabs** — a grid on iPhone, a sidebar on iPad; all share one data store.
- **Tracker blocking** — WebKit content rules block known advertising, analytics
  and pop-up networks, and a hard blacklist refuses known scam domains, link
  shorteners and redirect relays. The shield counts what a page tried to load.
- **Smart address bar** — shows the full URL, resolves domain-shaped input over
  DNS first, and falls back to a search when an address does not resolve.
- **Find on page** — a compact bar at the top of the page with next, previous
  and a way out; WebKit's own `window.find` does the matching, so the highlight
  and wrap-around are the browser's own.
- **Page actions** — share the page, copy the link, add it to favorites, or ask
  for the desktop version of the site (the user agent is swapped and the page
  reloads at once).
- **Focus Search** — the built-in engine renders a classic results page inside
  the tab, with Web and Images tabs and a "Search for more" link, built from
  DuckDuckGo's lightweight endpoints with Google, Bing and DuckDuckGo fallbacks.
- **Live suggestions** — the start-page field and the address bar ask
  DuckDuckGo's key-less autocomplete endpoint as you type, over an ephemeral
  session with a short debounce, and offer a real address first when what you
  typed looks like a domain.
- **Encrypted DNS and Personal VPN** — DNS-over-HTTPS through Cloudflare, Quad9
  or Google via `NEDNSSettingsManager`, and an IKEv2 Personal VPN profile for a
  server you already have.
- **Chrome-style extensions** — a folder with a `manifest.json` in the app's
  `Extensions` folder loads: content scripts, CSS content scripts, background
  scripts, `storage.local`/`sync` and runtime messaging, in isolated worlds.
  Lua is a first-class option through an embedded Lua 5.3 VM (fengari).
- **The mark** — a minimal aperture-and-spark logo drawn in code, so it stays
  crisp and takes the accent colour in use: on the start page, the Settings
  header, the History and Flags headers, and the tab switcher.
- **JIT & Pairing (optional)** — any number of phones can be paired. Each
  `.mobiledevicepairing` record is validated (UDID plus the certificates the
  handshake needs, and the sheet names exactly what a bad file is missing),
  sealed with the app's own Keychain key and stored under its own phone's UDID,
  so a second phone never overwrites the first. Records can be switched between
  and removed one at a time. The tunnel address is a setting shared by the
  pairing sheet and the status check, which reports in the tunnel's own words
  why it could not connect.
- **Pairing-file generator** — Focus Plus can also write the record itself: it
  speaks the whole lockdown handshake through the tunnel, reads the device,
  generates a host certificate with OpenSSL, starts the encrypted session and
  asks the phone for the record, then seals and switches to it.

## Internal pages

| Address | Opens |
| --- | --- |
| `focus://flags` | The Flags page, inside the tab |
| `focus://history` | The History page, inside the tab |
| `focus://start` | A new tab |

`about:flags` and `about:history` work too. Typing the bare word still searches.

## Planned for Focus Plus

- A per-site privacy report behind the shield: what was blocked on the page in
  front of you, and by which rule list.
- Clearing one site's stored data from the page's own menu.
- Extension popup UI and the `chrome.tabs` API, so richer extensions work.
- iCloud sync for settings, favorites and open tabs between iPhone and iPad.
- A Reader view with text-size controls and light, sepia and dark themes.
- Custom tracker-blocking rule lists you can import, enable and delete.

## Building

Open the project and run, or use the Run button in the app this chat lives in.
Targets iOS 26. One dependency: OpenSSL (Swift Package, by Marcin Krzyżanowski),
used by the pairing-file generator for the host certificate and the tunnel's
encrypted session. The fengari Lua VM ships in the app bundle.

**CI:** the *Build IPA* workflow archives a Release build on every push that
touches the app (and on demand from the Actions tab), uploads an unsigned
`FocusPlus.ipa` as a run artifact, and attaches the same IPA to the GitHub
release tagged with the app's version (`v1.0`). Re-sign it with your own
certificate to install it on a device.

## License

MIT — see [LICENSE](LICENSE). Focus Plus is forked from Focus Lite, whose MIT
notice is kept in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
