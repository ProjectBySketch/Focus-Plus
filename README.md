# Focus Plus

A private, feature-rich browser for iPhone and iPad from **ProjectBySketch™** —
proprietary and closed source. It grew out of Focus Lite's engine and adds its
own interface, a dedicated History page, a Flags page, and a much richer start
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
- **History** — its own page (`focus://history`), not a settings row: visits
  grouped by day with Today and Yesterday headings, live counts of visits, sites
  and today's pages, a search field, swipe-to-delete, a long-press menu to open
  in a new tab, open here or copy the address, and Clear All behind a
  confirmation. History is written to Application Support as JSON and capped at
  5,000 visits. Incognito never records anything.
- **A rebuilt interface** — a floating glass command bar with the shield, the
  address and the reload control on one line and the actions on the next; a
  drag-to-lift gesture for the bar; a redesigned tab switcher with a New Tab tile
  and thumbnails; a start page with a mark, a big search field, shortcut tiles,
  the pages you read recently and a privacy card; and an iPad layout with a
  branded sidebar and a floating toolbar.
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
- **Customization** — accent colour, search engine (or a custom template),
  homepage for new tabs, page zoom, minimalistic mode and the alternate app
  icon, all saved on device.
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
  reports whether a StikDebug-style local tunnel is listening. Focus Plus never
  opens a tunnel itself and never uploads the pairing record; removing it
  deletes it from the device.

## Internal pages

| Address | Opens |
| --- | --- |
| `focus://flags` | The Flags page |
| `focus://history` | The History page |
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

This repository carries no source: Focus Plus is closed source, so the app's
code, project file and assets live only on the build machines and never enter
version control. What is kept here is the product README, the licence and the
CI workflow that archives the app when the source is present.

Targets iOS 26; no third-party dependencies beyond the bundled fengari VM.
The alternate "Minimal" app icon is compiled in through the
`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` build setting.

**CI:** `.github/workflows/build-ipa.yml` builds a Release archive and uploads
an unsigned `FocusPlus.ipa` as a build artifact. It publishes nothing; re-sign
the IPA with your own certificate to install it on a device.

## License

Proprietary — see [LICENSE](LICENSE). All rights reserved. The MIT notice of
the project Focus Plus is derived from is kept in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
