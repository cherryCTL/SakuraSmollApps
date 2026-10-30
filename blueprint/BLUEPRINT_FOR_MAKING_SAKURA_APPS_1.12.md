BLUEPRINT_VERSION: 1.12

# BLUEPRINT FOR MAKING SAKURA APPS

**Blueprint version 1.12** (the number on line 1 of this file is the official one). History and the rules for changing this file are in section 16. **If you are an AI agent that was given this file:** when the owner asks you to add, change or remove something in it, edit this file yourself, then raise the version as section 16 says; do not just answer in chat.

**Audience:** an AI coding agent (or a human) building or redesigning a Sakura-style app.
**Purpose:** make a *new* application look, feel, install and behave like part of the **Sakura Apps** family.
**For every Sakura app, not for one app.** NetScope appears only as *evidence* of how the pattern was done once; every example is an illustration of a pattern, never something to rebuild (see 13.3).
**Not a spec for any particular app.** Nothing here tells you what your app must *do*. Network monitoring, DNS probes, speed tests and mirror checks are NetScope's own functions and must never be copied into another product.

**Scope (read first).** This is primarily a **Sakura TUI design blueprint**: it defines the visual language, boxed layout, progress bars, themes, keyboard navigation, settings and installation experience for terminal user interfaces. **TUI describes the interface, not the programming language. Do not default to Bash or shell scripts.** Choose the implementation language and project structure that best fit the user's request and existing repository; use shell only when the user explicitly asks for it or the existing project requires it. If the user does not specify an interface, prefer a TUI for a terminal-oriented Sakura app, but never infer that it must be written as a shell script. If the user asks for a desktop GUI, web UI, game or another interface, build that interface instead and adapt the same Sakura visual identity with native components. If the user asks for a CLI-only utility, do not add a TUI unless requested. The user's app-specific description is the sole source of its functionality; this blueprint contributes style and reusable UX conventions, not product features.

How to read the evidence labels used throughout:

| Label | Meaning |
|---|---|
| **Observed** | Confirmed in the supplied Sakura NetScope sources (including v1.9.3 and the stable v1.0 release) or the uploaded Sakura Downloader backup. Version-specific differences are called out; a proposed standard is not labelled Observed. |
| **Recommended** | A good practice this blueprint asks you to follow. It is *not* claimed to exist in the current source. |
| **Unknown** | Could not be verified from the available files. Listed again in section 15. |

Evidence was extracted from the supplied Sakura NetScope v1.9.3 and stable v1.0 sources, plus the Sakura Downloader backup, especially themes/colours, box and panel layout, hints, settings, keyboard handling, responsive screens, progress indicators, performance/caching, classified installer requirements and install/uninstall behaviour. NetScope remains evidence for reusable patterns only, not a requirement to use Bash, a single-file architecture, or any NetScope feature. Section 9 also defines the owner-approved shared install/icon contract for future Sakura apps; parts of that contract intentionally improve on the current NetScope implementation.

---

## 0. One-page summary of the Sakura identity

- **Name:** `Sakura <Product>` (display), `sakura-<product>` (command and file slug). Example: `Sakura NetScope` / `sakura-netscope`.
- **Mood:** calm, soft, dark-terminal-friendly. Pink accents on a plain terminal background, thin rounded borders, generous labels, short keyboard hints.
- **Signature elements:** a cherry-blossom **tree logo** with the title `S A K U R A` and the product name under it; the **✿** blossom glyph in every panel title; **rounded box borders**; a **solid reverse-video selection bar** with a **▶** marker; and a theme-coloured **Hints box** whose key list is grouped and separated clearly. Put version/install/uninstall guidance in Settings, not as permanent clutter on the main dashboard.
- **Palette:** the default Hanakage theme uses xterm-256 foreground roles: pink `218`, rose `211`, cyan `117`, green `114`, yellow `222`, red `203`, gray `245`, brown `137` (tree trunk only). **Themes:** every app ships twenty-five selectable themes: the eighteen core palettes plus seven character-inspired themes: `anta-baka`, `soulless-moon`, `calm-whisper`, `retro-bit`, `darkly-rose`, `lightly-rose`, and `galactic-silence`. The seven new themes use RGB role colours where needed; Lightly Rose also uses an explicit light surface in interfaces that support backgrounds (section 2.4).
- **Theme tokens (1.2):** screens never ask for a colour, they ask for a *token* (`bar_fill`, `btn_focus`, `border`, `hint_key`, ...); each token resolves to a theme role plus attributes, so a theme restyles progress bars, buttons, text, lines and borders together (2.5).
- **Thin progress bars (1.2):** in Unicode mode the cells that show how full a bar is are thin lines `━` (filled) and `─` (empty), not full-height blocks; ASCII stays `#` and `-` (3.4, 7.1).
- **Navigation:** single-letter keys, arrows, `Tab` to switch panel, `Enter` for details, `Esc`/`q` to go back, `r` to refresh **and** redraw, `x`-style toggles for modes. Linked panels that form one logical list can share one active selection marker and let Up/Down cross panel boundaries (4.4). In a TUI with global theme cycling, `,` moves to the previous theme and `.` to the next from any non-text-input screen; the Hints row shows `< Theme Name >` beside `< setting` (4.2).
- **Hints and footer:** show every shortcut once in the hints area, grouped with thin separators; use two balanced columns when wide enough. Avoid a duplicate bottom shortcut legend and keep uninstall guidance in Settings/About rather than the main dashboard.
- **Resilience:** one-pass frame painting (no flicker), resize handling (3.8), Unicode with ASCII fallback, colour-off support and a useful non-interactive fallback when the app supports one.
- **Smoothness (1.2):** frame building is budgeted and measured; no forks in hot paths, cached art, only the visible rows are built, idle loops block instead of spinning (12.12).
- **Lists (1.2):** every list has a visible selection bar, arrow-key movement, a scrolling window and an `Enter` details screen (4.4).
- **Privacy (1.2):** a method for hiding any class of sensitive data in any part of an app, with identical box heights and no leaks on any screen (6.2).
- **Install experience:** an explicit first-run choice between **System-wide**, **Local** and **Demo**, a live **Requirements** panel with **MUST BE INSTALLED / BETTER TO INSTALL / OPTIONAL** dependency groups, resize-aware installer UI, plus a shared, confirmation-based uninstaller reachable from Settings and the command entry point (section 9). Local app payloads live in `~/.local/bin/sakurasuit/<app-id>/`; per-app settings/config (and app-owned cache/demo subfolders where required) live in `~/.config/SakuraSuit/<app-id>/`.
- **Desktop integration:** detect an app-matching `.png`, `.jpg` or `.ico` beside the source/package; install the chosen icon with the app, create a standard `.desktop` entry, use a stock icon only when no usable custom icon exists, and remove only owned launcher/icon files on uninstall (1.4, 9).

Three layers, never mix them up:

| Layer | What it is | Reuse rule |
|---|---|---|
| **Shared identity** | Name pattern, logo style, palette roles, borders, glyph set, hint style, selection style, first-run choice, uninstall wording | Copy the *rules*; adapt the *content* |
| **General infrastructure** | Frame painter, key reader, settings file, temp dir and cleanup, installer, ASCII fallback, resize handling | Reimplement in your language following the same behaviour |
| **App-specific functionality** | Your data, your panels, your screens, your keys | Design from your requirements; never import NetScope's |

---

# PART A — SAKURA VISUAL & EXPERIENCE BLUEPRINT

## 1. Identity and branding

### 1.1 Naming

**Observed in stable NetScope v1.0 (with earlier v1.9.3 lineage)**
- Display name: `Sakura NetScope`; command slug: `sakura-netscope`.
- A separate app-directory id is `sakura_netscope`; this is the directory name under `SakuraSuit` and is not the terminal command.
- Per-user configuration is stored at `${XDG_CONFIG_HOME:-~/.config}/SakuraSuit/sakura_netscope/`, including `settings.conf`, `install.conf`, and optional provider/speed-test configuration.
- NetScope v1.0 uses the SakuraSuit per-app configuration namespace and a single-file executable payload; its local command/launcher arrangement is reference-app-specific. The nested multi-file bundle structure defined in section 9 remains the required family standard for new implementations.
- Temporary files use a per-run temporary directory and must be removed on exit. Environment variables use an app-specific prefix such as `NETSCOPE_PROXY`.

**Rules for a new product**
1. Pick a clear product noun: `Timer`, `Notes`, `Tetris`, `Backup`. Avoid generic names such as `App`.
2. Define these fields **once** in a single identity block: display name, command slug, app-directory id, environment prefix, version, tagline, entry point, desktop id, default stock icon name and optional icon candidates.
3. Display name = `Sakura ` + Title Case noun. Command slug = `sakura-` + lowercase noun with hyphens (example `sakura-timer`). App-directory id = `sakura_` + lowercase noun with underscores (example `sakura_timer`). Never conflate the command with the app-directory id.
4. Environment prefix = uppercase product noun, without an extra `SAKURA_` prefix (for example `TIMER_INTERVAL`).
5. Keep the display name, command slug, app-directory id and desktop id consistent across help, Settings, install paths, desktop entries, icon names, backup names and uninstall messages. Derive them from the identity block rather than duplicating literals.

| Identity field | Example |
|---|---|
| Product noun | Timer |
| Display name | Sakura Timer |
| Command slug | `sakura-timer` |
| App-directory id | `sakura_timer` |
| Per-user config directory | `~/.config/SakuraSuit/sakura_timer/` |
| Environment prefix (if needed) | `TIMER` |
| Tagline | A timer that runs your event |

### 1.2 Where the name appears (all of these must be updated for a new app)

| Place | Observed in NetScope | Rule |
|---|---|---|
| Main box title | `✿ Sakura NetScope` | Blossom + display name |
| Logo caption | `S A K U R A` / `NetScope` | Brand line, then product line |
| Footer / status | Short messages only | Never repeat the name |
| Sub-screen titles | `✿ Settings`, `✿ Speed test`, `✿ Glossary` | Blossom + screen name (no product name needed) |
| Help text (`--help`) | Header block of the script | First line: `<Display name> — <tagline>` |
| `--version` | `sakura-netscope 1.2.0` | `<slug> <version>` |
| Install messages | `installed to <path>`, uninstall heading | Always say `Sakura <Product>` |
| Menu entry | `Name=Sakura NetScope` (no uninstall action; 9.2 "Uninstall entry points") | Same pattern |
| Backup file | `sakura-netscope-backup-<stamp>.sh` | `<slug>-backup-<stamp>` |
| Terminal title | **Unknown / not set by the app** | **Recommended:** set to the display name on start (`printf '\e]0;%s\a'`) and clear it on exit |

### 1.3 The logo

**Observed.** The family logo is a pink cherry-blossom tree in plain ASCII characters so it renders in any terminal and in ASCII mode. NetScope reuses the Sakura Downloader tree and changes only the last line (product name). Width 26, height 10:

```text
        .@@@@@@.
     .@@@o@@@@@o@@.   .
    @@o@@@@@@@@@@o@@@
     ~@@@o@@@@@@@o@@~
  ,    ~~@@@@\|/@@@~~  .
     .         |         ,
   ,          /|\    .
           ___|___
      S A K U R A
        <Product>
```

Colouring is done **per character class**, not per line (Observed):

| Character | Meaning | Colour |
|---|---|---|
| `@` | blossom mass | pink |
| `o` | darker blossoms | rose |
| `.` `,` | falling petals / sparkle | pink |
| `~` | lower canopy shadow | rose |
| `\` `|` `/` `_` | trunk and branches | brown |
| `S A K U R A` | brand line | bold pink |
| product line | product name | rose |

There is also a **small tree** for narrower terminals (11 columns, 6 rows) and a **privacy/empty-state "grove"** (several trees of different sizes with fallen petals, generated deterministically so it never changes between frames).

**Rules for a new app**
1. Keep the tree, the colour mapping and the two caption lines. Change only the product line (centre it under `S A K U R A`).
2. If the product has a mascot-like motif (a cloud for Weather, a block for a game), you may add **one** small product symbol *next to* the tree or in the title row. Do not replace the tree.
3. Never ship a logo that needs Unicode: the tree must stay ASCII-only. Unicode is allowed only for decoration (✿, ▶, box drawing).
4. Show the logo only where there is room (see section 4.5 thresholds). When it does not fit, fall back to the small tree, then to the title text `✿ Sakura <Product>`.
5. Use the logo on: the main screen, first-run screen, About, install and uninstall screens. Do not put it on every sub-screen.

### 1.4 Icons and assets

**Observed in NetScope v1.9.3:** its desktop entry uses the stock icon name `preferences-system-network`. Automatic discovery of a sibling custom image is a new required family rule, not an existing NetScope feature.

**Custom icon discovery (required for new apps)**
1. At installation, inspect only the app's source/package directory and any explicitly declared assets directory; do not recursively search the user's home directory or choose an unrelated image.
2. Look for a file whose basename matches the app-directory id first, then the command slug, then the source entry-point stem. Accept `.png`, `.jpg` and `.ico` (case-insensitive extension). Example: `sakura_netscope.sh` beside `sakura_netscope.ico` means the ICO is the matching custom icon. If several exact matches exist, use a deterministic documented precedence (prefer PNG, then JPG, then ICO within the same basename); never pick a random file.
3. Validate that the selected file exists, is readable and is a plausible image. Copy it into the installed app bundle. In Local mode it stays beside the app under `~/.local/bin/sakurasuit/<app-id>/`. In System-wide mode the bundle keeps its copy and the installer also places it in the standard system icon-theme tree where appropriate (section 9.2).
4. The desktop entry should reference the installed copy, never the temporary source path. An absolute `Icon=` path is allowed by the Desktop Entry Specification; when using an icon-theme name, use a stable app-specific name and install the icon in the corresponding icon-theme directory. Some desktop environments may not support every image format equally: test `.ico` and `.jpg`; if the custom icon cannot be displayed, use the declared stock fallback rather than leaving a broken icon.
5. If no usable matching custom image is found, use one explicit stock freedesktop icon name selected for the product. Keep this fallback in the identity block. Never generate, download or invent an icon automatically.
6. On uninstall, remove the exact app-owned custom icon and desktop entry installed by that mode. Do not remove a stock icon supplied by the system or an icon with a name shared by another app.
7. A GUI app may additionally have runtime assets, but all files must remain inside the app's bundle or an explicitly owned per-app data directory; do not scatter untracked assets around the filesystem.

Decorative TUI symbols follow section 7. A product symbol must also have an ASCII fallback.

### 1.5 Avoiding leftovers when adapting a blueprint or an old app

Before finishing, search the whole project (case-insensitive) for every old product name, slug, env prefix, desktop id, icon name, config path and tagline. Zero hits are expected except in a changelog. Typical leftovers: `NetScope`, `NETSCOPE_`, `sakura-netscope`, `provider`, `mirror`, `speed test`, example hostnames, help text, glossary entries, the desktop file, the uninstall messages and test fixtures.

---

## 2. Colour palette and visual language

### 2.1 The palette (default theme: Hanakage)

**Observed** (xterm 256-colour escape codes, hard-coded in one function that sets variables; the hex values are the standard xterm values for those indexes):

| Name | Code | ≈ Hex | Shared identity? | Role |
|---|---|---|---|---|
| Pink | `38;5;218` | `#ffafd7` | **Yes** | Primary accent: borders, panel titles, headings, hint keys, tree canopy, contextual hint text, logo brand line |
| Rose | `38;5;211` | `#ff87af` | **Yes** | Secondary accent: selection marker and bar, hint descriptions, live values, product line, petal decoration |
| Cyan | `38;5;117` | `#87d7ff` | Yes | Labels and neutral information (field names, informational status messages) |
| Green | `38;5;114` | `#87d787` | Semantic | Success, healthy, completed, "on" |
| Yellow | `38;5;222` | `#ffd787` | Semantic | Warning, missing optional item, attention |
| Red | `38;5;203` | `#ff5f5f` | Semantic | Error, failed, unreachable |
| Gray | `38;5;245` | `#8a8a8a` | Yes | Secondary text, empty bar cells, bar brackets, disabled/unknown, help footers inside sub-screens |
| Brown | `38;5;137` | `#af875f` | Logo only | Tree trunk |
| Bold / Dim / Reverse | `1` / `2` / `7` | — | Yes | Emphasis, de-emphasis, selection bar |

