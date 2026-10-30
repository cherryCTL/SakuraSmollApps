# 🌸 SAKURA SUIT APPS

*Little tools for daily annoyances. A reusable UI playground. And, occasionally, a wonderfully pointless idea.*

Sakura Suit Apps is my personal collection of small apps built for two things:

1. **Make the tools I already use less annoying.** Some great tools have workflows that involve typing long commands, remembering flags, or repeating the same steps all day. Sakura apps wrap those tools in friendlier menus, shortcuts, presets, and small interfaces that fit the way I actually use them. The goal is simple: less typing, less friction, more getting things done.
2. **Build a UI style I can reuse.** Sakura is also my playground for creating a visual identity with reusable layouts, components, and lots of themes. I want that style to work in both **TUI and GUI** apps, so I can carry the same look and feel into future projects.

Not every app needs to be serious. Some will be practical daily helpers; some might be experiments, tiny toys, or completely silly things made just because the idea sounded fun. **Pointless is a perfectly valid project category here.**

Most apps currently use a TUI because it is convenient for me to build and use. That is a development choice for now, not a rule for the future. Sakura is meant for both terminal and graphical apps.

---

## 🌸 Sakura Projects

### 01 — Sakura NetScope

**Sakura NetScope 1.0** is the first stable app in the collection. It brings everyday network checks, speed tests, and Linux distribution mirror testing into one terminal interface — so I don't have to juggle commands just to figure out whether my connection or a mirror is having a bad day.

A few things it can do:

- Check global network providers and **Inside** providers. Inside currently covers **Iran only**; support for more countries is planned.
- Test mirrors for popular Linux distributions, including global mirrors and the currently supported Iran-based Inside mirrors.
- Summarise reachability, latency, packet loss, and connection quality.
- Run download and upload speed tests.
- Keep useful settings, Privacy Mode, and a built-in glossary in one place.
- Switch between **25 themes** — from soft Sakura colours to character-inspired palettes.
- Change the active theme from anywhere with `,` (previous) and `.` (next). The Hints row shows the current theme as `< Theme Name >`.
- Check installer requirements in three groups: **Must be installed**, **Better to install**, and **Optional**.

And for our dear nerds: the **Glossary** is stuffed with bite-sized network explanations, nerdy terms, and fun little bits of text. Poke around — you might learn something and become even more powerful (or at least more annoying at LAN parties).

It's a network toolbox, but it should feel a little nicer to use than a pile of commands. **A few small bugs still remain and are waiting to be squashed in future updates.**

#### 🛠️ Planned for Sakura NetScope

- **More Inside regions:** Inside network checks and mirror coverage are currently Iran-only. Support for other countries is planned for the future.

#### 📸 A peek at NetScope

<table>
  <tr>
    <td width="50%" valign="top"><strong>Main page</strong><br><img src="screenshots/sakura%20netscope/main%20page.png" alt="Sakura NetScope main page" width="100%"></td>
    <td width="50%" valign="top"><strong>Settings</strong><br><img src="screenshots/sakura%20netscope/setting%20page.png" alt="Sakura NetScope settings" width="100%"></td>
  </tr>
  <tr>
    <td width="50%" valign="top"><strong>Glossary</strong><br><img src="screenshots/sakura%20netscope/glossary.png" alt="Sakura NetScope glossary" width="100%"></td>
    <td width="50%" valign="top"><strong>Mirror test</strong><br><img src="screenshots/sakura%20netscope/mirror%20test.png" alt="Sakura NetScope mirror test" width="100%"></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><strong>Speed test</strong><br><img src="screenshots/sakura%20netscope/speedtest.png" alt="Sakura NetScope speed test" width="72%"></td>
  </tr>
</table>

---

### 02 — 🌸 SakuraDesktopIcons

A desktop icon manager for **Hyprland**, built with **C++17, Qt6, and LayerShellQt**. It brings draggable desktop icons, flexible positioning, and a surprisingly customizable desktop experience to Wayland.

A few things it can do:

