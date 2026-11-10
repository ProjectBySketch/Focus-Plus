# Focus Plus

A feature-rich, MIT-licensed browser for iPhone and iPad from
**ProjectBySketch™**. It grew out of Focus Lite's engine and adds its own
interface, a dedicated History page, a Flags page, and a much richer start
page.

## What's in it

- **Flags** — a real `about:flags`-style page (`focus://flags`), with eleven
  switches grouped into Appearance, Browsing, Privacy and Advanced. Every
  switch changes behaviour immediately and is saved on device: floating versus
  docked command bar, rich or bare start page, live tab thumbnails, the tracker
  counter in the address bar, spring or plain motion, history recording, history
  search, tab restore at launch, the incognito app-switcher cover, browser logs
  in Settings, and the internal pages themselves. Each flag shows its stage
  (Stable, Beta, Experimental) and the key it is stored under, and the whole set
  can be turned experimental-on or reset to defaults in one tap.
- **History** — its own page (`focus://history`), opened inside the tab like
  any other page, not as a sheet: visits grouped by day, live counts of visits,
  sites and today's pages, a search field, and deletion at every scale — one
  visit by swiping or from its menu, one whole day from the day's header, one
  site's entire trail from the visit's menu, or everything from the page menu.
  Nothing is capped or trimmed: every visit is kept until it is deleted.
  Incognito never records anything.
- **Flags** — also a page (`focus://flags`), with the same header and back
  button: eleven switches grouped into Appearance, Browsing, Privacy and
  Advanced, filterable, each showing its stage (Stable, Beta, Experimental) and
  the key it is stored under, with enable-all-experimental and reset in one tap.
- **A decorated start page** — a layered wash with accent glow, a greeting that
  follows the time of day, a live clock, a favorites grid you add to from the
  page and long-press to prune, the other open tabs to jump back into, the pages
  you read last, one-tap History, Flags, Private and Settings tiles, and a
  session read-out. Every one of those blocks can be switched off in Settings.
- **Browsing that is saved** — normal browsing uses the persistent store, so
  history, sign-ins and site data survive relaunches, and tabs are restored when
  the app starts again. The erase button wipes everything on demand.
  **Incognito is the only mode that saves nothing.**
- **Incognito mode** — tints the interface, shows a pill, hides page content in
  the app switcher and wipes the session whenever you turn it on or off.
- **Tabs** — multiple tabs in a grid on iPhone and a sidebar on iPad; all share
  one data store, and erasing or toggling incognito drops them all.
- **Tracker blocking** — WebKit content rules block known advertising, analytics
  and pop-up networks, and a hard blacklist refuses known scam domains, link
  shorteners and redirect relays. The shield counts what a page tried to load.
- **Smart address bar** — shows the full URL, resolves domain-shaped input over
  DNS first, and falls back to a search when an address does not resolve.
- **Focus Search** — the built-in engine renders a classic results page inside
  the tab, with Web and Images tabs and a "Search for more" link, built from
  DuckDuckGo's lightweight endpoints with Google, Bing and DuckDuckGo fallbacks
  for images.
- **Encrypted DNS and Personal VPN** — DNS-over-HTTPS through Cloudflare, Quad9
  or Google via `NEDNSSettingsManager`, and an IKEv2 Personal VPN profile for a
  server you already have.
- **Chrome-style extensions** — drop a folder with a `manifest.json` into the
  app's `Extensions` folder and it loads: content scripts, CSS content scripts,
  background scripts, `storage.local`/`sync` and runtime messaging, in isolated
  worlds. Lua is a first-class option through an embedded Lua 5.3 VM.
- **Customization** — accent colour (Purple by default), search engine (or a
  custom template), homepage for new tabs, page zoom and minimalistic mode, all
  saved on device. The phone's command bar sits where
  you preset it — top or bottom, no dragging — and can tuck itself away while
  you scroll, coming back on the way up; it always steps aside for the keyboard
  so the space bar is never covered. Settings also has a Start page section
  with a switch per block (greeting, clock, favorites, open tabs, recently
  visited, shortcuts, session stats) and a Favorites section where the grid can
  be pruned and added to without opening the page.
- **The mark** — a minimal aperture-and-spark logo drawn in code, not an image,
  so it stays crisp and takes the accent colour in use: on the start page, the
  History and Flags headers, and its own tile animation when a tab opens.
- **Looks** — six palettes under Settings → Appearance: Midnight, Christmas,
  Aurora, Sand, Mono and Ocean. Each one paints the chrome, the start page and
  the tab switcher; Christmas adds the pine-green night, falling snow and the
  holiday greeting, and picking any other look switches it off. The accent
  colour sits on top of whichever you choose.
- **Live suggestions** — the start-page field and the address bar both ask
  DuckDuckGo's key-less autocomplete endpoint for completions as you type,
  over an ephemeral session with a short debounce, and offer a real address
  first when what you typed looks like a domain. Nothing is stored.
- **JIT & Pairing (optional)** — Settings can hold the phone's
  `.mobiledevicepairing` file, sealed with the app's own Keychain key, and
  reports whether a StikDebug-style local tunnel is listening. A pairing-file
  page reads the phone through that tunnel — the lockdown handshake, the device
  name, model, iOS version and UDID, and whether the phone wants TLS for
  pairing — so the tunnel can be checked before anything is installed. The
  record itself is written at the encrypted end of that handshake, which needs a
  TLS stack the app does not bundle, so it is generated with SideStore or the
  StikDebug helper and imported here. Nothing is uploaded, and removing the
  pairing file deletes it from the device.

## Internal pages

| Address | Opens |
| --- | --- |
| `focus://flags` | The Flags page, inside the tab |
| `focus://history` | The History page, inside the tab |
| `focus://start` | A new tab |

`about:flags` and `about:history` work too. Typing the bare word still searches,
so nothing is taken away from the address bar.

## Planned for Focus Plus

- A start page with favorites you can add, rename and reorder, alongside the
  recently read pages it shows today.
- A per-site privacy report behind the shield: what was blocked on the page in
  front of you, and by which rule list.
- Extension popup UI and the `chrome.tabs` API, so richer extensions work.
- iCloud sync for settings, favorites and open tabs between iPhone and iPad.
- A Reader view with text-size controls and light, sepia and dark themes.
- Custom tracker-blocking rule lists you can import, enable and delete.
- On-device search history suggestions, and a per-tab list of blocked requests
  you can export.

## Building

Open the project and run, or use the Run button in the app this chat lives in.
Targets iOS 26; no third-party dependencies beyond the bundled fengari VM.

**CI:** the *Build IPA* workflow archives a Release build on every push that
touches the app (and on demand from the Actions tab), uploads an unsigned
`FocusPlus.ipa` as a run artifact, and attaches the same IPA to the GitHub
release tagged with the app's version (`v1.0`). Re-sign it with your own
certificate to install it on a device.

## License

MIT — see [LICENSE](LICENSE). Focus Plus is forked from Focus Lite, whose MIT
notice is kept in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