**Primary text** normally uses the terminal's default foreground, and the eighteen core themes use xterm-256 foreground codes without setting a background. **Observed in NetScope v1.9.3:** the historical implementation had seven selectable themes and no truecolor or background-theme support. Blueprint 1.10 adds seven owner-approved character themes; these may use 24-bit RGB foreground values for palette fidelity. `lightly-rose` is the sole core-set exception that may paint a light background and matching base foreground on the app's rendered surface; terminal-wide palette settings must never be changed, and the original screen must be restored on exit. If a UI toolkit does not use terminal ANSI painting, render this variant as a native light surface.

### 2.2 Rules for reuse

1. Define colours **once**, by *role* (primary, secondary, label, ok, warn, error, muted, trunk), from the theme table in 2.4 (one init function reads the active theme). Never write raw escape codes inside screens.
2. Keep the **shared identity** colours (pink, rose, cyan, gray, brown) in every app. Semantic colours (green, yellow, red) keep their meaning but your app decides *which* states map to them: Weather might use yellow for "rain likely", a game might use red for "game over".
3. **Do not rely on colour alone** (Recommended; partly Observed). NetScope pairs colour with words and glyphs: status words (`UP`, `DOWN`, `DEGRADED`, `WARMING UP`), glyphs `✓ ✗ !`, and a bar plus a percentage. Every status in your app needs a word or glyph in addition to its colour.
4. Selection must remain visible with colours off: use reverse video (when colours are on) and the `▶`/`>` marker (always).
5. Contrast: pink on a dark terminal is the design target. On a light terminal pink and yellow may be faint. **Unknown** whether this was ever tested; Recommended: offer `NO_COLOR` and a `--no-color` option (NetScope honours `NO_COLOR`, `TERM=dumb` and non-tty output by turning colours off).
6. Do not add new hues for decoration. If a new accent is truly needed, derive it from pink or rose.

### 2.4 Themes (standard for every Sakura app)

**Status.** The seven-theme implementation is **Observed historically** in Sakura NetScope v1.9.3 and Sakura Downloader 12.0.0. NetScope v1.0 has all twenty-five themes and declares `violet-purple` as its own default; this app-specific choice does not change the family fallback of `hanakage` for an app whose owner has not chosen a default. Blueprint 1.9 established eighteen core themes; blueprint 1.10 expands the shared standard to **twenty-five themes** by adding seven owner-selected character themes and a light-surface treatment for `lightly-rose`. These seven new palettes and RGB/light-surface behaviour were not present in the historical seven-theme reference sources. The theme roles and tests below apply to every new or redesigned Sakura app.

A **theme** is a set of eight colour *roles*. Everything else (bold, dim, reverse video, layout, glyphs, wording) is shared by all themes, so a theme never changes how the app works, only how it is tinted. **Hanakage is the default theme**, while Sakura remains the name of the overall app family. Every app must define its intended default theme explicitly in its app metadata/configuration. If the app creator has not chosen or specified a different default, use `hanakage`. A newly installed app uses its declared default until the user selects and saves another theme; after that, the saved choice persists across restarts. The brand logo and product identity remain Sakura-family identity, not theme-specific.

#### 2.4.1 Roles

| Role | Used for (same as the usage map in 2.3) | Sakura name |
|---|---|---|
| `primary` | Borders, titles, section labels, hint keys, contextual hint text, brand line, tree canopy | Pink |
| `secondary` | Selection marker and bar, hint descriptions, live values, product line, shadows in the canopy | Rose |
| `label` | Field labels and neutral information | Cyan |
| `ok` | Success, healthy, "on" | Green |
| `warn` | Warning, missing optional item, attention | Yellow |
| `error` | Error, failed, unreachable | Red |
| `muted` | Secondary text, paths, empty bar cells, disabled/unknown | Gray |
| `trunk` | Tree trunk and branches in the logo only | Brown |

Shared attributes in every theme: `bold`, `dim`, and `reverse`. The eighteen core themes and all character themes except `lightly-rose` retain the terminal's default background; `lightly-rose` is the one explicit light-surface exception and applies background colour only to rendered app cells, then resets it on exit.

#### 2.4.2 The twenty-five standard themes

Code order is `primary secondary label ok warn error muted trunk`. Core themes use xterm-256 indexes (`ESC[38;5;<n>m`); the seven character themes may use exact hex/RGB entries (`ESC[38;2;r;g;bm`).

| Slug | Name | Codes | Mood |
|---|---|---|---|
| `hanakage` | Hanakage (**default**) | `218` `211` `117` `114` `222` `203` `245` `137` | Soft blossom pink, rose and muted tones; the default Sakura-family theme |
| `joyful-sea` | Joyful Sea | `45` `39` `159` `121` `221` `203` `245` `94` | Bright turquoise and azure, light aqua labels |
| `emerald-green` | Emerald Green | `78` `36` `152` `156` `222` `203` `245` `94` | Jewel greens with a pale silver-green label |
| `sunset-yellow` | Sunset Yellow | `221` `208` `223` `114` `209` `203` `245` `130` | Golden yellow with orange, warm cream labels |
| `clean-white` | Clean White | `255` `250` `153` `114` `222` `203` `244` `245` | White and silver with a pale-blue label; the calmest theme |
| `aqualume` | Aqualume | `123` `75` `195` `121` `229` `210` `109` `67` | Luminous aqua, sky-blue glass and near-white labels |
| `violet-purple` | Violet Purple | `141` `135` `183` `114` `222` `203` `245` `96` | Lavender and violet, soft orchid labels |
| `coffee-brown` | Coffee Brown | `130` `137` `223` `114` `222` `203` `245` `94` | Warm coffee and caramel browns with cream labels |
| `kohaku` | Kōhaku | `160` `203` `231` `114` `222` `124` `245` `240` | Bold red and clean white accents; semantic errors use a deeper red |
| `matcha-garden` | Matcha Garden | `107` `149` `230` `151` `222` `203` `245` `94` | Matcha green, sage, cream and quiet garden tones |
| `midnight-tide` | Midnight Tide | `25` `39` `153` `121` `221` `203` `245` `60` | Deep midnight navy, silver and cool cyan |
| `momiji-ember` | Momiji Ember | `160` `166` `222` `114` `220` `124` `245` `130` | Japanese maple crimson, burnt orange, gold and warm brown |
| `neon-shibuya` | Neon Shibuya | `45` `201` `117` `121` `220` `203` `245` `99` | Cyberpunk teal, magenta, purple and electric blue |
| `wisteria-dream` | Wisteria Dream | `183` `141` `189` `151` `222` `203` `245` `97` | Wisteria lilac, orchid, pale blue-white and deep purple |
| `indigo-washi` | Indigo Washi | `25` `61` `189` `114` `222` `203` `245` `137` | Indigo ink, washi-paper white, warm gray and pale blue |
| `jade-dynasty` | Jade Dynasty | `36` `78` `152` `156` `220` `203` `245` `130` | Deep jade, bright green and antique gold |
| `frostbite` | Frostbite | `117` `153` `195` `159` `229` `203` `245` `109` | Icy blue, cold white, silver and steel blue |
| `cyberneon` | Cyberneon | `46` `118` `190` `154` `226` `203` `245` `94` | Cyberpunk green and electric yellow, with neon contrast and dark-terminal readability |
| `anta-baka` | Anta Baka | `#D52B35` `#F07832` `#FFD166` `#87D787` `#FFD166` `#D52B35` `#A69AA1` `#2D2029` | Asuka-inspired tsundere fire: hot red, orange, warning gold and charcoal |
| `soulless-moon` | Soulless Moon | `#607FC4` `#A7C7ED` `#A7C7ED` `#87D787` `#FFD787` `#C74954` `#6D7890` `#242B3B` | Rei's first selected palette: detached icy blue, deep blue and restrained red |
| `calm-whisper` | Calm Whisper | `#45BFC1` `#3B78B5` `#D8C66D` `#87D787` `#D8C66D` `#FF5F5F` `#7C8796` `#273A55` | Sona Classic: calm sea-glass cyan, blue and soft gold |
| `retro-bit` | Retro Bit | `#F34AA6` `#27D9E8` `#8C5BFA` `#87D787` `#FFD166` `#FF5F5F` `#8175B8` `#252047` | Sona Arcade: pixel magenta, electric cyan and purple |
| `darkly-rose` | Darkly Rose | `#7548A8` `#558FBC` `#558FBC` `#87D787` `#F3EFC1` `#D94E61` `#DBDDE2` `#43469A` | Crystal Rose on a dark terminal surface using all five extracted skin colours |
| `lightly-rose` | Lightly Rose | `#7548A8` `#558FBC` `#43469A` `#2F7D57` `#9A7925` `#B13B50` `#777A86` `#43469A` | Crystal Rose light variant; outfit grey is the background and clip cream is the selected-row surface |
| `galactic-silence` | Galactic Silence | `#5999F4` `#984B61` `#9DBAFF` `#87D787` `#FFD787` `#FF5F5F` `#6554B5` `#151A43` | Sona Stargazer revised palette: blue-forward galaxy, nebula purple, and muted burgundy |

Hex values for GUI/web rendering and RGB-role themes (section 8). For the eighteen core themes, these are the nearest display colours for their xterm-256 indexes; the seven character-theme rows use their RGB values directly:

| Theme | primary, secondary, label, ok, warn, error, muted, trunk |
|---|---|
| Hanakage | `#ffafd7` `#ff87af` `#87d7ff` `#87d787` `#ffd787` `#ff5f5f` `#8a8a8a` `#af875f` |
| Joyful Sea | `#00d7ff` `#00afff` `#afffff` `#87ffaf` `#ffd75f` `#ff5f5f` `#8a8a8a` `#875f00` |
| Emerald Green | `#5fd787` `#00af87` `#afd7d7` `#afff87` `#ffd787` `#ff5f5f` `#8a8a8a` `#875f00` |
| Sunset Yellow | `#ffd75f` `#ff8700` `#ffd7af` `#87d787` `#ff875f` `#ff5f5f` `#8a8a8a` `#af5f00` |
| Clean White | `#eeeeee` `#bcbcbc` `#afd7ff` `#87d787` `#ffd787` `#ff5f5f` `#808080` `#8a8a8a` |
| Aqualume | `#87ffff` `#5fafff` `#d7ffff` `#87ffaf` `#ffffaf` `#ff8787` `#87afaf` `#5f87af` |
| Violet Purple | `#af87ff` `#af5fff` `#d7afff` `#87d787` `#ffd787` `#ff5f5f` `#8a8a8a` `#875f87` |
| Coffee Brown | `#af5f00` `#af875f` `#ffd7af` `#87d787` `#ffd787` `#ff5f5f` `#8a8a8a` `#875f00` |
| Kōhaku | `#d70000` `#ff5f5f` `#ffffff` `#87d787` `#ffd787` `#af0000` `#8a8a8a` `#585858` |
| Matcha Garden | `#87af5f` `#afaf5f` `#8787d7` `#afd787` `#ffd787` `#ff5f5f` `#8a8a8a` `#875f00` |
| Midnight Tide | `#005faf` `#00afff` `#afafd7` `#87ffaf` `#ffd75f` `#ff5f5f` `#8a8a8a` `#5f5f87` |
| Momiji Ember | `#d70000` `#d75f00` `#ffd787` `#87d787` `#ffd700` `#af0000` `#8a8a8a` `#af5f00` |
| Neon Shibuya | `#00d7ff` `#ff00af` `#87d7ff` `#87ffaf` `#ffd700` `#ff5f5f` `#8a8a8a` `#5f87ff` |
| Wisteria Dream | `#d7afff` `#af87ff` `#d7d7ff` `#afd787` `#ffd787` `#ff5f5f` `#8a8a8a` `#875f87` |
| Indigo Washi | `#005faf` `#5f87af` `#d7d7ff` `#87d787` `#ffd787` `#ff5f5f` `#8a8a8a` `#af875f` |
| Jade Dynasty | `#00af87` `#5fd787` `#afd7d7` `#afff87` `#ffd700` `#ff5f5f` `#8a8a8a` `#af8700` |
| Frostbite | `#87d7ff` `#afd7ff` `#d7ffff` `#afffff` `#ffffaf` `#ff5f5f` `#8aafaf` `#5f87af` |
| Cyberneon | `#00ff5f` `#5fff00` `#87d7ff` `#afff87` `#ffff00` `#ff5f5f` `#8a8a8a` `#875f00` |

| Anta Baka | `#D52B35` `#F07832` `#FFD166` `#87D787` `#FFD166` `#D52B35` `#A69AA1` `#2D2029` |
| Soulless Moon | `#607FC4` `#A7C7ED` `#A7C7ED` `#87D787` `#FFD787` `#C74954` `#6D7890` `#242B3B` |
| Calm Whisper | `#45BFC1` `#3B78B5` `#D8C66D` `#87D787` `#D8C66D` `#FF5F5F` `#7C8796` `#273A55` |
| Retro Bit | `#F34AA6` `#27D9E8` `#8C5BFA` `#87D787` `#FFD166` `#FF5F5F` `#8175B8` `#252047` |
| Darkly Rose | `#7548A8` `#558FBC` `#558FBC` `#87D787` `#F3EFC1` `#D94E61` `#DBDDE2` `#43469A` |
| Lightly Rose | `#7548A8` `#558FBC` `#43469A` `#2F7D57` `#9A7925` `#B13B50` `#777A86` `#43469A` |
| Galactic Silence | `#5999F4` `#984B61` `#9DBAFF` `#87D787` `#FFD787` `#FF5F5F` `#6554B5` `#151A43` |

**Owner-provided Crystal Rose source palette (preserve exactly):** hair `#43469A`; outfit `#DBDDE2`; flower `#7548A8`; eyes `#558FBC`; instrument/clothing clips `#F3EFC1`. Both `darkly-rose` and `lightly-rose` use this same palette. The dark variant maps all five source colours directly into foreground roles. The light variant uses `#DBDDE2` as its light terminal surface and `#F3EFC1` as the selected-row surface; its semantic warning/error/ok roles are darkened where needed for readable contrast. The source colours are not replaced by the contrast adjustments.' 

Deliberate adjustments keep semantic roles distinct: in **Emerald Green**, **Sunset Yellow**, **Kōhaku** and **Cyberneon**, semantic colours remain distinguishable from decorative accents. The character themes likewise retain readable success/warning/error roles instead of assigning arbitrary character colours to every state. Whatever the theme, a status is never shown by colour alone (rule 3 in 2.2). `darkly-rose` uses the terminal's existing background. `lightly-rose` is the only theme that paints its own light surface (`#DBDDE2`, with a base foreground of `#43469A`) and uses `#F3EFC1` for the selected-row surface; this is done with per-cell ANSI rendition rather than changing the terminal emulator's global palette, and the prior screen is restored on exit.

#### 2.4.3 Rules