- Arrange desktop icons with drag-and-drop, manual positioning, multi-selection, keyboard navigation, and resizing.
- Manage files from the desktop: open, rename, delete, inspect properties, and move items to the Trash.
- Create and edit `.desktop` launchers, links, and directory entries; add custom actions to context menus.
- Pick built-in themes or load custom JSON themes, with support for reading colours from Noctalia's generated theme format.
- Customize animations and sound events, with reduced-motion support.
- Keep independent icon layouts across multiple monitors.
- Use the system tray for quick access to Settings, About, and Restart.
- Build, install, or uninstall through its interactive installer.

Project home: **[SakuraDesktopIcons on GitHub](https://github.com/cherryCTL/SakuraDesktopIcon)**

<table>
  <tr>
    <td width="50%" valign="top"><strong>Settings and desktop integration</strong><br><a href="https://github.com/cherryCTL/SakuraDesktopIcon"><img src="https://raw.githubusercontent.com/cherryCTL/SakuraDesktopIcon/main/screenshots/ex1.png" alt="SakuraDesktopIcons settings and desktop" width="100%"></a></td>
    <td width="50%" valign="top"><strong>Appearance and custom themes</strong><br><a href="https://github.com/cherryCTL/SakuraDesktopIcon"><img src="https://raw.githubusercontent.com/cherryCTL/SakuraDesktopIcon/main/screenshots/ex2.png" alt="SakuraDesktopIcons appearance settings" width="100%"></a></td>
  </tr>
</table>

---

## 🌸 More Sakura Apps

NetScope is just the first one to move in. Here is another little resident of the Sakura garden:

More little Sakura apps will appear here as they become ready — daily helpers, wrappers around other tools, experiments, GUI projects, TUI projects, and the occasional app whose entire purpose is basically *"because why not?"* If it makes something easier, teaches me something, or is simply fun to build, it belongs in the garden.

---

## ▶️ Try Sakura NetScope

You can start the installer either way:

- **File manager:** Open the `bin/` folder and run `Sakura NetScope 1.0.sh`. If your file manager asks, choose **Run** or **Execute**, not **Display**.
- **Terminal:** From the repository root, run:

```bash
bash "bin/Sakura NetScope 1.0.sh"
```

The installer checks the requirements before installing. Missing mandatory tools stop installation; missing recommended or optional tools do not block it, and features that depend on unavailable tools can report that they are unavailable.

## 🧰 What's in this little toolbox?

```text
SakuraSmallApps/
├── bin/          # Ready-to-run scripts and app binaries
├── src/          # Source-first projects that need building or compiling
├── blueprint/    # The shared Sakura UI and development blueprint
├── screenshots/  # App screenshots and theme-name artwork
└── README.md
```

Some projects may stay as scripts; others may eventually be rewritten or ported in Rust so they can reach more platforms. That's a direction to explore, not a promise that every app already runs everywhere.

---

## 🧩 The Sakura Blueprint — make your own Sakura app

The [`BLUEPRINT_FOR_MAKING_SAKURA_APPS_1.12.md`](blueprint/BLUEPRINT_FOR_MAKING_SAKURA_APPS_1.12.md) file is the shared design and development guide for the Sakura family. It documents the visual identity, reusable UI patterns, theme system, navigation, settings, responsive layouts, installers, requirements checks, and practical development conventions.

You can give this blueprint to an AI coding assistant together with your own app idea and ask it to build a **Sakura-style application**. Tell it what the app should actually do, then use the blueprint as the guide for how the interface and shared experience should look and behave.

It is **not limited to TUI apps**. Use it for terminal interfaces or graphical desktop apps; the AI should adapt the Sakura identity to the right kind of interface instead of forcing terminal boxes onto a GUI. The blueprint provides the reusable style and UX rules — your app idea provides the features. It can be a useful daily tool, a GUI experiment, a tiny game, or something wonderfully pointless. Go make a little Sakura thing. 🌸

---

## 🎨 The Sakura Theme Garden

A Sakura app should be able to change its outfit without changing its personality. The shared theme set currently has **25 palettes**: a core collection of colour moods, plus seven character-inspired themes. Each one has a little reference behind it and a feeling it tries to bring to the interface.

The theme names below are coloured with each theme's primary accent. The character themes are optional flavour — the same Sakura UI rules still apply underneath.

<table>
<tr><td valign="top" width="33%"><img src="screenshots/theme-labels/hanakage.svg" alt="Hanakage" width="190" height="38"><br><sub><strong>Reference:</strong> Sakura blossoms<br><strong>Feeling:</strong> Soft, gentle and welcoming — the visual home of the Sakura family.</sub></td><td valign="top" width="33%"><img src="screenshots/theme-labels/joyful-sea.svg" alt="Joyful Sea" width="190" height="38"><br><sub><strong>Reference:</strong> Bright open water and tropical sea colours<br><strong>Feeling:</strong> Fresh, playful and breezy, with a splash of optimism.</sub></td><td valign="top" width="33%"><img src="screenshots/theme-labels/emerald-green.svg" alt="Emerald Green" width="190" height="38"><br><sub><strong>Reference:</strong> Polished emeralds and jewel-green tones<br><strong>Feeling:</strong> Rich, natural and steady — like a quiet green sanctuary.</sub></td></tr>
<tr><td valign="top" width="33%"><img src="screenshots/theme-labels/sunset-yellow.svg" alt="Sunset Yellow" width="190" height="38"><br><sub><strong>Reference:</strong> Golden-hour skies and warm sunset light<br><strong>Feeling:</strong> Sunny, cheerful and cozy, with a little orange warmth.</sub></td><td valign="top" width="33%"><img src="screenshots/theme-labels/clean-white.svg" alt="Clean White" width="190" height="38"><br><sub><strong>Reference:</strong> White porcelain, silver and pale blue<br><strong>Feeling:</strong> Minimal, calm and uncluttered — the quietest member of the set.</sub></td><td valign="top" width="33%"><img src="screenshots/theme-labels/aqualume.svg" alt="Aqualume" width="190" height="38"><br><sub><strong>Reference:</strong> Luminous water, aqua glass and sky-blue reflections<br><strong>Feeling:</strong> Cool, bright and glassy, with a clean futuristic feel.</sub></td></tr>
<tr><td valign="top" width="33%"><img src="screenshots/theme-labels/violet-purple.svg" alt="Violet Purple" width="190" height="38"><br><sub><strong>Reference:</strong> Lavender, violet and orchid shades<br><strong>Feeling:</strong> Dreamy, elegant and a little mysterious.</sub></td><td valign="top" width="33%"><img src="screenshots/theme-labels/coffee-brown.svg" alt="Coffee Brown" width="190" height="38"><br><sub><strong>Reference:</strong> Roasted coffee, caramel and warm cream<br><strong>Feeling:</strong> Grounded, cozy and warm — a comfy cup of terminal time.</sub></td><td valign="top" width="33%"><img src="screenshots/theme-labels/kohaku.svg" alt="Kōhaku" width="190" height="38"><br><sub><strong>Reference:</strong> A bold Japanese-inspired red-and-white pairing<br><strong>Feeling:</strong> Crisp, confident and striking, with a strong classic contrast.</sub></td></tr>
<tr><td valign="top" width="33%"><img src="screenshots/theme-labels/matcha-garden.svg" alt="Matcha Garden" width="190" height="38"><br><sub><strong>Reference:</strong> Matcha tea, sage leaves and a quiet garden<br><strong>Feeling:</strong> Botanical, peaceful and naturally balanced.</sub></td><td valign="top" width="33%"><img src="screenshots/theme-labels/midnight-tide.svg" alt="Midnight Tide" width="190" height="38"><br><sub><strong>Reference:</strong> Deep ocean water beneath a midnight sky<br><strong>Feeling:</strong> Cool, focused and quiet, with a distant cyan glow.</sub></td><td valign="top" width="33%"><img src="screenshots/theme-labels/momiji-ember.svg" alt="Momiji Ember" width="190" height="38"><br><sub><strong>Reference:</strong> Japanese maple leaves and autumn embers<br><strong>Feeling:</strong> Seasonal, fiery and warm — crimson, burnt orange and gold.</sub></td></tr>
<tr><td valign="top" width="33%"><img src="screenshots/theme-labels/neon-shibuya.svg" alt="Neon Shibuya" width="190" height="38"><br><sub><strong>Reference:</strong> Neon-lit Tokyo streets and cyberpunk city nights<br><strong>Feeling:</strong> Loud, electric and lively, like a late-night arcade district.</sub></td><td valign="top" width="33%"><img src="screenshots/theme-labels/wisteria-dream.svg" alt="Wisteria Dream" width="190" height="38"><br><sub><strong>Reference:</strong> Hanging wisteria flowers and soft spring light<br><strong>Feeling:</strong> Airy, delicate and dreamy, with a gentle purple haze.</sub></td><td valign="top" width="33%"><img src="screenshots/theme-labels/indigo-washi.svg" alt="Indigo Washi" width="190" height="38"><br><sub><strong>Reference:</strong> Indigo ink and traditional washi paper<br><strong>Feeling:</strong> Thoughtful, handcrafted and calm, with an inky blue character.</sub></td></tr>
<tr><td valign="top" width="33%"><img src="screenshots/theme-labels/jade-dynasty.svg" alt="Jade Dynasty" width="190" height="38"><br><sub><strong>Reference:</strong> Jade stone and antique gold accents<br><strong>Feeling:</strong> Composed, rich and quietly regal.</sub></td><td valign="top" width="33%"><img src="screenshots/theme-labels/frostbite.svg" alt="Frostbite" width="190" height="38"><br><sub><strong>Reference:</strong> Frosted glass, ice and cold steel-blue shades<br><strong>Feeling:</strong> Crisp, chilly and clean — a little winter for your terminal.</sub></td><td valign="top" width="33%"><img src="screenshots/theme-labels/cyberneon.svg" alt="Cyberneon" width="190" height="38"><br><sub><strong>Reference:</strong> Cyberpunk green, electric yellow and dark neon contrast<br><strong>Feeling:</strong> High-voltage, sharp and unapologetically digital.</sub></td></tr>
<tr><td valign="top" width="33%"><img src="screenshots/theme-labels/anta-baka.svg" alt="Anta Baka" width="190" height="38"><br><sub><strong>Reference:</strong> Asuka Langley from Neon Genesis Evangelion<br><strong>Feeling:</strong> Tsundere fire: bold red, hot orange and warning-gold attitude.</sub></td><td valign="top" width="33%"><img src="screenshots/theme-labels/soulless-moon.svg" alt="Soulless Moon" width="190" height="38"><br><sub><strong>Reference:</strong> Rei Ayanami from Neon Genesis Evangelion<br><strong>Feeling:</strong> Detached, distant and moon-cold, with icy blue and restrained red.</sub></td><td valign="top" width="33%"><img src="screenshots/theme-labels/calm-whisper.svg" alt="Calm Whisper" width="190" height="38"><br><sub><strong>Reference:</strong> Sona Classic from League of Legends<br><strong>Feeling:</strong> Soft sea-glass colours and gentle gold — quiet, soothing and calm.</sub></td></tr>
<tr><td valign="top" width="33%"><img src="screenshots/theme-labels/retro-bit.svg" alt="Retro Bit" width="190" height="38"><br><sub><strong>Reference:</strong> Arcade Sona from League of Legends<br><strong>Feeling:</strong> Pixel-magenta, electric cyan and purple; playful retro game energy.</sub></td><td valign="top" width="33%"><img src="screenshots/theme-labels/darkly-rose.svg" alt="Darkly Rose" width="190" height="38"><br><sub><strong>Reference:</strong> Crystal Rose Sona — dark variant<br><strong>Feeling:</strong> The same five colours taken from the skin, arranged for a darker, richer surface.</sub></td><td valign="top" width="33%"><img src="screenshots/theme-labels/lightly-rose.svg" alt="Lightly Rose" width="190" height="38"><br><sub><strong>Reference:</strong> Crystal Rose Sona — light variant<br><strong>Feeling:</strong> The same five skin colours on a bright, delicate surface; airy but still unmistakably Crystal Rose.</sub></td></tr>
<tr><td></td><td align="center"><img src="screenshots/theme-labels/galactic-silence.svg" alt="Galactic Silence" width="190" height="38"><br><sub><strong>Reference:</strong> Stargazer Sona from League of Legends<br><strong>Feeling:</strong> A blue-forward cosmic palette with nebula purple and muted burgundy; quiet, vast and star-lit.</sub></td><td></td></tr>
</table>

Yes, I’m an **Evangelion** fan. Yes, I play **League**. And yes, **Sona is my favourite champion** — I’m a pretty good support, too. What gave it away? 🌙🎮

---

*Made for everyday convenience, reusable interfaces, and whatever silly idea comes next. 🌸*