1. **One table.** Keep the themes in one place (three parallel arrays or one structure: slug, display name, eight role colours, and optional surface metadata). Role colours may be xterm-256 indexes or RGB hex values. Screens use the role variables only (`C_PRI`, `C_SEC`, `C_LBL`, `C_OK`, `C_WARN`, `C_ERR`, `C_MUT`, `C_TRUNK`, plus `C_BOLD`, `C_REV`, `C_OFF`). No raw escape codes anywhere else.
2. **Selection order:** `--theme NAME` > environment variable `<PREFIX>_THEME` > saved setting `theme=<slug>` > the app-declared default theme (use `hanakage` if none is declared). An unknown value from the saved file or environment silently falls back to the next source; an unknown value passed with `--theme` is an error (exit code 2, with the list of valid names).
3. **Per-app default theme (required).** Each app must explicitly declare its own default theme in its app metadata/configuration and document it in Settings > Appearance or About. If the owner has not selected a product-specific default, use `hanakage`. This declared default applies on first launch until the user saves a theme choice. Selection precedence is explicit CLI override, environment override, saved user preference, then the app-declared default (which defaults to `hanakage`); an invalid saved value falls back to the app-declared default. Never silently change a saved user theme when the app is updated.
4. **Settings > Appearance.** A row `Theme` shows `< Name >` and four colour chips. `Left`/`Right` (or `Enter`) cycle through the themes and the whole screen is **re-tinted immediately** (live preview). Invalidate every theme-dependent frame, colour string and decorative-art cache as soon as the theme changes. On leaving Settings, mark the underlying screen dirty and rebuild it before showing it; the old theme must never remain visible until the user manually refreshes or restarts. The change is saved with the normal Save action; leaving with "discard" restores the previous theme and redraws with it. Place the `ASCII mode` row next to it. For a TUI with global theme cycling, also support `,` (previous) and `.` (next) on every screen that is not accepting text input; apply and persist the change immediately, and redraw the current screen in place without navigating away.
5. **Optional command-line controls.** If the app already has a command-line interface, it may expose `--theme NAME`, `--list-themes` and `--no-color`; these flags are not required for a TUI app. `NO_COLOR` and `TERM=dumb` should disable colour when relevant, while selection remains visible through the `▶`/`>` marker.
6. **Logo.** The tree keeps its character mapping (section 1.3) but is coloured by role: `@`, `.`, `,` -> `primary`; `o`, `~` -> `secondary`; `\ | / _` -> `trunk`; `S A K U R A` -> bold `primary`; product line -> `secondary`.
7. **Semantic colours keep their meaning** in every theme. An app may define its own semantic states (rain, game over) but must map them onto `ok`/`warn`/`error`/`label`, never onto a new hue.
8. **Dark terminals are the default design target.** *Clean White* and *Kōhaku* use pale/white foreground accents on the terminal's existing background. `lightly-rose` is the explicit light-surface exception: on a TUI it colours rendered cells with a light outfit-grey background and a contrasting dark base foreground, uses cream as the selected-row surface, and never changes terminal-wide palette settings. Scope this surface to the app's rendered screen and restore the previous alternate screen on exit. Other themes must not set a background. (section 15)
9. **Themes change presentation only.** Same text, same glyphs, same widths, same keys and same behaviour. A theme must never be required to understand a screen. The optional `lightly-rose` surface changes the rendered background treatment but not layout or content.
10. **Adding a theme later:** add one entry to the authoritative role table and matching hex table (slug, display name, eight role values); add surface metadata only if needed, add an override row if needed, and keep every theme count/list in this blueprint synchronized. Then run the theme tests. Do not add themes that are only a recolour of an existing one with worse contrast.
11. **Light-surface rendering efficiency (Observed in NetScope v1.0):** for `lightly-rose`, use a compact combined SGR rendition for the recurring base foreground/background and another combined rendition for the selected-row surface, rather than emitting separate reset, foreground and background controls for every styled fragment. Keep the exact RGB palette and visible appearance unchanged; do not alter the terminal emulator's global palette. Always restore normal rendition and the previous screen on exit. Measure ANSI control-sequence count and output bytes before/after an optimisation, and keep the change only if it is visually identical.

#### 2.4.4 Theme tests (add to the render tests)

- Render every screen under every theme: after stripping colour codes the output must be **byte-identical** across themes.
- The set of foreground codes (`38;5` or `38;2`) found in a theme's output must match its declared role palette, except documented base/surface colours for `lightly-rose`; the only permitted background colour is `48;2;219;221;226` plus the selected-row `48;2;243;239;193` in that theme.
- Settings round trip: select a theme, save and restart; the same theme returns. Invalid saved values fall back to the app-declared default, which is `hanakage` unless the owner explicitly chooses another default. If the app implements a `--theme` option, an invalid explicit value must be reported clearly.
- Global theme navigation: from the dashboard and each non-text-input screen, `,` selects the previous theme and `.` the next; verify wraparound, immediate re-tint, persisted preference and cache invalidation. While a text field has focus, punctuation is input and must not change the theme.
- For `lightly-rose`, verify identical layout/content before and after ANSI-sequence optimisation, verify the allowed light/selection background codes only, and measure a representative full-frame render.
- `NO_COLOR=1` and `--no-color` output contains no `ESC[...m` sequence.

### 2.5 Theme coverage: component tokens (standard since blueprint 1.2)

**Status: Recommended.** Not Observed in any app yet; NetScope and Downloader 12 colour their screens from the eight role variables directly. Tokens are the fix for the next problem: a theme should restyle **everything** (progress bars, buttons, text, lines, borders, selection, hints, inputs), but a table of eight colours does not say *which* colour each of those uses. Tokens say it once.

#### 2.5.1 Two layers

| Layer | What it is | Who may use it |
|---|---|---|
| **Roles** (2.4.1) | The palette: `primary secondary label ok warn error muted trunk`, plus `bold dim reverse` and the terminal default | Only the token builder |
| **Tokens** (this section) | A *named style* = one role (or the terminal default) + attributes. Screens and components ask for tokens | Every screen and component |

A token represents a named visual style (for example `border`, `bar_fill` or `btn_focus`). Rendering uses the selected toolkit's styling mechanism; screens never hard-code palette values.

#### 2.5.2 The token table (default mapping, shared by all themes)

| Group | Token | Role (+ attributes) | Used for |
|---|---|---|---|
| Frame | `border` | primary | Box borders of the main/focused boxes |
| | `border_dim` | muted | Borders of unfocused boxes, inner dividers |
| | `title` | primary + bold | Box titles |
| | `heading` | primary + bold | Screen headings, section names |
| | `sep_line` | muted | Separator rules (`── LABEL ───`) |
| | `sep_label` | primary + bold | The label inside a separator |
| Text | `text` | terminal default | Normal body text and values |
| | `text_dim` | muted | Notes, paths, secondary text, empty/unknown values |
| | `label` | label | Field names and neutral information |
| | `hint_key` | primary + bold | The key in a hint (`Enter`) |
| | `hint_text` | secondary | The description in a hint |
| | `footer` | primary | Contextual sub-screen hints/status; never use this token to add a duplicate permanent shortcut legend or uninstall line to the main dashboard |
| | `st_info` / `st_ok` / `st_warn` / `st_error` / `st_off` | label / ok / warn / error / muted | Status words and glyphs (`✓ ! ✗`) and temporary status messages |
| Selection | `sel_focus` | reverse + bold + secondary | Selected row in the focused panel |
| | `sel_unfocus` | reverse + bold + muted | Selected row in an unfocused panel |
| | `sel_marker` | secondary | The `▶` marker when no bar is drawn |
| | `scroll` | muted | `▲ ▼` and the `a-b/n` range text |
| Bars | `bar_fill` | primary | Filled cells, neutral state |
| | `bar_ok` / `bar_warn` / `bar_error` | ok / warn / error | Filled cells by state |
| | `bar_empty` | muted | Empty cells |
| | `bar_bracket` | muted | `[` and `]` around a bar |
| | `bar_head` | secondary | The animated head cell (`✿`) |
| | `bar_text` | terminal default | The percentage after the bar |
| | `spark` | secondary | Sparklines |
| Buttons | `btn` | primary | Button label in `[ Label ]` |
| | `btn_bracket` | muted | The brackets of a button |
| | `btn_focus` | reverse + bold + secondary | The focused button |
| | `btn_danger` | error + bold | A destructive button (`[ Delete ]`) |
| | `btn_off` | muted + dim | A disabled button |
| Inputs | `input` | terminal default | Text being typed |
| | `input_focus` | secondary + bold | The focused field's label or underline |
| | `input_hint` | muted | Placeholder / rule text (`1-60`) |
| | `input_error` | error | Validation message |
| Decoration | `petal` | secondary | Falling petals, blossom glyph animation |
| | `logo_*` | per 2.4.3 rule 5 | Logo parts (canopy, shadows, trunk, brand line, product line) |

Add a token only when an existing one cannot express the style. Never add a token for a single call site, and never add a *role* because a token is missing: re-map the token instead.

#### 2.5.3 Per-theme overrides (starting configuration)

A theme is **eight role colours plus optional surface metadata and at most about ten overrides**. Anything not listed uses the default mapping above. These are design proposals meant to make each theme feel distinct; tune them on a real display.

| Theme | Overrides (token -> role) | Intent |
|---|---|---|
| `hanakage` | none | Default Sakura-family identity palette; all defaults |
| `joyful-sea` | `border_dim` -> secondary; `bar_head` -> label | Bright frames, light-aqua sparkle on moving bars |
| `emerald-green` | `bar_fill` -> secondary; `hint_text` -> label | Fill is a deeper green than the lime `ok`, so neutral and success bars differ |
| `sunset-yellow` | `bar_fill` -> secondary; `btn_focus` -> reverse + bold + primary | Orange bars, golden focused buttons |
| `clean-white` | `border` -> muted; `border_dim` -> muted; `hint_text` -> muted; `bar_empty` -> muted + dim | Calmest: quiet frames, restrained hints |
| `aqualume` | `border` -> secondary; `sep_line` -> secondary; `bar_head` -> primary | Glassy mid-blue frames, bright aqua head |
| `violet-purple` | `border` -> secondary; `hint_text` -> label | Violet frames, orchid hints |
| `coffee-brown` | `border_dim` -> secondary; `hint_text` -> label; `bar_head` -> label | Warm tan dividers, cream hints and bar head |
| `kohaku` | `border` -> secondary; `hint_text` -> label; `bar_head` -> label | Soft red frames, white hints and bar head |

| `anta-baka` | `border_dim` -> secondary; `bar_head` -> label | Asuka red/orange, with gold accent and charcoal trunk |
| `soulless-moon` | `border` -> secondary; `hint_text` -> label | Icy blue and detached midnight tones |
| `calm-whisper` | `bar_head` -> secondary; `hint_text` -> label | Quiet cyan/blue body with a soft gold accent |
| `retro-bit` | `border` -> secondary; `bar_head` -> label | Arcade magenta/cyan contrast with purple accents |
| `darkly-rose` | `border` -> secondary; `hint_text` -> label | Crystal Rose hair, flower, eyes, outfit and clips on a dark surface |
| `lightly-rose` | `base_foreground` -> `#43469A`; `base_background` -> `#DBDDE2`; `sel_focus` surface -> `#F3EFC1` | Light Crystal Rose variant; keep body text and semantic states contrast-safe |
| `galactic-silence` | `border` -> secondary; `hint_text` -> label | Blue-forward Stargazer palette with nebula purple and muted burgundy |

Rules for overrides: an override changes **only colour or an attribute**, never a glyph, width or wording (2.4.3 rule 8); a state token (`st_*`, `bar_ok/warn/error`, `btn_danger`) may not be overridden to a colour that hides its meaning; every override must be listed in the theme test.

#### 2.5.4 How to use tokens (the rules for every screen and component)

1. **Ask for tokens, never raw colour values.** Components request a named token such as `title`, `border` or `bar_fill`; only the theme/token layer resolves it to concrete colours and attributes.
2. **Keep styling scoped.** Ensure a styled span cannot leak its style into following text; nested styling must restore the surrounding style correctly.
3. **Components choose tokens by state, not by colour.** A bar component takes a state (`ok`, `warn`, `error`, `neutral`) and uses `bar_ok/bar_warn/bar_error/bar_fill`. A button component takes a state (`normal`, `focus`, `danger`, `off`) and uses the matching `btn*` token. Never write `if theme == X` in a component.
4. **Text lines**: labels `label`, values `text`, secondary information `text_dim`, headings `heading`, hints `hint_key` + `hint_text`, status `st_*`. A line of text must never invent its own colour.
5. **Lines and borders**: the focused box uses `border`, other boxes `border_dim`; separators use `sep_line` + `sep_label`.
6. **Selection** always comes from `sel_focus` / `sel_unfocus`, never from a hand-built reverse-video string.
7. **Colour off** (environment preference, an app option where appropriate, or a terminal that cannot display colour): disable colour styling without losing readability. Keep selection markers, status words and component shapes.
8. **Adding a screen or component** means picking tokens from the table. If none fits, add a token (2.5.2) and give it a default mapping; all themes then follow automatically.

Language-neutral token-builder sketch:

```text
theme_apply(selected_theme):
    roles = theme_table[selected_theme]
    tokens = default_token_map(roles)
    apply_theme_specific_overrides(tokens, selected_theme)
    if colour_is_disabled:
        remove_colour_attributes(tokens)
    repaint_visible_ui()

render_progress_bar(percent, state, width):
    filled = round(percent * width / 100)
    fill_style = token_for_bar_state(state)
    return styled(filled_cells, fill_style) + styled(empty_cells, "bar_empty")
```

The chosen language and UI toolkit determine the concrete implementation. Do not copy shell syntax or require subprocess-based rendering.#### 2.5.5 Developer style gallery

Provide a developer-only screen or test fixture that shows every token, progress bars at 0/50/100 percent, focused and normal controls, selected and unselected rows, an input and status examples. It is a visual test tool, not a required user-facing screen or CLI flag. See 10.1.

#### 2.5.6 Token tests (add to 2.4.4)

- Every token is defined for every theme (after overrides).
- With colour off, every token is empty and the rendered text is identical to the coloured text with the codes stripped.
- Across themes the stripped output of every screen is byte-identical (tokens change colour only).
- The set of colour codes in a screen's output is a subset of the active theme's eight codes.
- The style gallery renders without errors in all twenty-five themes, including a light-surface rendering for `lightly-rose`.

---

## 3. Layout, panels and component patterns

### 3.1 The rendering model (Observed, reuse the behaviour)

1. Every screen is built as an **array of finished text lines** (colours included). Nothing is printed while building.
2. A single `paint` step writes the whole frame in one `printf`: cursor home, each line followed by "clear to end of line", then "clear below". This prevents flicker and leftover characters.
3. The app uses the terminal's **alternate screen** and hides the cursor, then restores both on exit.
4. **Never clear the whole screen on a normal key press** (that caused a visible black flash). Clear the whole screen only on resize or on the explicit refresh/redraw key.
   Theme changes and returning from Settings must still trigger a fresh frame from the updated state; invalidate theme-dependent colours/art without forcing a process restart. Use a targeted redraw where safe, and a full redraw when stale pixels/characters could remain.
5. Visible width is calculated after stripping colour codes, so padding and borders align even when lines contain colours.
6. Frame building must be fast (target well under 100 ms). The most expensive mistake found in practice was measuring text width with a slow pattern; use cheap literal replacement or your language's string width function.

### 3.2 Box and panel anatomy (Observed)

```text
╭─ ✿ Panel title ──────────────────────╮     top border, title after the blossom
│ content row                          │     content rows are padded to the inner width
├─ SECTION ─────────────── 1-12/20 ▼ ──┤     mid border: section name left, scroll hint right
│ ▶ selected row                       │
╰──────────────────────────────────────╯
 footer / hint text outside the box
```

- Corner and line characters: `╭ ╮ ╰ ╯ ─ │ ├ ┤` (ASCII fallback `+ - |`).
- The title always starts with the blossom glyph `✿` (ASCII `*`). A panel title may also carry its live semantic state inline—for example `GLOBAL · DISCONNECTED`—using both a readable status word and its semantic colour. Put the state in the title when it belongs to the panel as a whole; do not repeat the same state in a redundant extra row.
- Inner padding: one space inside the border on each side. Box width = terminal width unless the content is a text screen (then see 3.5).
- Section separator **inside** a list: `── LABEL ───────` in gray with the label in bold pink. It splits groups (for example "main items" and "sites") without a new box.

### 3.3 Information hierarchy and density

1. **Top:** identity and the most important state of the whole app (the "headline"). One or two lines of meaning, not a data dump.
2. **Middle:** the working area, split into **named panels** (2 columns when wide, stacked when narrow). Each panel owns one subject.
3. **Bottom:** use a single transient status-message slot when needed. Do not repeat the whole shortcut legend below the dashboard when a Hints box is already visible. Keep the rest of the bottom area empty unless the app has useful, live status content. Version/install information and uninstall guidance belong in Settings/About; the actual uninstall action belongs inside Settings.
4. A panel is made of: **summary rows** (a few headline values), then a **list or body**. Summary rows come first; detail lives one keypress away (Enter). A panel-wide state may be folded into its title (for example `GLOBAL · DISCONNECTED`) with semantic colour and a readable word; avoid duplicating the same status in a separate row.
5. When a panel has six headline metrics, a balanced **two-row by three-column** grid is a useful compact arrangement. Compute column widths from the current inner width and shorten labels at narrow sizes rather than clipping values.
6. Label/value pairs are `label` (cyan, fixed width) + `value`. Keep labels to one or two words.
7. Two row densities exist (Observed): **full** (two lines per item: line 1 name/state/value, line 2 a bar) and **compact** (one line per item). Choose full when there is vertical room for *all* items; otherwise compact with scrolling.
8. Scrolling shows a range indicator `a-b/n` and arrows `▲`/`▼` in the panel's mid border. Selection scrolls the window; the window "pulls back" to use spare room at the end.

### 3.4 Component patterns

| Component | Pattern |
|---|---|
| **Progress/meter bar** | `[` + filled `━` + empty `─` + `]` (thin line cells, standard since blueprint 1.2); brackets `bar_bracket`, filled part `bar_ok/warn/error/fill` by state, empty part `bar_empty`; ASCII `[####----]`. A percentage `NN%` or `N/A` follows. Width adapts to the row. Minimum width 3. **Thin means the filled/empty *cells* that show how full the bar is (for example 89 of 100 percent); the bar's overall length does not change.** **Observed:** NetScope and Downloader 12 still draw full-height `█` and light `░`; new and redesigned apps use the thin cells, and the change is made only in the glyph table (7.1). |
| **Button** (dialogs, prompts) | `[ Label ]`: brackets `btn_bracket`, label `btn`; focused `btn_focus` (reverse bar); destructive `btn_danger` and default focus on the safe button; disabled `btn_off`. Buttons are reached with `Tab`/`←`/`→` and activated with `Enter`; each also has a letter shortcut shown in the hint line. ASCII looks the same. |
| **Input field** | `label  value_` on one row: label `label`, typed text `input`, focused label `input_focus`, rule or placeholder `input_hint` (`1-60`), error `input_error` on the next line. Shortcuts are suspended while a field has focus (4.2 rule 7). |
| **Status word** | Fixed width (10), uppercase, state colour. Never invent a status without both a word and a colour. A state describing an entire panel may sit in its title (for example `GLOBAL · CONNECTED`); retain the text label as well as colour and avoid duplicating the same state in the summary body. |
| **Inactive group/list rows** | When an entire subsection is inactive, state `INACTIVE` once in its section heading. In each row, replace the repeated status word with a short dash placeholder, show unavailable measurements as `none`/`N/A`, and render an empty meter. Keep the section title and normal row alignment; do not gray the entire section heading or repeat `INACTIVE` on every line. |
| **Metric summary grid** | For six compact headline metrics, use two rows of three balanced columns. Derive each column width from the current panel's inner width; shorten labels at narrow breakpoints before values collide; preserve readable values and separators. This is a reusable pattern, not a fixed requirement for every app. |
| **Selected row** | Reverse video + bold + marker `▶` over the marker cell and the name cell (`sel_focus`); unselected rows have a blank marker cell, so alignment never shifts. The focused row uses `sel_focus` (rose in Sakura). An unfocused `sel_unfocus` marker is optional for independent lists; linked panels that form one logical list show only one active marker. If colours are off, the marker still shows. Full behaviour: 4.4. |
| **Sparkline** | Eight levels `▁▂▃▄▅▆▇█`, ASCII `. _ - = + * # @`. |
| **Animated progress** | A row of bar cells; the head cell is a rose `✿`; a petal stream (`✿`, `·`, `.`) drifts along a line above the content. Frame count increments per draw. |
| **Key hint** | `key` (bold pink, fixed width 6) + description (rose). |
| **Hints box** | A bordered box titled `Hints`, placed beside the main box on wide terminals. Use two balanced columns when the width allows it; group related shortcuts into sections and show every active shortcut exactly once. Section headings may be right-aligned with a continuous horizontal rule leading into the heading. Do not add a central vertical divider between hint columns unless the layout truly requires two independent panels; remove decorative dividers that make the hints look fragmented. Shorten labels without changing meaning (for example `refresh`, not `refresh/redraw`). On narrow terminals, use one compact column or a concise single-line hint only when necessary. When global theme cycling exists, the final Hints row may pair `< setting` on the left with `< Theme Name >` on the right; the current name updates live, and the raw `,` / `.` shortcut labels need not be repeated there. |
| **Status message** | One transient footer line for a few seconds (e.g. `Refreshing + redrawing...`); it may temporarily replace a contextual footer hint, but must not duplicate a visible Hints box. |
| **Separator** | `── LABEL ───` (see 3.2). Use the same visual separator for logical groups inside a Hints box. |
| **Balanced multi-column rows / grids** | Compute column widths from the available inner width at the current terminal size. Keep repeated panels and paired items aligned; use surplus width to widen useful content (for example a meter/bar or inter-column spacing) rather than compressing all content at the left and leaving an unexplained gap at the right. Recalculate on resize and test one exact-width and adjacent-width case. |
| **Empty / unknown** | Gray `-` or `N/A`; never leave a blank where a value belongs. |
| **Loading / warming up** | A word state (`WARMING UP`, `measuring...`) in a neutral colour with a bar at 0 or a moving blossom. |
| **Warning** | Yellow text with `!`; one line, says what and what to do. |
| **Error** | Red text with `✗`; says what failed, why if known, and the next step. |
| **Success** | Green `✓` plus a short sentence. |
| **Privacy / empty-state art** | The grove (trees of 3 sizes, fallen petals, centred title). Deterministic, so it never flickers. |

### 3.5 Text-style screens (settings, help, glossary, diagnostics, compact status views)

**Observed.** A generic framed screen: the content box can be capped at 110 columns (minimum 40 where the terminal permits); title `✿ <Screen>`; body lines inside; one gray footer line below the box with that screen's keys (for example `Up/Down select   Left/Right change   Enter edit/toggle   Esc back`). The body's first line is the screen heading in bold pink. In NetScope v1.0, Settings and Glossary deliberately use full-area layout; the Test Mirrors operation uses a compact, content-sized centred frame. This is evidence for choosing a policy by screen purpose, not a rule that every app must copy those exact screens.

**Required responsive placement rule:** every screen must explicitly choose one of two layout behaviours, and re-evaluate it from the current terminal size every time it draws:

- **Compact/content-sized screen:** for a small result panel or short operation view, calculate the frame from its useful content, cap it to the available terminal area, and centre it horizontally and vertically. Never leave a compact panel stuck in the top-left corner when the terminal becomes large or full-screen. Its contents and bars must be recomputed to fit the chosen width.
- **Full-area screen:** for the dashboard, long scrolling material, wide tables or screens whose purpose uses the available area, make the outer frame fill the usable terminal width and height. Resize its inner panels, columns, row budgets and footer positions with the terminal; don't merely stretch an outer border around a small top-left panel.

Pick one policy based on the screen's purpose and keep related screens consistent. Do not arbitrarily mix centered compact content and top-left compact content. A resize must recalculate centring, maximum dimensions, wrapping, scroll windows and all dependent caches. Test normal, wide/full-screen, short and narrow terminal sizes. Examples from NetScope such as a compact speed measurement view or a full-area list/details view illustrate layout patterns only; they do not prescribe which screens another app needs.

### 3.6 Terminal size behaviour (Observed thresholds; reuse the idea, set your own numbers)

| Condition | Behaviour |
|---|---|
| Width < 40 or height < 14 | Show `Terminal too small: need 40x14, have WxH` instead of the UI |
| Width ≥ 118 | Hints box beside the main box; use two grouped columns when there are enough shortcuts |
| Width ≥ 98 | Two main panels side by side; extra boxes side by side |
| Width < 98 | Panels stacked; extra boxes stacked or hidden when there is no room |
| Main box width ≥ 116 | Big logo |
| Main box width ≥ 96 | Small tree |
| Narrower | No tree, title text only |
| Not enough height for extra boxes | Hide them rather than squeezing the main panels |

**Rules for a new app:** decide a *minimum size*, one or two *breakpoints* and a *degradation order* (what disappears first). Hide decoration first, then secondary boxes, then show a "too small" message. Resize must trigger a re-read of the terminal size and a full redraw (NetScope originally failed to re-read the size on resize; this was a bug).

### 3.7 Choosing a layout for *your* content

Do not copy the dashboard grid. Use this decision table:

| Your content is… | Use | Example |
|---|---|---|
| Several parallel subjects of the same kind | **Named panels** side by side, same structure in each | Weather: panels `QUCHAN` and `JAPAN`, each with `TODAY` and `TOMORROW` rows (temperature, rain probability) |
| One live area plus status | **Play area + side/status panel + hints** | Game: board, score/level panel, controls hint panel |
| A list you act on | **List panel + details screen** (Enter) | Notes, downloads |
| A guided flow | **Stepper screens** with a footer showing Back/Next | Backup wizard |
| Mostly reading | **Text screen** (3.5) | Help, About |

Whatever you choose, keep: logo/title at the top, named panels with theme-coloured borders, a discoverable hints area, and one transient footer status slot. Do not fill otherwise empty dashboard space with a second copy of the same shortcut list.

### 3.8 Resizing: the complete method (standard since blueprint 1.2)

The goal: dragging the window edge, rotating a phone terminal, splitting a tmux pane or pressing `r` always leaves a correct, aligned screen within a quarter of a second. NetScope does this with a few lines; any app can.

**The six rules**

1. **A resize is an event, not a polling job.** Trap the resize signal (`SIGWINCH`; the equivalent event in other runtimes). The handler does **one thing**: set a flag (`RESIZED=1`). Never draw, measure or allocate inside the handler.
2. **The main loop owns the reaction.** The loop wakes at least every 0.25 s (a blocking read with a timeout, which a trapped signal also interrupts). When the flag is set it: clears the flag, **re-reads the terminal size**, **invalidates every cache that depends on size**, clears the whole screen once, and rebuilds the frame.
3. **Layout is a pure function of `(columns, rows, state)`.** One function (`compose_frame`) builds every line from the current width and height and nothing else. No widths stored in constants, no widths computed once at start-up. (The original NetScope bug: the size was read once at start-up, so a resize broke the layout. Never read the size only once.)
4. **Breakpoints and a degradation order** are data, not scattered `if`s: a table of minimum widths and heights and what appears at each (3.6). Order of loss: decoration (logo, art), then secondary boxes, then spacing, then a single "terminal too small" message.
5. **Every screen re-reads the size.** Sub-screens (settings, details, help) call the size reader each time they draw, so a resize inside them is handled too.
6. **Register resize handling before the first interactive screen.** The first-run installer/Requirements chooser is a screen too. Install the `SIGWINCH`/resize-event handler before opening it, not after the installation choice returns. Its input loop must consume the resize flag and redraw on the next event-loop wake without requiring an arrow key or any other user input. Apply the same rule when `--install-mode` opens the chooser later. The installer chooser must also compare the actual current `(columns, rows)` with the last painted size after each input wait; this polling fallback catches a missed/delayed resize signal. A new keypress must never be the trigger that finally notices a resize.

**What must be invalidated on resize:** deterministic art keyed by size (the grove), cached column widths, scroll offsets (re-clamp so the selection stays visible), any pre-built frame, and the "last painted lines" buffer if you diff frames.

**Why the full clear:** a normal frame overwrites each line and clears to the end of line and below; after a resize old characters can survive in places the new frame does not reach (a shorter line, a moved border). Clear once on resize and on the manual refresh key `r`; **never on an ordinary key press** (that causes a black flash).

**Safety nets (Recommended):** keep `r` as a manual "refresh + redraw UI" key (Observed); also re-read the size periodically and treat a change as a resize, because some multiplexers and remote terminals drop or delay the signal (not Observed in NetScope). For an installer chooser, perform this comparison after each short input wait, so redraw latency is bounded by the wait interval and never depends on another keypress.

**Language-neutral resize flow**

```text
on_resize_event:
    set resized = true

main_loop:
    wait_for_input_or_background_event()
    if resized:
        resized = false
        size = read_current_terminal_size()
        invalidate_size_dependent_caches()
        clear_screen_once()
        needs_redraw = true
    if needs_redraw:
        frame = compose_frame(size, current_state)
        paint(frame)
    process_input_and_background_results()
```

The signal/event handler only marks the UI dirty; normal application code handles layout and rendering.

**Resize checklist for a new app**

- [ ] Resize trap sets a flag only; the loop does the work
- [ ] Size re-read on resize, on `r`, and at every sub-screen draw
- [ ] `compose_frame(cols, rows, state)` is pure and has a documented breakpoint table
- [ ] Caches keyed by size are invalidated; selection is re-clamped
- [ ] One full clear on resize and `r`, never on normal keys
- [ ] Too-small message below the minimum size; no crash, no garbage
- [ ] Resize while the first-run installer/Requirements chooser is open; verify it redraws at the new size without pressing a key
- [ ] Repeat the installer resize test for `--install-mode` and for other sub-screens
- [ ] Tested with a pseudo-terminal: change size mid-run, assert the new frame has no line wider than the new width and the same logical content

---

## 4. Menu structure and navigation

### 4.1 Observed key map (NetScope), shown only as an example of the *pattern*

| Key | Action in NetScope | Pattern to reuse |
|---|---|---|
| `q` | Quit | Always quit from the main screen |
| `r` | Refresh data **and** clear and redraw the UI | `r` = refresh + repair the display |
| `p` | Pause / resume | Optional, only for live apps |
| `Tab`, `←`, `→` | Switch focused panel | Panel switching |
| `↑`, `↓` | Move selection | Selection |
| `Enter` (also `d`) | Details of the selected item | Drill down |
| `s` | Settings | Settings |
| `g` | Diagnostics | Diagnostics-like screen |
| `t` | Speed test | App-specific action (do not reuse) |
| `k` | Glossary | Help-like reference screen |
| `x` | Privacy mode | Mode toggle |
| `+` / `-` | Refresh interval | App-specific adjustment |
| `Esc` / `q` | Back from a sub-screen | Back |

`h/j/k/l` vim keys were removed because `k` became the glossary. Lesson: **decide your key map first and never give one key two meanings.**

### 4.2 Rules

1. **Universal keys** (keep in every Sakura app): `q` quit (main), `Esc` back (sub-screens), `Enter` confirm/open, arrows select, `Tab` switch panel, `r` refresh/redraw, `s` settings. Add `?` or `h` for help only if you do not use them otherwise.
2. **App keys** are mnemonic letters chosen for *your* sections. Build a table first (key, section, meaning), check for conflicts, then code.
3. **Single source of truth:** keep one table of keys → label → handler. Draw the hints box from it. (**Observed:** NetScope keeps the hint text in one array and the key handling in a separate `case`, so they can drift; do better.)
4. **Entering and leaving:** a section opens full screen with its own footer keys. `Esc` (and `q` or the opening key again) returns to the previous screen and restores selection. Returning never loses the main screen's state.
5. **Confirm / cancel:** destructive actions ask `[y/N]` with **No** as the default; harmless confirmations may default to Yes. `Esc` cancels any prompt.
6. **Scrolling screens:** `↑/↓` line, `PgUp/PgDn` page, `Home/End` ends, `Space` page down; footer states this.
7. **Text fields:** when a text value is being edited, **all shortcut keys are suspended** and typed characters go into the field. `Enter` accepts and `Esc` cancels (Recommended). (Observed: NetScope edits settings text on the bottom row with a readline prompt pre-filled with the current value, so shortcuts are not interpreted while typing; `Enter` accepts, but only end-of-input such as Ctrl-D cancels, and `Esc` does **not**. Make `Esc` cancel in new apps and show the validation rule.)
8. **Discoverability:** every active key appears exactly once in the current hints area; sub-screens show their own context-specific keys only when needed; a glossary/help screen explains terms. Hints must be **generated from the same key table** the handler uses. When width allows, split hints into two balanced columns and separate logical groups with horizontal rules. Do not duplicate the same shortcut legend as a permanent line along the bottom.
9. **Mode toggles** (like privacy) show a status message when switched (`privacy mode ON`) and are visible in the UI afterwards.
10. **Non-interactive use:** if the product benefits from automation or piping, provide a useful non-interactive mode and clear help/version information. These are product-specific conveniences, not mandatory TUI flags; never start an interactive screen when no interactive terminal is available.
11. **Global theme cycling:** for TUIs that expose the shared theme chooser, reserve `,` for previous theme and `.` for next theme. Handle both through the central key reader on the dashboard and all non-text-input screens; changing theme updates the active screen immediately and saves the preference. Suspend these global punctuation shortcuts while a text input/editor owns focus. The Hints box may communicate the control with the live carousel `< Theme Name >` instead of duplicating the raw shortcut text.

### 4.4 Selecting items and opening the details screen (standard since blueprint 1.2)

Every Sakura app that shows a list uses this model. It is what makes moving through a list feel clear: the user always knows which item is selected, which panel has the keyboard, and what `Enter` will do.

**The model (Observed in NetScope as an example of the pattern)**

| Piece | Behaviour |
|---|---|
| Per-list state | `sel` (selected index) and `off` (first visible index) are stored per list/panel, so each panel remembers its last position |
| Focus | One panel owns the keyboard (`FOCUS`); `Tab`, `←`, `→` switch panels. Preserve one active selection marker across panels that represent one logical combined list; do not show a second active marker in an unfocused panel |
| Move | `↑`/`↓` move by one. For linked panels that form one logical sequence, crossing the end of one panel moves to the first item of the next (for example GLOBAL last → INSIDE first), and reverse crossing works too; clamp at the two outer ends. For genuinely independent lists, keep movement within the focused list. **Recommended:** `Home`/`End` and `PgUp`/`PgDn` for long lists |
| Selection bar | The active row is a solid reverse-video bar with the `▶` marker (`sel_focus`). In a linked-panel model, the unfocused panel has no active marker; in independent-panel models, a muted `sel_unfocus` marker may remain if it communicates useful context. |
| Scrolling window | Only as many rows as fit are shown. Moving the selection past an edge slides the window; when the end is reached the window "pulls back" to fill spare room. A range text `a-b/n` and arrows `▲ ▼` sit in the panel's middle border (`scroll`) |
| Group separators | A separator line (`── SITES ──`) counts as a row in the window arithmetic, and is repeated at the top if the window starts inside that group |
| Details | `Enter` opens a full-screen details screen for the item selected in the focused panel. If the list is empty, `Enter` does nothing |
| Return | Leaving details returns to the same focused panel with the same selection and scroll position |

**The details screen (pattern)**

- A framed screen (3.5) titled with the item name and its group in muted text, for example `<Item name>  (<Panel> <group>)`.
- Body, top to bottom: identity fields (label/value), a blank line, **state** (status word in its state token), **metrics** (numbers the row could not hold), then a **history strip** or similar small visual.
- **Live:** it redraws about twice a second while open, and background work keeps running, so numbers keep moving.
- **Observed:** *any* key returns in NetScope. **Recommended:** `Esc`, `q` and `Enter` return, other keys are ignored, and the footer says so.
- It shows data only. Destructive actions are never bound to `Enter` on a list; they need an explicit confirmation screen with the safe button focused (3.4, Button).

**The window arithmetic (language-neutral)**

```text
inputs:  n items, unit = lines per item (1 compact, 2 full), budget = lines available,
         sel, off, separator_row = index where a group starts (or none)
rows_needed(i, off) = unit + (1 if a separator is drawn before item i)      # drawn at the group start, or at off if off is inside the group
window(off)         = how many items from off fit in budget
loop:  off = min(off, sel)                       # selection above the window: move up
       while sel >= off + window(off): off += 1  # selection below the window: slide
       while off > 0 and off-1 + window(off-1) >= n: off -= 1   # spare room at the end: pull back
build only the rows off .. off+window(off)-1     # never build rows that are not visible
```

**Rules for a new app**

1. Build one reusable **list component** with this state and behaviour; every list in the app uses it.
2. Decide whether panels are independent lists or segments of one logical list. For linked segments, keep one active marker and let Up/Down cross segment boundaries; for independent lists, movement stays in the focused list.
3. Identify items by a **stable id**, not by position, when the list can reorder or refresh; after a refresh keep the same item selected (NetScope's lists are static, so it does not need this; yours may).
4. Show `Enter details` and `Up Dn select item` in the hints (generated from the key table, 4.2).
5. The empty list shows a muted `No items` row and disables `Enter`.
6. The details content is **your domain's data**; only the frame, typography and keys are shared. Do not copy another app's fields.
7. Test: arrow through the whole list at three heights, assert the selected row is always visible, the range text is correct, `Enter` opens the right item and returning restores focus, selection and scroll. For linked panels, test both cross-panel directions and assert there is only one active selection marker.

---

## 5. Settings, help, details and supporting screens

Decide screens by user need. **Do not add a screen just because NetScope has one.**

| Screen | Add it when… | Sakura style |
|---|---|---|
| **Settings** | The app has preferences | One selectable list grouped by app-specific, meaningful section headings; each row is `label  value`; selected row has `▶` and bold label; enabled/active values use `ok`, inactive/unknown values use `muted`; `Left/Right` change, `Enter` edits/toggles/opens an explicit action, and `Esc` returns. Validate and persist changes safely. Put version/install/uninstall guidance and the config path outside the selectable rows, below or beside the frame, not on the dashboard. In privacy mode shorten home paths. |
| **Appearance** | Always (standard since blueprint 1.1) | Rows `Theme` (cycle with Left/Right, live preview with four colour chips; see 2.4) and `ASCII mode` (`auto`/`on`/`off`) in a section named `APPEARANCE`. Both are saved (`theme=`, `ascii=`) |
| **Uninstall** (section of Settings) | Always (since blueprint 1.1) | Section `UNINSTALL`, one row `Uninstall Sakura <Product>`; `Enter` starts the shared uninstaller (9.2, "Uninstall entry points"), which lists the files and asks with default **No**. It is the only in-app way to remove the app |
| **Version / install info** | Always | Show the exact form `sakura-<product> version <x.y.z>` using the single `VERSION` constant shared by `--version`, About and update checks. Also show the active installation mode (`System-wide`, `Local`, or `Demo mode`) and a concise `How to uninstall` hint. These informational lines sit inside the Settings screen but outside the selectable settings-options frame, using the same muted/pink style; do not make them selectable options or repeat them on the main dashboard. The uninstall action itself remains a selectable `Uninstall Sakura <Product>` row inside Settings |
| **Privacy** (section of Settings) | The app shows personal or environment data (6.2) | Section `PRIVACY` with one row per sensitive class (`Hide <class>  on/off`) and a row `Privacy key hides  all/selected`; the `x` key toggles the chosen classes live |
| **Shortcut reference** | More than ~6 keys | The hints box *is* the reference; add a screen only if keys exceed the box |
| **Help / usage** | Always | `--help` text from the script header; keep it in sync with the real flags |
| **Glossary** | The domain has jargon | Scrollable framed screen: `#HEADING` lines in bold pink, terms in bold cyan, short plain-language explanations wrapped and indented two spaces; scroll position in the title `(a-b of N)`. Put a blank line and a consistent separator between entries; leave extra vertical space between categories so each term is easy to scan. Keep definitions concise and beginner-friendly without changing their meaning. Add entries for new user-facing features/terms and update/remove stale entries when behaviour changes. Never copy NetScope domain terms into another app. |
| **About / version** | Always (can be a section of Help) | Logo, display name, version, tagline, licence line, config and install paths |
| **Diagnostics** | The app depends on external tools or the environment | One screen listing each dependency with `✓` green or `✗` yellow, the path, what it is for and how to install it; plus terminal size, glyph mode and `TERM` |
| **Details** | Items have more data than a row can show | Opened with `Enter`, framed screen titled with the item name and its group; refreshes while open; `Esc` back |
| **Logs** | The app produces events worth reading | A scrollable screen with the newest line at the bottom; never log secrets |

Settings conventions for new apps:
- Group related settings under short, easy-to-read headings (for example `APPEARANCE`, `BEHAVIOUR`, `SCHEDULE`, `STORAGE`, or `APPLICATION`); choose groups for the actual app, not NetScope's categories.
- Make the selection and interaction model obvious: Up/Down selects a row; Left/Right changes a value; Enter toggles, edits a value or opens a clearly indicated action; Esc cancels editing or returns. When editing text, suspend app shortcuts until commit/cancel. Show valid ranges and a short validation error; never silently accept invalid input.
- Save changes atomically with restrictive permissions for private settings. Preserve unknown/future keys when practical. Do not make a setting selectable if it is merely informational.
- Keep the Appearance group beside the first screen-relevant settings; Theme live-preview invalidates theme-dependent frames/art, and ASCII mode redraws glyph-dependent elements immediately.
- Use readable, consistent dividers. Prefer safe ASCII separators (`--- SECTION ---`) if decorative dashes are corrupted by encoding/font issues. Avoid random long replacement-character sequences.
- Keep Settings proportional to the app: do not copy NetScope's monitoring, routing, scan or uninstall details as product settings. Only include meaningful preferences for the user's requested app. Remove temporary developer/test controls from normal UI before release.
- Show version, active installation mode and concise uninstall instructions as read-only metadata outside the selectable list. The actual uninstall action remains a dedicated Settings row.

Settings values: validate every numeric setting with a min and max; unknown or invalid values fall back to the default without crashing.

Privacy-sensitive values (credentials, addresses, home paths) are masked in screens when a privacy mode is on, and credentials are never displayed at all (Observed: `(credentials hidden)`).

---

## 6. Branded screens and privacy

### 6.2 How to add privacy to any part of an app (standard since blueprint 1.2)

Use this when the owner asks for privacy on a section, a screen or the whole app. The method has nothing to do with what the app does.

**Step 1: inventory.** List every place the app can show something sensitive and give each a **class**:

| Class (examples) | Typical values |
|---|---|
| `identity` | names, emails, account ids, usernames |
| `location` | addresses, coordinates, place names, time zone |
| `network` | IP addresses, Wi-Fi names, hostnames, device names |
| `paths` | home directory, file names with a username |
| `secrets` | tokens, passwords, keys (see rule 3) |
| `content` | the user's own text, files or messages shown on screen |

**Step 2: one redaction layer.** All sensitive text goes through one function, for example `show <class> <value>`. When privacy is on for that class it returns a mask; otherwise the value. No screen formats a sensitive value by itself.

| Mask style | Use for | Example |
|---|---|---|
| Replace | most values | `hidden` or `********` |
| Shorten | paths | `/home/alex/notes` -> `~/notes` |
| Keep shape, drop value | when the layout needs a width | `••••••••` (ASCII `********`) |

Partial masks (`192.168.•.•`) still leak structure; use them only if the owner agrees.

**Step 3: three levels of scope.**

1. **Value** level: the field shows a mask (default for single values).
2. **Panel/box** level: the whole box is replaced by a **masked box of identical width and height** (title kept, content replaced by the grove or a muted privacy illustration). Use it when the box is mostly sensitive. Pre-build the art for the size and cache it (12.12). When the title already says `Privacy Mode`, do not repeat that text over the centre of the illustration; let the deterministic grove/empty-state art occupy the centre without a duplicate message.
3. **Screen/app** level: every class is on.

Settings > `PRIVACY` lets the user choose which classes the privacy key affects; the key `x` toggles exactly those classes at once, live.

**Step 4: cover every surface.** The same value can appear in many places; check all of them: main screen, details, settings, diagnostics, logs, error and status messages, non-interactive/export output (if supported), window title, install/uninstall messages, backup file names, copied text. Mask the **value**, keep the **message** useful (`cannot reach <hidden>`, not a blank line).

**Rules**

1. Privacy is **off by default** and is **not saved** unless the owner asks (Recommended optional setting `privacy_default`). Flag `--privacy` and environment variable `<PREFIX>_PRIVACY=1` start with it on.
2. It must be **visible when on**: a status message when toggled and a short tag in the footer (`privacy on`).
3. **Secrets are never printed**, privacy on or off. Show `set` / `not set`, or reveal for a few seconds on an explicit key and then mask again.
4. Masked and unmasked boxes have **identical dimensions**; toggling must not move other parts of the screen.
5. Changing the privacy state **invalidates cached frames and art** and redraws; it does not restart anything. Any mode or theme change that changes visible art/colours must follow the same rule, including when the user returns from Settings to an underlying privacy/empty-state screen.
6. Privacy changes only what is *shown*; it must not change what is stored, sent or logged to disk. Log files follow the same classes (do not log secrets, mask on request).

**Test (required).** Seed the app with known sensitive values for each class, turn privacy on, open every screen and one-shot output, strip colour codes, and assert **zero occurrences** of any seeded value. Then assert masked and normal boxes have the same line count and width.



---

## 7. Unicode, box drawing and ASCII mode

### 7.1 Observed behaviour

- Mode is **auto**: Unicode when the locale charmap is UTF-8 and `TERM` is not `linux`; otherwise ASCII. `--ascii` forces ASCII and a saved setting `ascii=0|1|-1` (`-1` = auto) can be changed in Settings. Switching refreshes the glyph variables immediately.
- All glyphs come from one function that sets a **glyph table**:

| Glyph role | Unicode | ASCII |
|---|---|---|
| Corners / lines | `╭ ╮ ╰ ╯ ─ │ ├ ┤` | `+ - |` |
| Bar filled / empty | `━ ─` (thin line cells, standard since blueprint 1.2; older apps used `█ ░`) | `# -` |
| OK / bad / warn / unknown | `✓ ✗ ! ?` | `+ x ! ?` |
| Dot | `·` | `.` |
| Scroll up / down | `▲ ▼` | `^ v` |
| Selection marker | `▶` | `>` |
| Blossom | `✿` | `*` |
| Sparkline | `▁…█` | `. _ - = + * # @` |

- The logo and the grove use ASCII characters only, so they are identical in both modes.

### 7.2 Known gaps (Observed, so do not copy them)

A **complete** ASCII mode does not exist in NetScope. The install/uninstall text still prints `•` bullets and `—` dashes, and a few messages and glossary strings contain non-ASCII characters. Treat that as a flaw.

### 7.3 What a new app must do

1. Put **every** non-ASCII character behind a glyph table with an ASCII twin. That includes bullets, arrows, dashes, ellipses, check marks, spinners, sparklines, progress cells and decorative symbols. Message text should use plain ASCII punctuation (`-`, `...`) in both modes unless it goes through the table.
2. Keep Unicode **single-width** only. Avoid emoji and East-Asian-ambiguous symbols where a plain alternative exists (`▶` and `✿` are used in NetScope, and their width was **not verified** across fonts; if a terminal draws them double-width, the ASCII mode is the remedy).
3. Add a `--ascii` flag, a settings toggle, auto-detection and a `NO_COLOR`/`--no-color` path.
   Progress-bar cells are part of the glyph table: Unicode `━` (filled) and `─` (empty) are single-width box-drawing characters (the same family as the borders), ASCII `#` and `-`. **Observed:** the two bar glyphs live in the glyph-init function (`BAR_FULL`, `BAR_EMPTY`), so making existing apps thinner is a two-line change there. Width of these glyphs in every font is **Unknown** (section 15).
4. **Alignment test (required):** render every screen at several sizes in both modes and assert:
   - after stripping colour codes, every line has the same visible width as its box border in the same mode;
   - no line exceeds the terminal width;
   - replacing each Unicode glyph by its ASCII twin turns the Unicode frame into the ASCII frame exactly (same line count, same widths).
   A simple harness: run the app's one-shot mode with forced `--cols N --rows M` in both modes, strip `ESC[...m`, and compare line lengths.

---

## 8. Responsive behaviour, compatibility and accessibility

- **Keyboard only.** Every action has a key. No mouse is required or used.
- **Resize.** Follow the complete method in 3.8: flag in the signal handler, re-read size in the main loop, invalidate size-dependent caches, one full clear, rebuild a pure `compose_frame`; `r` is the manual fix.
- **Smoothness.** Keep the frame budget and the no-fork rules of 12.12.
- **Terminal types.** Support: UTF-8 terminals, the Linux console (ASCII), `dumb` terminals and pipes (no colour, no cursor control; use one-shot mode). Colour assumes 256 colours (Observed); a 16-colour fallback is **Recommended**.
- **Readable spacing.** One blank cell inside borders, labels aligned in columns, no more than ~110 columns for text screens, separators instead of extra boxes.
- **Do not depend on colour** (see 2.2) and avoid blinking or fast flashing. Animation is gentle (about 10 frames per second at most) and can always be cancelled with `q` or `Esc`.
- **Focus** is always visible (selected row + panel border emphasis).
- **Non-terminal apps.** If the product has a GUI or web UI, keep the *identity* (name pattern, pink/rose accents with the same semantic colours, ✿ in titles, tree logo on first-run and About, named panels with thin rounded borders, short hints, the same installer choices) and use native widgets for the rest. Do not draw ASCII boxes inside a GUI. Reuse the theme table by converting the eight roles to CSS custom properties or native colour resources (hex values in 2.4.2), keep the same role names, and offer the same twenty-five themes in the app's settings.

---

## 9. First-run experience and installation choice (REQUIRED for every Sakura app)

### 9.1 Evidence from previous and current reference versions

- Earlier reference-app versions used flat paths such as `~/.local/bin/<command>` and `${XDG_CONFIG_HOME:-~/.config}/<command>/`.
- **Observed in NetScope v1.9.3 and stable v1.0:** per-user config is `${XDG_CONFIG_HOME:-~/.config}/SakuraSuit/sakura_netscope/`, with settings, install mode and optional provider/speed-test files. The Local executable is stored under `~/.local/bin/sakurasuit/`, with a compatibility launcher at `~/.local/bin/sakura-netscope`; the reference implementation remains a single-file payload rather than the nested multi-file bundle prescribed for future apps.
- NetScope v1.0 has Demo, Local and System-wide modes, version-aware updates, a Requirements panel with three dependency tiers, a per-user desktop entry for Local installs, a system desktop entry, config migration that avoids overwriting files already in the new directory, and confirmation-based uninstall. It also registers terminal resize handling before the first-run installer chooser. The reference app is a useful behaviour example, but its single-file packaging and other implementation-specific choices do **not** replace the family bundle contract below.
- The rules below are the **required owner-approved family standard for new apps and future installer revisions**. Where they differ from current NetScope, follow this section rather than copying the current code literally.

### 9.2 Required behaviour for new Sakura apps

> **Owner decision:** keep the first-run choice between Demo / Local / System-wide, remember the choice when appropriate, provide `--install-mode` where a command interface exists, and do not install anything before the user chooses. Preserve the shared install/uninstall experience unless the owner explicitly changes it.

On the first interactive launch from an uninstalled source, show the logo and three explicit options before installing or modifying anything. A copy already installed by a recognised system package manager should not launch a second self-installer or ask each user to reinstall it.

| # | Choice | What it does | Needs elevation? |
|---|---|---|---|
| 1 | **System-wide install** | Makes the app available to every user, puts its payload and assets in the system install root, adds a terminal command and desktop entry, and installs its custom icon into the system icon tree where supported. Each user's settings remain in that user's SakuraSuit config directory. | Yes, only for the listed system files; explain before the password prompt |
| 2 | **Local install** | Installs only for the current user: app bundle, command launcher, desktop entry and optional custom icon. No administrator access. | No |
| 3 | **Demo mode** | Runs from the supplied source/package without installing the executable, command launcher, desktop entry or icon and without system-wide changes. If the app explicitly needs persistent demo state, place it only in the per-app `demo/` subfolder under the SakuraSuit config namespace and disclose that; otherwise create nothing persistent. | No |

`q` / `Esc` cancels and exits without changes. Demo should be the default highlighted choice, and the user must explicitly confirm with Enter.

#### 9.2.1 Canonical names and per-user config paths

Every app defines two different names: `<command>` (hyphenated command such as `sakura-timer`) and `<app-id>` (underscored directory such as `sakura_timer`). Use the following per-user location as the shared family convention:

```text
${XDG_CONFIG_HOME:-~/.config}/SakuraSuit/<app-id>/
    settings.conf       # saved preferences
    install.conf        # per-user remembered choice, if needed
    ...                 # app-specific editable config
    cache/              # only when persistent cache is useful
    demo/               # only if Demo needs persistent demo-only state
```

- Keep all app-owned persistent configuration and any deliberately co-located app cache/demo subfolders within this per-app namespace. Never create generic siblings such as `~/.config/sakura-timer/` or shared files named `sakura_*` directly under `~/.config/`.
- Temporary one-run data may use `${TMPDIR:-/tmp}/sakurasuit-<app-id>.XXXXXX` or an appropriate runtime directory, but must be private, cleaned on every exit path, and never mistaken for saved user data.
- Apply restrictive permissions (`umask 077` or equivalent) to private config/state. Quote paths and honour `XDG_CONFIG_HOME`.
- During migration, copy old config files only when the destination file does not already exist. Never overwrite new settings with an older file. Keep the old directory until the user has verified migration or until an explicit cleanup choice; don't silently destroy old settings.
- For System-wide installs, program files are shared but user settings are not. Never write one user's preferences or personal data under `/opt`, `/usr/local`, `/usr/share`, or another shared system path.

#### 9.2.2 Local installation layout (required)

Use this layout; it keeps all app payloads in a per-app folder while preserving a short command users can type in the terminal:

```text
~/.local/bin/<command>                              # symlink/launcher on PATH
~/.local/bin/sakurasuit/<app-id>/                    # actual app bundle
    <entry-point>                                    # .sh script or compiled binary
    <app-id>.png | .jpg | .ico                      # selected custom icon, if found
    ...                                              # app-owned runtime assets
${XDG_DATA_HOME:-~/.local/share}/applications/<desktop-id>.desktop  # menu entry
${XDG_CONFIG_HOME:-~/.config}/SakuraSuit/<app-id>/                  # settings/config/cache/demo
```

- `~/.local/bin/<command>` must invoke the per-app bundle reliably. Prefer a symlink where suitable; otherwise use a tiny, well-tested launcher. The real program and its assets stay in `~/.local/bin/sakurasuit/<app-id>/`.
- The `.desktop` file goes in `${XDG_DATA_HOME:-~/.local/share}/applications/`, uses the correct `Exec` entry point, uses `Terminal=true` for a TUI/CLI launcher and appropriate categories, and references the installed icon—not the original source tree.
- The selected custom icon is copied into the same per-app bundle. A desktop entry may use its absolute installed path (`Icon=/.../sakura_timer.png`), or an installed icon-theme name if that is appropriate and tested.
- Do not create a separate desktop uninstall action. The only uninstall entry points are those listed below.

#### 9.2.3 Standalone System-wide installation layout (required)

For a self-installing app that is **not being installed by a native OS package manager**, keep the complete payload in an app-owned `/opt` tree and create standard front-end entries. `/opt` is the FHS location for add-on application software, while `/usr/local` is reserved for software installed locally by the system administrator ([FHS `/opt`](https://specifications.freedesktop.org/fhs/latest/opt.html), [FHS `/usr/local`](https://specifications.freedesktop.org/fhs/latest-single/)). This avoids manually overwriting files owned by the OS package manager.

```text
/opt/sakurasuit/<app-id>/                            # payload owned by this app
    <entry-point>
    ...                                              # app assets and bundle copy of icon
/usr/local/bin/<command>                             # symlink/launcher for all users
/usr/local/share/applications/<desktop-id>.desktop  # system menu entry
/usr/local/share/icons/hicolor/<size>/apps/<app-id>.<ext>  # custom icon, if found
~/.config/SakuraSuit/<app-id>/                       # separate per-user config
```

- Put only this app's files under `/opt/sakurasuit/<app-id>/`. Make `<command>` available through `/usr/local/bin/<command>` so all users can launch it from a normal shell. Do not put per-app executable payloads directly into one crowded shared `/usr/local/bin` directory.
- Put the system desktop entry under `/usr/local/share/applications/` and custom icon(s) under `/usr/local/share/icons/hicolor/` in a size directory appropriate to the actual image. The entry must invoke the public command or its stable installed path and reference the installed icon. Do not point it at the original source tree or an individual user's home directory.
- Remove only the exact command link/launcher, bundle directory, desktop entry and icon files recorded as installed by this app. Refresh the desktop database/icon cache when the relevant utility is available; failure to refresh should be reported or safely ignored, not cause unrelated files to be removed.
- **Native package-manager exception:** if the project also ships a `.deb`, RPM, Arch package, or another native package, its manifest may place files in the distribution's ordinary package-owned locations (such as `/usr/bin`, `/usr/share/applications`, `/usr/share/icons`). Package-manager installation and removal must be owned by that package manager; do not let the self-installer delete package-owned files. Never overwrite `/usr/bin` or `/usr/share` manually when a native package has not claimed those paths.
- Use elevation only for the files listed above. Explain which files will be installed before calling `sudo`/`pkexec`; never run the entire app as root just because installation needs elevation.

#### 9.2.4 Automatic custom-icon selection and installation

1. During installation, inspect the source/package directory (and only explicit asset directories) for exact matches using the naming rules in 1.4. For a script named `sakura_timer.sh`, a sibling `sakura_timer.png`, `sakura_timer.jpg` or `sakura_timer.ico` is a valid match.
2. Copy the selected icon into the Local or System-wide app bundle. For System-wide mode, also install it in the standard icon-theme tree. The icon-theme format list is narrower than the discovery list: the [freedesktop Icon Theme Specification](https://specifications.freedesktop.org/icon-theme/) uses PNG, XPM and SVG (SVG support is optional), and recommends PNG. Therefore, place a discovered PNG in at least `hicolor/48x48/apps/` (and optionally other suitable sizes). For `.ico` or `.jpg`, keep the original in the app bundle and copy it to the system icon directory if requested, but do not assume icon-name theme lookup will find it.
3. Use the installed asset path/name in the desktop entry. The [Desktop Entry Specification](https://specifications.freedesktop.org/desktop-entry/latest-single/) allows `Icon` to be an absolute path or an icon-theme name. For `.ico`/`.jpg`, prefer an absolute path to the installed file if the target desktop's loader supports it; otherwise convert to PNG only when an already-installed converter is available, or use the stock fallback. Do not silently install conversion tools.
4. If no matching image exists, use the stock icon selected in the identity block. Never invent a custom icon or search unrelated folders.
5. Remember which icon files were installed so uninstall removes exactly those files. Do not delete other sizes, stock theme assets, or a same-named icon that predated this installation.

#### 9.2.5 Remembering the choice and repeat launches

1. After a choice, show a clear result (`✓ installed` or `✗ failed` with the reason) before continuing.
2. Where a per-user remembered mode is useful, store it as `mode=system|local|demo` in `${XDG_CONFIG_HOME:-~/.config}/SakuraSuit/<app-id>/install.conf`. Remembering Demo is optional; ask `Remember this choice? [y/N]` and create the `demo/` folder only if required.
3. When the user later invokes `<command> --install-mode`, reopen the chooser. Optional explicit controls such as `--demo`, `--local`, and `--system` may be provided for scripting.
4. If a command resolves to a known installed bundle, detect that actual installation from its canonical path/manifest before prompting. A system-wide install must remain usable by other users who have not separately run the installer; do not mistake their absent per-user `install.conf` for an uninstalled application.
5. Non-interactive launches never show an installation prompt. When running from an uninstalled source with no TTY, behave as Demo and explain how to install interactively if relevant.
6. Do not silently install dependencies. Missing optional tools degrade gracefully; required dependencies are reported clearly.

#### 9.2.6 Safe update rules

- Use the app's semantic `VERSION` as the single update source, not only file modification times.
- Replace an installed bundle only when the new version is newer, unless the user explicitly asks for a downgrade. Report when the source is older than the installed version.
- Copy to a temporary sibling in the target bundle, verify that it can run/report the expected version, then atomically rename it into place. Preserve the old working install if any step fails. For a multi-file bundle, stage the complete new bundle and switch it atomically where feasible; do not partially replace files while the program is in use.
- Update the bundle, launcher, desktop entry and icon as one tracked install transaction. If one critical step fails, roll back to the previous install and clean staged files. Existing settings and user data must not be overwritten by an app update.

#### 9.2.7 Uninstall entry points: exactly two

Use one shared uninstaller with these entry points where they apply:

1. If the app provides a command entry point: `<command> --uninstall`.
2. Inside the app: **Settings > UNINSTALL**. The `Uninstall Sakura <Product>` row invokes the same uninstaller (same file list, questions and defaults).

A GUI-only app need not invent a terminal command. Do not add a desktop-menu uninstall action, separate uninstall script, keyboard shortcut that uninstalls, or automatic cleanup on exit. Keep uninstall guidance in Settings/About, not on the permanent main screen.

#### 9.2.8 Uninstall safety and cleanup

- Show the exact list of owned files that will be removed; ask for confirmation with **No** as default.
- Offer a backup of the actual installed entry point before removal (default Yes if consistent with the app's existing UX). If a requested backup fails, remove nothing.
- Remove the launcher, app bundle, desktop entry, installed custom icon(s), and any app-owned desktop/icon cache entries that can be named exactly. Update desktop/icon caches where possible. For a System-wide install, request elevation only for owned system paths; a user's config must be handled as that user, not by deleting all users' config.
- Ask separately whether to remove per-user config/cache/demo data. Default **No**. Saved user data, user-created files and settings are separate from the app binaries; never delete them without a dedicated opt-in question.
- For system-wide installs, deleting the shared program is an administrative action: show that all users will lose access, and do not remove a different Local install. If package-manager-owned, delegate removal to the package manager.
- Never use broad wildcard deletion or an unvalidated path. Build the removal list from the install manifest / exact paths recorded at installation.
- Make uninstall idempotent: `Nothing to remove - not installed.` is normal. Cancel, partial install, missing icon, missing desktop file and repeat runs must be handled safely.
- If both Local and System-wide copies exist, identify the currently running one, state clearly which copy will be removed, and never delete the other without a separate explicit choice.



#### 9.2.9 Dependency classification and Requirements panel

Every app must derive its dependency list from the capabilities it actually implements. Do not copy another app's dependency names or mark every useful tool as mandatory. At first-run installation (and when reopening the installer), show one framed panel titled **Requirements** with three separated groups:

| Group | Meaning | Installer behaviour |
|---|---|---|
| **MUST BE INSTALLED** | The app cannot start safely or cannot provide its minimum/core purpose without this dependency. Use this sparingly. | A missing mandatory requirement blocks a fresh install and an update. Explain what is missing and what the user must do. |
| **BETTER TO INSTALL** | The dependency unlocks an important capability, but the application remains useful without it. | Missing items never block installation. The dependent feature must degrade gracefully, and its own panel/action/diagnostics must say which capability is unavailable and how to enable it. |
| **OPTIONAL** | Extra information, convenience or a non-essential integration. | Missing items never block installation or normal startup. Report status where useful; do not clutter unrelated screens. |

**Panel presentation:**

1. Use the exact heading `Requirements`; separate the three groups with clear horizontal separators and the names above.
2. Show each dependency or logical dependency group on its own readable row. Installed/available is green with `✓`; missing is red with `✗`. Add a short purpose/impact explanation after the name where space permits.
3. Do not report every member of an alternative set as individually mandatory. If any one of several backends satisfies a requirement, display one grouped requirement such as `At least one probe backend` and show the accepted alternatives in its detail.
4. Distinguish **installed** from **usable**. For example, a `ping` binary may exist but ICMP may be blocked by permissions; show it as installed and explain the limitation, but do not count it as a working ICMP backend.
5. Evaluate mandatory conditions before both installation and update. A missing requirement must not leave a partially replaced installation.
6. Never install dependencies silently. The installer reports what is missing; the user installs it through their normal package manager. Do not infer or run a package-manager command without explicit consent.
7. The app's Diagnostics view and any capability-specific panel should repeat the relevant missing-tool explanation. A Recommended or Optional absence must disable only the dependent capability, not the entire app.
8. Dependency checks should be detected once per launch or refreshed deliberately; do not run repeated `command -v` / expensive capability probes inside every render pass.

**NetScope v1.0 example (Observed, not a universal list):** `bash >= 4` plus at least one usable probe backend are mandatory; `curl`, `ping`, `wget`, `ip` and `timeout` are recommended; DNS lookup helpers, Wi-Fi detail tools and `pgrep`/`pkill` are optional. Its alternative probe backend is a single OR-group, not a requirement to install every command. Future apps must classify their own actual dependencies.

#### 9.2.10 Resize-aware installer screens

The installer chooser and Requirements panel are normal interactive screens and must obey section 3.8 from the moment they appear:

- Register the resize-event handler **before** drawing the first-run chooser or the `--install-mode` chooser. Do not postpone `SIGWINCH` handling until after installation or until the main dashboard starts.
- The handler only sets a resize/dirty flag. The chooser's normal event loop consumes the flag, re-reads the terminal dimensions, rebuilds the Requirements box and option layout, and repaints without requiring the user to press an arrow key, Enter or another key. It also compares the real terminal dimensions after every short input wait, so a lost/delayed `SIGWINCH` cannot leave the old layout on screen until the next user keypress.
- Recompute frame width, wrapping, padding, vertical placement, scroll/visibility budgets and all size-dependent caches from the new dimensions. Keep the selected install mode stable across a resize.
- If a resize and a key arrive together, process the key normally and ensure a redraw is still pending; a resize must not eat or reinterpret the key.
- Test the initial first-run flow and the later `--install-mode` flow in a pseudo-terminal: resize while the chooser is idle, send **no key**, and assert that the Requirements frame visibly redraws at the new dimensions within the normal event-loop wake interval.
- Verify that the highlighted install choice remains unchanged during the redraw, and repeat once with a resize signal and once with the dimension-poll fallback (where the signal is not delivered).

# 10. Developer style gallery

Developer samples are illustrative, not requirements. The normative layout, navigation, settings, privacy, installation and list behaviour is defined in sections 3-9; do not implement every sample screen unless the app needs it.

### 10.1 Style gallery (`--style-gallery`)

Developer-only style gallery (available through a debug route, test harness or optional flag): show every token, progress bars at 0/50/100% in neutral/ok/warn/error states, normal/focused/danger/disabled controls, selected/unselected rows, an input and status examples. Test all twenty-five themes and colour-off mode. Do not add a user-facing CLI solely to expose this gallery. See 2.5.5-2.5.6.

---

# PART B — SAKURA CODING & PROJECT-STRUCTURE BLUEPRINT

Observed facts come first in each topic; recommendations are marked.

## 11. Existing project evidence

The original reference apps inspected for this blueprint were single-file Bash TUIs. That describes the source material only; it is **not** a language, file-layout or implementation requirement. Reuse the demonstrated UI behaviour, not the original implementation choices.
## 12. Conventions to follow

### 12.1 Source tree (Recommended; adapt to the language)

```text
sakura-<product>/
  README.md                 what it is, install modes, keys, uninstall
  CHANGELOG.md
  VERSION                   single source of the version string
  src/
    main.*                  argument parsing, mode dispatch only
    app/                    domain / application logic (NO drawing code)
    ui/
      theme.*               theme table, tokens (2.5) and glyph tables (the only place with escape codes)
      keys.*                key table: key -> label -> handler -> hint text
      frame.*               box, row, bar, separator, paint
      screens/              main, settings, help, about, details, first_run
    config/                 settings load/save/validate
    install/                installer, uninstaller, desktop entry, modes
    assets/                 logo art, glossary text, default data
  tests/                    ui, settings, install, error cases
  tools/                    build / release scripts
```

A single-file tool (like the current apps) is acceptable when it is small, but keep the **same logical sections in the same order**: constants and identity, settings, theme/glyphs, small utilities, domain logic, frame builders, screens, installer, key handling, main. Put the app-specific domain logic in one clearly marked block so it can be replaced wholesale.

### 12.2 Separation of concerns

- **UI never decides business rules.** Domain code returns data; UI formats it.
- **Domain code never prints.** It sets values or returns results.
- **Installer code is independent of the UI** and callable from the command line (`--install-mode`, `--uninstall`).
- **Assets** (logo, glossary, default lists) are data, not scattered literals.

### 12.3 Code organisation and readability

- Follow the idioms and formatting conventions of the chosen language; do not copy Bash naming, globals, shell banners or script layout into another language.
- Separate domain logic, UI rendering, keyboard handling, theme tokens, settings and installation.
- Use clear names, small focused functions/components, and comments that explain non-obvious decisions rather than narrating every line.
- Keep the UI layer independent from app-specific logic so the user's requested functionality can be implemented or changed without rewriting the visual system.

### 12.4 Centralised theme and keys

- Keep theme data and glyph choices in one central module. Components consume semantic theme tokens, never raw colour values. Changing the theme updates all visible components and repaints the UI. A developer-only style gallery can inspect every token.
- **Observed gap:** the hint list and the key `case` are separate. **Recommended:** one key table drives both the handler and the hints box, and a test asserts they match. For a TUI implementing global theme cycling, put `,` and `.` in this same table as previous/next theme; do not duplicate or separately hard-code their labels in screen footers. Render the current theme as `< Theme Name >` in the final Hints row beside `< setting`, and keep that value live after every cycle.

### 12.5 Settings and configuration

- **Observed:** a `key=value` text file under `${XDG_CONFIG_HOME:-~/.config}/SakuraSuit/<app-id>/`, created with restrictive permissions; defaults live in code; values are validated; unknown keys are ignored; a missing file means defaults; settings may be saved as they change; an environment variable can override a stored value without being written back.
- **Required path convention:** never create a separate `${XDG_CONFIG_HOME}/<command-slug>/` directory. All persistent per-app configuration belongs to the SakuraSuit namespace defined in 9.2.1.
- **Recommended:** write to a temporary file then rename (atomic); version the file (`config_version=1`); keep user-editable lists in separate files inside the same per-app config directory and never overwrite user-edited files when generating templates.
- **Standard keys (Recommended; Observed in Downloader 12):** `theme=<slug>` and `ascii=auto|on|off` live in the settings file; credentials, if any, go in the same file with mode `600` and are never printed (say plainly in the UI that they are not encrypted unless a keyring is really used).

### 12.6 Errors, logging, validation, safe defaults

- **Observed:** user input is validated with explicit ranges; invalid values fall back to defaults; messages say what failed and what to do; the app exits with a clear message when it has no way to work (no required tools); an exit trap and signal traps (`INT`, `TERM`, `HUP`) clean the temp directory and restore the terminal; the temp directory is created with `mktemp -d`.
- **Recommended:** a small `log` facility writing to a file only when `--log` is passed; never log secrets; return non-zero exit codes for failures in one-shot modes; no silent `rm -rf` on computed paths.

### 12.7 Dependencies and subprocesses

- Declare dependencies using the three installer tiers in 9.2.9: **MUST BE INSTALLED**, **BETTER TO INSTALL**, and **OPTIONAL**. Check them before install/update, show green checks and red crosses in the Requirements panel, and explain capability impact in Diagnostics. Optional/recommended capabilities should degrade gracefully; only missing mandatory requirements block installation.
- Never install dependencies silently. Demo mode must not modify the system; other modes must explain and ask before consequential changes.
- Use the language's normal async/background-work model for slow operations, cancel them on exit, and clean up temporary resources.

### 12.8 Portability and paths

- Use `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `TMPDIR` and `$HOME`; no absolute user paths in code. Quote every path. Resolve the running script's own path robustly (symlinks). Keep platform-specific code (for example reading `/proc`) behind a check and a graceful fallback. **Observed:** only Linux was targeted; macOS, BSD and Windows behaviour is **Unknown**.

### 12.9 Testing conventions

- **Observed:** the reference apps did not ship a test suite. For a TUI, use a pseudo-terminal or equivalent harness to render screens at fixed sizes, send keys, inspect output and measure responsiveness. For other interfaces, use the equivalent component, integration and accessibility tests.
- **Recommended** (add these to every new app):
  1. **Render tests** for each TUI screen at three sizes × Unicode/ASCII modes, checking alignment, clipping and consistent layout. For six-metric panels, check the two-row/three-column summary at normal and narrow widths, and verify that panel-wide status titles remain readable without a duplicate status row.
  2. **Navigation tests:** every documented key matches exactly one hint; grouped two-column hints stay aligned and use separators; no duplicate permanent shortcut legend appears beneath the dashboard; `Esc` returns; resize redraws; ordinary navigation does not flash the whole screen. Where global theme cycling is enabled, `,`/`.` work on every non-text-input screen, wrap at both ends, update `< Theme Name >` immediately and persist the selected theme. For linked multi-panel lists, verify one active marker, Up/Down crossing both panel boundaries, `Tab` changing focus and `Enter` opening the item in the active panel; returning from details must restore focus, selection and scroll position.
  3. **Settings tests:** defaults, invalid input, persistence round trip, live theme update and environment overrides where supported. Change themes while a privacy/empty-state view is visible, then exit Settings: every visible element must use the new theme without pressing refresh or restarting.
  4. **Privacy tests:** seed known sensitive values and verify they do not leak through any visible surface; masked layouts keep the same dimensions (6.2).
  5. **Install tests** in a temporary `$HOME`: Demo creates no executable/desktop/icon installation (and only creates a documented `demo/` folder if required); Local creates the per-app bundle, command launcher, desktop entry and selected custom icon in the documented paths; System-wide runs against a fake root and lays down the bundle, launcher, desktop entry and icon; repeat runs are no-ops; cancel changes nothing; partial failure rolls back; uninstall removes only its recorded files and keeps config unless told otherwise. Also test each dependency tier: missing MUST blocks install/update, missing BETTER/OPTIONAL never blocks, an OR-group passes when any accepted backend is usable, and installed-but-unusable tools are distinguished from missing tools. Test Requirements-panel resize without keypress as specified in 9.2.10.
  6. **Icon tests:** matching `<app-id>.png`, `.jpg` and `.ico` are found next to the entry point; the wrong/random image is never picked; missing/invalid images fall back to the declared stock icon; the desktop entry points to the installed, not source-tree, icon; uninstall removes the app-owned icon only.
  7. **Error tests:** missing dependency, unwritable directory, terminal too small, no terminal, unsupported/broken custom icon and a failed/partial install.
  8. A **brand test**: grep for old product names (see 1.5).

### 12.10 Build, release, version

- Keep one source of truth for the app version and show it in About; a `--version` option is optional when the app exposes command-line flags.
- Use semantic versions, a changelog and a repeatable build/release process that runs the language's formatter, linter, tests and packaging steps.

### 12.11 Preserve behaviour while redesigning presentation

When restyling an existing app, preserve its domain logic, capabilities, data formats and existing workflows. Change only what the user asked to change; keep existing keys, options and config compatible where possible, and compare before/after behaviour with regression tests. Do not redesign or replace the app's actual function based on examples in this blueprint.


### 12.12 Responsiveness and performance

- The UI must feel immediate: target under 100 ms from key press to updated screen, with frame construction ideally under 50 ms for ordinary TUI views.
- Never run network requests, long disk operations, parsing, imports or exports on the UI thread. Use the language's async/background mechanism and show progress when work takes time.
- Avoid flicker: compose a complete frame or component update before drawing; update only changed content when practical. Do not clear and repaint the entire TUI for ordinary selection movement.
- For long lists, render only visible rows (virtual scrolling). Cache expensive static layout/art and invalidate it when **every input to the cached result** changes, such as width, height, label, theme, ASCII mode or view mode. Use bounded caches (for example a small LRU) rather than an unbounded map; include all relevant inputs in the cache key.
- Cache pure, repeated summaries only when their source state has not changed. Avoid repeated sorting, wrapping, width calculations, large art generation, configuration parsing or subprocess calls in the hot render path. Precompute stable configuration/data outside the frame painter.
- For external/background jobs, cap concurrency, retries and per-operation timeouts; keep the UI responsive and cancel/clean up workers on exit. Never start a new probe/process on every redraw unless that operation is explicitly the user's requested action.
- Idle loops must wait for input/events instead of spinning. Keep animations gentle (about 10 fps or less), cancellable and disabled when they add no value. The NetScope installer chooser uses a short timed input wait and compares the actual terminal dimensions at each loop wake, so it can redraw even if `SIGWINCH` is missed; this is an installer-specific safety net, not permission to poll rapidly in every app loop.
- Bound histories, buffers, retries and timeouts. Cancel background work and clean temporary resources on exit.
- Measure before optimising. Add a repeatable timing test for the largest realistic screen or workload and fix measured bottlenecks rather than guessing.
**NetScope v1.0 performance patterns (Observed reference examples; copy the principle, not the numbers or shell implementation):**

- Endpoint checks run in a bounded background worker pool (NetScope caps concurrent probes at 16) behind a scheduler process, with a per-cycle watchdog (15 seconds in NetScope). UI input and painting do not wait for every endpoint to finish.
- Completed endpoint results are ingested incrementally as they appear, so the dashboard can update partial results while slower checks continue. Do not count an already-ingested result twice when the full cycle completes.
- Slower environmental discovery (routes, gateway, proxy and interface details) is separated from the fast probe cycle and refreshed on a longer cadence; system-proxy discovery runs asynchronously.
- Repeated aggregate summaries are cached by all relevant inputs (cycle, history window, thresholds and scan switches), avoiding repeated sorting/calculation when the source state has not changed.
- Deterministic decorative art uses a small bounded multi-key cache. NetScope's grove cache key includes target width, target height, ASCII mode and theme; its cache is capped at eight entries. A single last-value cache was insufficient when two panels had different dimensions.
- List rendering builds only the visible scroll window and clamps selection/offsets to the visible range. The dashboard composes a complete frame before one terminal write; theme and resize changes invalidate only the caches that depend on those inputs, then repaint coherently.
- Process cleanup uses a single process-table snapshot to identify descendants of tracked workers rather than repeatedly launching process searches for every child.
- For truecolor light surfaces, reduce repeated ANSI output by combining the base foreground/background and selected-row rendition into compact SGR sequences (2.4.3); validate both output volume and unchanged appearance.

These are reference patterns and measurements from one Bash TUI, not universal requirements: do not add a worker pool, caches, subprocesses or art to an app that does not need them. Profile the actual workload and use the implementation model native to the chosen language/platform.

- These are cross-language UX goals, not a requirement to use subprocesses, shell variables, files as queues or any particular rendering technique.
---

# 13. How to Use This Blueprint for a New Sakura App

The blueprint defines a **reusable design identity and general implementation conventions**. It does **not** define a fixed application or a fixed list of features. Take the identity from Part A, the infrastructure habits from Part B, and the functionality **only** from the user's request.

### 13.1 Workflow for a new app

1. **Read the request** and write a one-paragraph product definition and the list of *real* features. Anything not in the request stays out.
2. **Name it** (1.1). Fill the identity block.
3. **List the sections/screens** the product genuinely needs. For each, decide: main panel, sub-screen, or not needed (section 5).
4. **Choose the layout** with the decision table (3.7). Name every panel after its subject, not after NetScope.
5. **Design the key table** (4.2) with the universal keys first, then app keys. Check conflicts.
6. **Make the logo**: the tree plus the product name (1.3). Decide the product symbol, if any.
7. **Define the theme table, the tokens (2.5), colours and glyph tables** (2, 2.4, 7) once. Include all twenty-five standard themes unless the owner narrows the list. Map your states to semantic roles **and** words/glyphs. Use thin progress-bar cells (3.4).
8. **Choose the implementation language and UI toolkit** based on the user's request and repository. Do not default to shell scripts. Implement shared UI infrastructure: themes/tokens, panels, progress bars, keyboard navigation, settings, resize/accessibility and cleanup.
9. **Implement the first-run installation choice and shared uninstaller** (9), including the app bundle, command launcher, desktop entry, custom icon discovery, migration and exact uninstall manifest. Command-line flags are optional controls, not the primary interface.
10. **Implement the product features** from the user's description. Keep domain logic separate from UI drawing.
11. **Add help/About/glossary/diagnostics only where useful.**
12. **Test** (12.9) and run the checklist (14).

### 13.2 Workflow for redesigning an existing app

1. **Inspect first.** List every feature, flag, key, screen, config file and install behaviour the existing app has.
2. **Preserve the core.** Keep the data/logic code and every existing capability. Replace or remove behaviour **only** if the user explicitly asks.
3. **Map old screens to the Sakura pattern:** old menu → hints box + key table; old tables → named panels with summary + list; old settings → Settings screen; old help → Help/About; old output formats → keep as one-shot modes.
4. **Keep compatibility:** existing user workflows, keyboard shortcuts, command-line flags (if any) and config files keep working where possible; migrate old settings safely.
5. **Introduce the first-run choice** without disturbing existing installs: an already-installed copy keeps working and is treated as Local mode.
6. **Verify:** compare before/after data output, run the render/navigation/install tests, run the brand grep, and show the user what changed.

---

### 13.3 Examples are illustrations, not specs (read before using any example)

Any sample names, reference-app details, key maps, component galleries and performance measurements in this blueprint are illustrations of patterns, not requirements to copy into a new product.

1. **Never implement an example unless the owner asks for exactly that app.** A request for "a notes app" gets a notes app that follows the *rules* of this blueprint, not Weather and not NetScope.
2. **Never copy NetScope's functionality, data or wording.** Network monitoring, providers, sites lists, mirrors, speed tests, DNS and proxy panels, internet-quality grades and the glossary entries are NetScope's own. If your app's nouns include any of them, you copied the wrong thing.
3. **Take the pattern, replace the content.** The table below says what to take and what to leave.
4. **Generate your own example content** from the owner's request for every screen, template and test.

| Take (shared by every Sakura app) | Leave (belongs to the example app) |
|---|---|
| Name pattern, tree logo, `✿` titles, rounded borders | Product names and taglines of other apps |
| Twenty-five themes, roles, tokens (2.4, 2.5), thin progress cells | Which states an app maps to `ok/warn/error` |
| Frame painter, resize method (3.8), performance rules (12.12) | Panel names, panel counts, dashboard grid |
| List selection and details screen model (4.4) | The fields shown in a details screen |
| Key-table method and universal keys (4.2) | Letter keys that mean something only to one app |
| Privacy method (6.2) | Which values are sensitive in a given app |
| Settings structure, first-run install choice, uninstall rules (5, 9) | Settings that belong to one domain |
| Tests and checklist (12.9, 14) | Domain-specific test data |

**Self-check before delivering:** search your new app (code, help, glossary, tests, desktop file) for NetScope nouns (`provider`, `mirror`, `speed test`, `ICMP`, `DNS`, `proxy`, `internet quality`, `INSIDE`, `GLOBAL`). Zero hits unless the owner's app really is about those things.

---

# 14. Final checklist

Use this checklist after implementation; detailed requirements remain in the referenced sections.

- [ ] **Identity:** one source for display name, command slug, app-directory id, env prefix, version and tagline; correct tree/logo, titles, menu entry, icon and paths; no old-product leftovers (1.1-1.5).
- [ ] **Themes and visuals:** all twenty-five themes; role table and component tokens; live preview in Settings; when supported, global `,`/`.` theme cycling and the live `< Theme Name >` Hints cue; Lightly Rose light-surface rendering is contained and optimised without appearance changes; consistent boxes, progress bars, selection, inputs and status styling; no hard-coded colours in components; theme/token tests pass (2).
- [ ] **Layout:** correct frame painting, named panels, inline panel-wide status where appropriate, summary grids, progress bars, buttons, inputs, inactive-row placeholders, status messages and responsive breakpoints; no flicker or clipping; resize behavior passes tests (3).
- [ ] **Navigation:** one key table drives both handlers and hints; no conflicting keys; lists scroll, show selection/range, support linked-panel boundary crossing with one active marker where appropriate, and restore focus/selection after details (4).
- [ ] **Screens and settings:** include only useful screens; validate and persist settings; help/About/version agree; glossary terms have readable spacing/separators; diagnostics, details and logs are conditional (5).
- [ ] **Privacy:** only when relevant; secrets are never printed; all display surfaces are masked; masked layouts retain dimensions; seeded-value leak test passes (6).
- [ ] **Compatibility:** where relevant, complete glyph table and ASCII fallback, colour-off support and readable non-interactive output; layout/resize/accessibility tests pass (7-8).
- [ ] **Install/uninstall:** first-run Demo/Local/System-wide choice; live Requirements panel with the three dependency tiers and correct mandatory/optional gating; installer resize redraws without a keypress; Local bundle under `~/.local/bin/sakurasuit/<app-id>/`; per-user config under `~/.config/SakuraSuit/<app-id>/`; System-wide bundle plus command, desktop entry and icon in the documented system locations; automatic custom-icon discovery; no changes before consent; safe atomic updates; exactly two uninstall entry points; explicit confirmations and safe defaults (9).
- [ ] **Architecture and quality:** separate UI/domain/config/install/assets; no blocking work in UI loop; bounded resources, safe errors and cleanup; render, navigation, settings, install, privacy, resize, timing and brand tests pass (11-12).
- [ ] **Product-specific correctness:** implement only requested features; examples are patterns, never product specs; preserve existing behavior when redesigning (13).
- [ ] **Release:** lint/build passes; one version source, changelog and release script are current (12.10, 16).

# 15. Uncertain or undocumented details

Not verified from the available project; do not treat as facts:

1. **Visual appearance in real terminals.** Only text renderings and a pseudo-terminal were inspected. No screenshots exist. Width of `✿` and `▶` in different fonts and in terminals using East-Asian ambiguous width is unknown.
2. **Terminal colour-depth support.** The eighteen core themes use xterm-256 codes; the seven character themes use RGB colour escapes, and `lightly-rose` additionally uses background-colour escapes. Exact appearance still depends on terminal truecolor support; no terminal-global palette commands are used.
3. **Owner's brand guidelines.** None were provided. The identity above is extracted from code and from the owner's requests in the conversation.
4. **Icon.** NetScope v1.9.3 uses a stock icon. Automatic sibling-image discovery is a newly specified rule and has not yet been implemented in NetScope. Desktop-environment support for `.ico` and `.jpg` varies; check the generated launcher on each target desktop.
5. **Terminal title and window class.** Not set by the apps.
6. **System-wide layout and install flow.** NetScope v1.9.3 implements basic System-wide, Local and Demo modes, but the per-app nested bundle layout, `/opt/sakurasuit/<app-id>` standalone System-wide layout, standardized custom-icon copying and full install-manifest cleanup in section 9 are the target contract and have not all been validated in a real system install.
7. **Desktop launchers.** `Terminal=true` menu entries were written to the standard files but not verified in every desktop environment. (Older apps also wrote an `Uninstall` menu action; blueprint 1.1 forbids it.)
8. **Other platforms.** macOS, BSD, Windows, Wayland-only setups and non-Bash implementations were not examined.
9. **Sakura Downloader beyond its installer and logo.** Only the install/uninstall system and the logo were studied; its download features and other screens were not documented.
10. **Tests.** No test suite is shipped; the testing practices listed under "Observed" were development habits, not repository files.
11. **Glossary and help language.** English only; right-to-left languages were not designed for (bidirectional text breaks in terminals).
12. **Theme contrast.** The twenty-four non-default themes have proposed role palettes; their contrast has not been validated on every real display. `lightly-rose` is explicitly designed for a light background; remaining themes target the terminal's usual dark background. Contrast on 16-colour terminals is unknown (2.4.3, rule 7).
13. **Theme names.** The twenty-five theme names are the owner's/current blueprint choices. The seventeen non-default core themes use proposed xterm palettes; the seven character themes use owner-approved RGB palettes, including the exact Crystal Rose source colours.
14. **Tokens and overrides (2.5).** The token table and the per-theme overrides are a Recommended design; no app implements them yet, and the override choices have not been checked on real displays.
15. **Thin progress cells (3.4, 7.1).** `━` and `─` are assumed single-width in common terminal fonts; this was not verified. Existing apps have not been changed to use them yet (only the glyph table needs to change).
16. **Performance numbers (12.12).** The millisecond figures were measured once in the development sandbox with a synthetic data set (120x45, about 40 data rows), not on real machines; idle CPU use was not measured. Treat them as orders of magnitude.
17. **Resize (3.8, 9.2.10).** NetScope v1.0 installer chooser resizing was verified in a pseudo-terminal both with `SIGWINCH` and with that signal ignored, including a resize without any keypress. Not verified in every terminal emulator or multiplexer. The 250 ms dimension poll is specific to the installer chooser; periodic polling on the main dashboard and other screens remains a recommendation, not an Observed behaviour.
18. **Privacy (6.2).** Observed only as the all-or-nothing mode in NetScope. Per-class and per-box masking, the `PRIVACY` settings section and the leak test are Recommended and untested in a real app.
19. **Details screen keys (4.4).** NetScope returns on any key; the stricter `Esc`/`q`/`Enter` rule is Recommended.
20. **Responsive placement (3.5).** The compact-centred versus full-area rule is a family standard from the owner's NetScope refinement cycle; test every new screen at wide/full-screen and narrow sizes.
21. **Custom icon installation (1.4, 9.2).** The filename-discovery and per-mode copy rules are specified but need implementation and integration tests, including `.ico`/`.jpg` compatibility on target desktops.

---

# 16. Versions and how to change this blueprint

## 16.1 The blueprint's own version

1. **Line 1 of this file is always `BLUEPRINT_VERSION: X.Y`.** Nothing may be placed above it. It is the single source of truth and the owner may edit it by hand at any time; if the number on line 1 and the text in the header ever disagree, line 1 wins and the header is corrected.
2. The format is `major.minor`. **Every content change raises the minor number by one** (`1.1` -> `1.2` -> `1.3`). A new major number (`2.0`) is used only when the owner says so.
3. Pure typo, spelling or spacing fixes that do not change meaning do not raise the version.

## 16.2 Rules for any AI agent that receives this file

1. When the owner asks to change this blueprint, edit this file itself; do not merely describe the edit or recreate the document from memory.
2. Apply the change only where it belongs, consolidate duplicate rules into one authoritative section, and correct any now-false cross-references. Keep evidence labels honest (Observed / Recommended / Unknown).
3. Raise the version once per request, update the header and line 1, and add a concise history entry in 16.4.
4. Return the updated file to the owner and say, in one line, what changed and the new version.
5. If the owner only asks a question about the blueprint, answer it and **do not** edit the file or change the version.
6. Do not silently drop unique requirements. When the owner's new request conflicts with an old rule, follow the owner's request, record the conflict in the history and remove the superseded rule.

## 16.3 App versions

1. Every Sakura app has one version source, displayed in About and optionally in Settings. A command-line `--version` option is useful when the app supports command-line options, but is not mandatory for a TUI.
2. The app's version is independent of the blueprint's. **Recommended:** a header comment `# Built to the Sakura blueprint X.Y` records which blueprint version the app follows, so it is easy to see which apps need aligning after the blueprint changes.
3. Raise the app's version for every release that changes behaviour or screens; the installer's "newer file" comparison (9.2) and the changelog use it.

## 16.4 Version history

| Version | Date | Changes |
|---|---|---|
| 1.12 | 2026-10-30 | Audited the complete NetScope v1.0 UI and installer; documented its app-specific Violet Purple default, inline panel status titles, responsive 2×3 metric grid, inactive-section row treatment, linked-panel single-marker navigation, privacy artwork without duplicate centre text, glossary spacing, and compact Lightly Rose rendering; strengthened installer dimension polling so resize redraw is independent of keypresses, added PTY regression tests, and corrected stale/duplicated blueprint wording. |
| 1.11 | 2026-10-30 | Audited the stable NetScope v1.0 implementation and added global `,`/`.` theme cycling with the live `< Theme Name >` Hints cue; documented the Lightly Rose combined-SGR render optimisation and other measured/reference performance patterns; specified the three-tier Requirements panel, OR-group dependency gating and graceful capability fallback; made resize handling before and during the installer chooser an explicit family rule and added no-keypress PTY regression tests. |
| 1.10 | 2026-10-29 | Added seven owner-selected character themes—Anta Baka, Soulless Moon, Calm Whisper, Retro Bit, Darkly Rose, Lightly Rose and Galactic Silence; retained the first Rei palette, revised Stargazer palette, and both Crystal Rose variants from the same five exact source colours; added RGB role support and Lightly Rose's contained light-surface/selection treatment; synchronized theme table, overrides, tests, checklist, workflows, counts and uncertainty notes. |
| 1.9 | 2026-10-29 | Expanded the standard theme set from nine to eighteen; renamed Sakura theme to Hanakage, Aero Water to Aqualume, and Red & White to Kōhaku; added Matcha Garden, Midnight Tide, Momiji Ember, Neon Shibuya, Wisteria Dream, Indigo Washi, Jade Dynasty, Frostbite and Cyberneon; added explicit per-app default-theme selection and Hanakage fallback rules; synchronized palettes, overrides, tests, checklist and references. |
| 1.8 | 2026-10-29 | Added Coffee Brown and Red & White, bringing the shared Sakura theme standard from seven to nine; added role-code and hex palettes plus token overrides; synchronized theme counts and theme-related tests, non-terminal guidance, workflow, checklist and uncertainty notes; explicitly distinguished the two blueprint additions from the seven themes actually present in the NetScope v1.9.3 / Downloader 12.0.0 reference sources. |
| 1.7 | 2026-10-28 | Updated the shared SakuraSuit per-app namespace; specified nested Local bundles and a cleaner standalone System-wide install layout with command launchers, desktop files and standard icon-theme integration; added filename-based custom icon discovery for `.png`, `.jpg` and `.ico`; consolidated Settings, responsive compact/full-area screen placement, hints, cache invalidation, performance and install/uninstall testing rules based on NetScope v1.9.3 while keeping NetScope functionality explicitly app-specific. |
| 1.6 | 2026-10-28 | Refined Hints layout into grouped, separated two-column sections when space allows; removed duplicated bottom shortcut legends and main-dashboard uninstall text; made theme changes invalidate cached art/frames and redraw the underlying screen on leaving Settings; clarified balanced grid/column sizing and added regression tests for these behaviours. |
| 1.5 | 2026-10-28 | Clarified semantic-version-based app updates, safe atomic replacement and downgrade protection; clarified Settings metadata for app version, install mode and uninstall guidance. |
| 1.4 | 2026-10-28 | Consolidated repeated guidance; made the blueprint TUI/style-first and language-neutral; removed the default Bash/shell assumption; clarified that the user's request alone defines app functionality; made CLI flags optional; unified performance and implementation guidance. |
| 1.3 | 2026-10-28 | Reduced repetition: removed duplicate colour and privacy recaps, shortcut-discovery walkthrough, redundant UI templates and worked examples; condensed the checklist to section references. |
| 1.2 | 2026-10-27 | Component tokens so themes restyle progress bars, buttons, inputs, text, lines, borders and selection, with per-theme overrides and a style gallery (2.5, 10.9); **thin progress-bar cells** `━` / `─` in Unicode mode (3.4, 7.1, 13.2); complete **resize method** (3.8); **item selection and details screen** model (4.4, 10.7); **privacy method** for any part of an app (6.2, 10.8, Settings > PRIVACY); **performance and smoothness** rules from NetScope's optimisation work (12.12); button and input field components (3.4); **examples are illustrations** rule and take/leave table (13.6); blueprint stated as for every Sakura app; checklist (14) and uncertain list (15, items 14-19) extended |
| 1.1 | 2026-10-27 | Seven-theme system with Sakura as default (2.4); scope initially stated as Linux shell / CLI apps (superseded in 1.4); first-run install system declared final (9.2); **uninstall has exactly two entry points** (`--uninstall` and Settings > UNINSTALL), all other routes (menu action, right-click, typed shortcut) removed (9.2, "Uninstall entry points"); Settings gains a section `UNINSTALL` and a final read-only row `sakura-<product> version <x.y>`; app version rule; blueprint versioning rules (this section); Sakura Downloader 12 case study (13.5) |
| 1.0 | 2026-10-26 | First blueprint, extracted from Sakura NetScope 1.2.0 and the Sakura Downloader installer and logo: identity, palette, layout, keys, screens, ASCII mode, first-run install choice, code conventions, checklists |
