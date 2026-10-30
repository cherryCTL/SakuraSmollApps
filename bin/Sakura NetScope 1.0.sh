#!/usr/bin/env bash
# =============================================================================
#  Sakura NetScope — TUI network monitor
#  First stable public release: v1.0
#  Sakura TUI family styling: shared themes, frames and blossom branding.
#  Built to the Sakura blueprint 1.12; expanded themes and refined dashboard layout.
#
#  Measures real connectivity and shows two independent panels:
#     GLOBAL   international internet
#     INSIDE   Iranian domestic ("national") internet
#  Each panel has two groups, separated by a line:
#     PROVIDERS  operators / backbones / clouds that carry the traffic
#     SITES      well-known websites
#
#  USAGE
#     sakura-netscope                   interactive TUI dashboard
#     sakura-netscope --once            measure, print one frame, exit
#     sakura-netscope --diag            tool / capability diagnostics
#     sakura-netscope --uninstall       remove the installed copy (asks first)
#     sakura-netscope --install-mode    choose Demo / Local / System-wide again
#     sakura-netscope --demo|--local|--system  set installation mode explicitly
#     sakura-netscope --write-config    create editable providers.conf + speedtest.conf
#     sakura-netscope --privacy         start in privacy mode (see key x)
#     sakura-netscope --speedtest       run the speed test once (text output)
#     options: --cycles N  --cols N  --rows N  --ascii  --color  --no-install
#              --theme NAME  --list-themes  --version  --help
#
#  KEYS
#     q quit   r refresh now + redraw the UI   p pause/resume   Tab switch panel
#     Up/Down select           Enter details    s settings       g diagnostics
#     , previous theme   . next theme (global shortcut, works on every screen).
#     +/- refresh interval     t full speed test (inside + global, upload + download)
#     Settings toggles scan for each of GLOBAL/INSIDE providers, sites and mirrors.
#     k glossary of every term x privacy mode: hides IP / SSID / gateway / proxy
#     j inspect and test the active package mirrors configured on this system
#
#  INSTALL / UNINSTALL
#     First interactive run offers System-wide, Local, or Demo mode. The choice
#     is stored in ~/.config/SakuraSuit/sakura_netscope/install.conf (Demo is optional).
#     Local installs to ~/.local/bin/sakurasuit; System-wide installs to /usr/local/bin and
#     /usr/share/applications using sudo only for system files; Demo installs nothing.
#     A newer VERSION updates an existing installation atomically; older files do
#     not silently downgrade it. Settings shows version, install mode and removal help.
#     How to uninstall: sakura-netscope --uninstall or Settings > Uninstall.
#
#  DEPENDENCIES (classified in the first-run Requirements panel)
#     MUST       : bash >= 4 and at least one usable probe backend:
#                  working ping (ICMP), curl, wget, or dig / host / nslookup.
#     RECOMMENDED: curl (HTTPS + Speed Test), ping (ICMP), wget (HTTPS fallback),
#                  iproute2 (ip), coreutils (timeout).
#     OPTIONAL   : getent / DNS utilities, Wi-Fi tools (iwgetid / iw / nmcli),
#                  pgrep / pkill. Missing optional tools only disable their feature.
#     Missing tools are also reported in the diagnostics screen (g / --diag).
#
#  FILES (all under $HOME)
#     ~/.local/bin/sakurasuit/sakura-netscope      local installed copy
#     /usr/local/bin/sakura-netscope                system-wide installed copy
#     ~/.local/share/applications/*.desktop        local menu entry
#     /usr/share/applications/sakura-netscope.desktop system-wide menu entry
#     ~/.config/SakuraSuit/sakura_netscope/settings.conf settings
#     ~/.config/SakuraSuit/sakura_netscope/providers.conf optional custom providers
#     ~/.config/SakuraSuit/sakura_netscope/speedtest.conf optional speed-test servers
# =============================================================================

if [ -z "${BASH_VERSION:-}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    printf 'Sakura NetScope needs bash 4 or newer.\n' >&2
    exit 1
fi
set -u
shopt -s extglob

APP="sakura-netscope"
VERSION="1.0"
SELF="$(readlink -f -- "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
INSTALL_MODE="" # system | local | demo; stored in install.conf
APP_DIR="sakura_netscope"
INSTALL_DIR="$HOME/.local/bin/sakurasuit"
INSTALL_PATH="$INSTALL_DIR/$APP"
DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
DESKTOP_FILE="$DESKTOP_DIR/$APP.desktop"
SUIT_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/SakuraSuit"
CONF_DIR="$SUIT_CONFIG_DIR/$APP_DIR"
LEGACY_CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$APP"
LEGACY_LOCAL_PATH="$HOME/.local/bin/$APP"
SETTINGS_FILE="$CONF_DIR/settings.conf"
INSTALL_CONF="$CONF_DIR/install.conf"
PROVIDERS_FILE="$CONF_DIR/providers.conf"
BACKUP_DIR="$HOME/Downloads"
ORIG_PATH="$PATH"

# ── Settings (defaults; override in settings.conf or via the settings screen) ─
INTERVAL=5            # seconds between probe cycles (counted from cycle end)
SETTINGS_MIGRATED=0
WINDOW=20             # rolling history length, in cycles
MIN_SAMPLES=1         # show a verdict from the first completed probe
PROBE_TIMEOUT=2       # seconds per single probe
DEGRADED_RTT=150      # ms; a reachable provider slower than this is DEGRADED
GLOBAL_VIA_PROXY=0    # 1 = GLOBAL HTTPS probes go through the proxy
PROXY_URL="${NETSCOPE_PROXY:-}"
DNS_TEST_HOST="example.com"
UI_ASCII=-1           # -1 auto, 0 unicode, 1 ascii
CYCLE_MAX=15          # hard watchdog; timed-out children are terminated
MAX_PARALLEL_PROBES=16 # bounded workers; launched by a background scheduler so UI stays responsive
ENV_DEEP_INTERVAL=15   # refresh gateway/DNS/proxy reachability less often than link rates

# Independent scan switches. Disabled sections keep their last sample but issue no probes.
SCAN_GLOBAL_PROVIDERS=1
SCAN_GLOBAL_SITES=1
SCAN_INSIDE_PROVIDERS=1
SCAN_INSIDE_SITES=1
SCAN_GLOBAL_MIRRORS=1
SCAN_INSIDE_MIRRORS=1

# ── Default providers ────────────────────────────────────────────────────────
# Format:  Name|host|checks|note        checks = icmp,https,dns (comma list)
# Sections: [global] [global-sites] [inside] [inside-sites]
#           [mirrors-global] [mirrors-inside]   (Linux package mirrors, flatpak, snap)
# *-sites entries are drawn below a "SITES" separator line.
# Every list is ordered by importance (size of the company / how central it is).
# Operator, cloud, site and mirror hostnames are the services' own domains; their
# hosting is NOT verified from here. Edit providers.conf to use endpoints you
# have verified yourself.
read -r -d '' DEFAULT_PROVIDERS <<'EOF'
[global]
Google DNS|8.8.8.8|icmp,https|Google Public DNS
Cloudflare|1.1.1.1|icmp,https|Cloudflare resolver / backbone / CDN
AWS|aws.amazon.com|icmp,https|Amazon Web Services
Azure|azure.microsoft.com|icmp,https|Microsoft Azure
Akamai|www.akamai.com|icmp,https|Akamai CDN
NTT|ntt.com|icmp,https|NTT Global IP Network (tier-1)
Lumen/Level3|4.2.2.2|icmp,dns|Lumen / Level3 tier-1 resolver
Alibaba Cloud|www.alibabacloud.com|icmp,https|Alibaba Cloud (China / Asia)
Cogent|cogentco.com|icmp,https|Cogent tier-1 transit
DigitalOcean|www.digitalocean.com|icmp,https|DigitalOcean

[global-sites]
google.com|google.com|icmp,https|Google
youtube.com|youtube.com|icmp,https|YouTube
facebook.com|facebook.com|icmp,https|Facebook
instagram.com|instagram.com|icmp,https|Instagram
whatsapp.com|whatsapp.com|icmp,https|WhatsApp
x.com|x.com|icmp,https|X (Twitter)
wikipedia.org|www.wikipedia.org|icmp,https|Wikimedia
telegram.org|telegram.org|icmp,https|Telegram
github.com|github.com|icmp,https|GitHub
netflix.com|netflix.com|icmp,https|Netflix

[inside]
Hamrah Aval|mci.ir|icmp,https|MCI / Hamrah Aval operator website (hosting not verified)
Irancell|irancell.ir|icmp,https|Irancell operator website (hosting not verified)
Mokhaberat|tci.ir|icmp,https|TCI - Telecommunication Co. of Iran website (hosting not verified)
Shatel|shatel.ir|icmp,https|Shatel operator website (hosting not verified)
ArvanCloud|arvancloud.ir|icmp,https|ArvanCloud cloud / CDN (hosting not verified)
Asiatech|asiatech.ir|icmp,https|Asiatech operator website (hosting not verified)
Rightel|rightel.ir|icmp,https|Rightel operator website (hosting not verified)
ParsPack|parspack.com|icmp,https|ParsPack cloud hosting (hosting not verified)
IranServer|iranserver.com|icmp,https|IranServer hosting (hosting not verified)
Hamravesh|hamravesh.com|icmp,https|Hamravesh cloud platform (hosting not verified)

[inside-sites]
digikala.com|digikala.com|icmp,https|Digikala
aparat.com|aparat.com|icmp,https|Aparat
divar.ir|divar.ir|icmp,https|Divar
snapp.ir|snapp.ir|icmp,https|Snapp
rubika.ir|rubika.ir|icmp,https|Rubika messenger
eitaa.com|eitaa.com|icmp,https|Eitaa messenger
splus.ir|splus.ir|icmp,https|Soroush Plus messenger (domain from memory, verify)
bale.ai|bale.ai|icmp,https|Bale messenger
cafebazaar.ir|cafebazaar.ir|icmp,https|Cafe Bazaar
namava.ir|namava.ir|icmp,https|Namava

[mirrors-global]
Arch|geo.mirror.pkgbuild.com|https|Arch Linux package mirror endpoint
Debian|deb.debian.org|https|Debian package archive
Fedora|dl.fedoraproject.org|https|Fedora package repositories
Ubuntu|archive.ubuntu.com|https|Ubuntu package archive
Nix|cache.nixos.org|https|Nix binary cache
Flathub|dl.flathub.org|https|Flathub application repository

[mirrors-inside]
Isfahan U|repo.iut.ac.ir|https|Isfahan University of Technology; supports Arch, Debian, Ubuntu, Fedora and more
Shatel|mirror.shatel.ir|https|Iranian Ubuntu and Debian mirror
Mobinhost|mirror.mobinhost.com|https|Iranian multi-distro mirror (Arch, Manjaro, Debian, Ubuntu and Fedora)
IranServer|mirror.iranserver.com|https|Iranian Debian and Ubuntu mirrors
PardisCo|mirrors.pardisco.co|https|Iranian Linux and programming package mirrors
ITO|repo-portal.ito.gov.ir|https|Information Technology Organization repository portal
EOF

# ── Central theme palette / glyphs ────────────────────────────────────────────
USE_COLOR=1
ESC=$'\e'
THEME="violet-purple"
THEME_SLUGS=(hanakage joyful-sea emerald-green sunset-yellow clean-white aqualume violet-purple coffee-brown kohaku matcha-garden midnight-tide momiji-ember neon-shibuya wisteria-dream indigo-washi jade-dynasty frostbite cyberneon anta-baka soulless-moon calm-whisper retro-bit darkly-rose lightly-rose galactic-silence)
THEME_NAMES=("Hanakage" "Joyful Sea" "Emerald Green" "Sunset Yellow" "Clean White" "Aqualume" "Violet Purple" "Coffee Brown" "Kōhaku" "Matcha Garden" "Midnight Tide" "Momiji Ember" "Neon Shibuya" "Wisteria Dream" "Indigo Washi" "Jade Dynasty" "Frostbite" "Cyberneon" "Anta Baka" "Soulless Moon" "Calm Whisper" "Retro Bit" "Darkly Rose" "Lightly Rose" "Galactic Silence")
# Eight roles: primary secondary label ok warn error muted trunk.
# Core themes use xterm-256 indexes; character themes use exact RGB hex entries.
THEME_CODES=(
    "218 211 117 114 222 203 245 137" # Hanakage
    "45 39 159 121 221 203 245 94"     # Joyful Sea
    "78 36 152 156 222 203 245 94"     # Emerald Green
    "221 208 223 114 209 203 245 130"  # Sunset Yellow
    "255 250 153 114 222 203 244 245"  # Clean White
    "123 75 195 121 229 210 109 67"   # Aqualume
    "141 135 183 114 222 203 245 96"   # Violet Purple
    "130 137 223 114 222 203 245 94"   # Coffee Brown
    "160 203 231 114 222 124 245 240"  # Kohaku
    "107 149 230 151 222 203 245 94"   # Matcha Garden
    "25 39 153 121 221 203 245 60"     # Midnight Tide
    "160 166 222 114 220 124 245 130"  # Momiji Ember
    "45 201 117 121 220 203 245 99"   # Neon Shibuya
    "183 141 189 151 222 203 245 97"  # Wisteria Dream
    "25 61 189 114 222 203 245 137"   # Indigo Washi
    "36 78 152 156 220 203 245 130"   # Jade Dynasty
    "117 153 195 159 229 203 245 109" # Frostbite
    "46 118 190 154 226 203 245 94"   # Cyberneon
    "#D52B35 #F07832 #FFD166 #87D787 #FFD166 #D52B35 #A69AA1 #2D2029" # Anta Baka
    "#607FC4 #A7C7ED #A7C7ED #87D787 #FFD787 #C74954 #6D7890 #242B3B" # Soulless Moon
    "#45BFC1 #3B78B5 #D8C66D #87D787 #D8C66D #FF5F5F #7C8796 #273A55" # Calm Whisper
    "#F34AA6 #27D9E8 #8C5BFA #87D787 #FFD166 #FF5F5F #8175B8 #252047" # Retro Bit
    "#7548A8 #558FBC #558FBC #87D787 #F3EFC1 #D94E61 #DBDDE2 #43469A" # Darkly Rose
    "#7548A8 #558FBC #43469A #2F7D57 #9A7925 #B13B50 #777A86 #43469A" # Lightly Rose
    "#5999F4 #984B61 #9DBAFF #87D787 #FFD787 #FF5F5F #6554B5 #151A43" # Galactic Silence
)
theme_index() {
    local i
    for ((i=0; i<${#THEME_SLUGS[@]}; i++)); do
        [[ ${THEME_SLUGS[i]} == "$1" ]] && { printf '%d' "$i"; return 0; }
    done
    return 1
}
theme_name() { local i; i=$(theme_index "$1") || i=0; printf '%s' "${THEME_NAMES[i]}"; }
theme_step() {
    local delta=$1 i
    i=$(theme_index "$THEME") || i=0
    i=$(( (i + delta + ${#THEME_SLUGS[@]}) % ${#THEME_SLUGS[@]} ))
    THEME=${THEME_SLUGS[i]}
}
theme_shortcut() { # delta: -1 previous, +1 next; called by the central key reader
    theme_step "$1"
    init_colors
    FOREST_W=-1
    FOREST_CACHE_KEY=""
    FOREST_CACHE_DATA=()
    FOREST_CACHE_KEYS=()
    save_settings
    KEY=THEME_CHANGED
}
set_theme_foreground() { # variable_name, xterm index or exact #RRGGBB
    local target=$1 value=$2 r g b
    if [[ $value =~ ^#[[:xdigit:]]{6}$ ]]; then
        r=$((16#${value:1:2})); g=$((16#${value:3:2})); b=$((16#${value:5:2}))
        printf -v "$target" '\e[38;2;%d;%d;%dm' "$r" "$g" "$b"
    else
        printf -v "$target" '\e[38;5;%sm' "$value"
    fi
}
init_colors() {
    local i p s l ok warn err mut trunk
    if (( ! USE_COLOR )); then
        PINK=''; ROSE=''; CYAN=''; GREEN=''; YELLOW=''; RED=''; GRAY=''; BROWN=''
        BOLD=''; DIM=''; RESET=''; REV=''
        return
    fi
    i=$(theme_index "$THEME") || { THEME=violet-purple; i=6; }
    read -r p s l ok warn err mut trunk <<< "${THEME_CODES[i]}"
    set_theme_foreground PINK "$p"
    set_theme_foreground ROSE "$s"
    set_theme_foreground CYAN "$l"
    set_theme_foreground GREEN "$ok"
    set_theme_foreground YELLOW "$warn"
    set_theme_foreground RED "$err"
    set_theme_foreground GRAY "$mut"
    set_theme_foreground BROWN "$trunk"
    BOLD=$'\e[1m'; DIM=$'\e[2m'; RESET=$'\e[0m'; REV=$'\e[7m'
    if [[ $THEME == lightly-rose ]]; then
        # Keep the same light surface and cream selection, but combine each
        # foreground/background reset into a single SGR control sequence.
        # This avoids emitting three separate ANSI commands for every styled
        # fragment during full-screen redraws, without changing the palette.
        RESET=$'\e[0;38;2;67;70;154;48;2;219;221;226m'
        REV=$'\e[38;2;67;70;154;48;2;243;239;193m'
    fi
}

detect_unicode() {
    local cm
    [[ ${TERM:-} == linux ]] && return 1
    cm="$(locale charmap 2>/dev/null || true)"
    cm="${cm^^}"
    [[ $cm == UTF-8 || $cm == UTF8 ]]
}

init_glyphs() {
    if (( UI_ASCII == -1 )); then
        if detect_unicode; then UI_ASCII=0; else UI_ASCII=1; fi
    fi
    if (( UI_ASCII )); then
        B_TL='+'; B_TR='+'; B_BL='+'; B_BR='+'; B_H='-'; B_V='|'; B_ML='+'; B_MR='+'
        BAR_FULL='#'; BAR_EMPTY='-'; G_OK='+'; G_BAD='x'; G_WARN='!'; G_UNK='?'; G_DOT='.'
        G_UP='^'; G_DN='v'; G_MARK='>'; G_BLOSSOM='*'; G_MARK2='>>'
    else
        B_TL='╭'; B_TR='╮'; B_BL='╰'; B_BR='╯'; B_H='─'; B_V='│'; B_ML='├'; B_MR='┤'
        BAR_FULL='━'; BAR_EMPTY='─'; G_OK='✓'; G_BAD='✗'; G_WARN='!'; G_UNK='?'; G_DOT='·'
        G_UP='▲'; G_DN='▼'; G_MARK='▶'; G_BLOSSOM='✿'; G_MARK2='▶▶'
    fi
}

# ── Small utilities ──────────────────────────────────────────────────────────
have() { command -v "$1" >/dev/null 2>&1; }

set_num() { # var value min max
    [[ $2 =~ ^[0-9]+$ ]] || return 1
    (( 10#$2 >= $3 && 10#$2 <= $4 )) || return 1
    printf -v "$1" '%d' "$((10#$2))"
}

trim() { local s=$1; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

# strip colour codes (result in STRIPPED). Literal replacements of the known
# codes are ~60x faster than the extglob pattern, which stays as a safety net.
strip_sgr() {
    local s=$1
    s=${s//"$PINK"/}; s=${s//"$ROSE"/}; s=${s//"$CYAN"/}; s=${s//"$GREEN"/}
    s=${s//"$YELLOW"/}; s=${s//"$RED"/}; s=${s//"$GRAY"/}; s=${s//"$BROWN"/}
    s=${s//"$BOLD"/}; s=${s//"$DIM"/}; s=${s//"$RESET"/}; s=${s//"$REV"/}
    [[ $s == *"$ESC"* ]] && s=${s//"$ESC"\[*([0-9;])m/}
    STRIPPED=$s
}

# visible length of a string containing colour codes (result in VL)
vlen() { strip_sgr "$1"; VL=${#STRIPPED}; }

# pad/truncate to a visible width (result in PADDED)
padr() {
    local s=$1 w=$2
    vlen "$s"
    if (( VL > w )); then
        strip_sgr "$s"
        s=${STRIPPED:0:w}
        VL=${#s}
    fi
    printf -v PADDED '%s%s%*s' "$s" "$RESET" $(( w - VL )) ''
}

hline() { printf -v HL '%*s' "$(( $1 < 0 ? 0 : $1 ))" ''; HL=${HL// /$B_H}; }

now_ms() {
    if [[ -n ${EPOCHREALTIME:-} ]]; then
        local s=${EPOCHREALTIME%[.,]*} f=${EPOCHREALTIME#*[.,]}
        NOW_MS=$(( 10#$s * 1000 + 10#${f:0:3} ))
    else
        NOW_MS=$(( $(date +%s) * 1000 ))
    fi
}

TIMEOUT_BIN=""
run_to() { local s=$1; shift; if [[ -n $TIMEOUT_BIN ]]; then "$TIMEOUT_BIN" "$s" "$@"; else "$@"; fi; }

# ── Tool detection ───────────────────────────────────────────────────────────
PING_BIN=""; CURL_BIN=""; WGET_BIN=""; IP_BIN=""; DNS_TOOL=""; SYS_DNS_TOOL=""
IW_BIN=""; IWGETID_BIN=""; NMCLI_BIN=""; PGREP_BIN=""; PKILL_BIN=""
ICMP_OK=0; ICMP_NOTE=""

detect_tools() {
    TIMEOUT_BIN="$(command -v timeout 2>/dev/null || true)"
    PING_BIN="$(command -v ping 2>/dev/null || true)"
    CURL_BIN="$(command -v curl 2>/dev/null || true)"
    WGET_BIN="$(command -v wget 2>/dev/null || true)"
    IP_BIN="$(command -v ip 2>/dev/null || true)"
    IW_BIN="$(command -v iw 2>/dev/null || true)"
    IWGETID_BIN="$(command -v iwgetid 2>/dev/null || true)"
    NMCLI_BIN="$(command -v nmcli 2>/dev/null || true)"
    PGREP_BIN="$(command -v pgrep 2>/dev/null || true)"
    PKILL_BIN="$(command -v pkill 2>/dev/null || true)"
    DNS_TOOL=""
    local t
    for t in dig nslookup host; do
        if have "$t"; then DNS_TOOL="$t"; break; fi
    done
    SYS_DNS_TOOL=""
    for t in getent host nslookup dig; do
        if have "$t"; then SYS_DNS_TOOL="$t"; break; fi
    done
    ICMP_OK=0
    if [[ -z $PING_BIN ]]; then
        ICMP_NOTE="ping is not installed"
    elif LC_ALL=C run_to 3 "$PING_BIN" -c 1 -W 1 127.0.0.1 >/dev/null 2>&1; then
        ICMP_OK=1; ICMP_NOTE="ICMP usable"
    else
        ICMP_NOTE="ping exists but cannot send ICMP (no permission?) — HTTPS/DNS probes are used instead"
    fi
}

# Migrate the previous per-app config directory into SakuraSuit without overwriting
# any files that already exist in the new location.
migrate_legacy_config() {
    local f
    [[ -d $LEGACY_CONF_DIR ]] || return 0
    mkdir -p -- "$CONF_DIR" 2>/dev/null || return 0
    for f in settings.conf install.conf providers.conf speedtest.conf; do
        if [[ -f "$LEGACY_CONF_DIR/$f" && ! -e "$CONF_DIR/$f" ]]; then
            cp -p -- "$LEGACY_CONF_DIR/$f" "$CONF_DIR/$f" 2>/dev/null || true
        fi
    done
}

# ── Install mode ──────────────────────────────────────────────────────────────
load_install_mode() {
    local value=""
    if [[ -f $INSTALL_CONF ]]; then
        value="$(sed -n 's/^mode=//p' "$INSTALL_CONF" | head -n1)"
    fi
    case $value in system|local|demo) INSTALL_MODE=$value ;; *) INSTALL_MODE="" ;; esac
    # Upgrade path for copies installed by older NetScope versions.
    if [[ -z $INSTALL_MODE && ( -x "$LEGACY_LOCAL_PATH" || -x "$INSTALL_PATH" ) ]]; then INSTALL_MODE=local; fi
    return 0
}

save_install_mode() {
    local value=$1
    mkdir -p -- "$CONF_DIR" 2>/dev/null || return 1
    ( umask 077; printf '# Sakura NetScope installation mode\nmode=%s\n' "$value" > "$INSTALL_CONF" ) || return 1
    INSTALL_MODE=$value
    set_install_paths
}

set_install_paths() {
    case ${INSTALL_MODE:-local} in
        system)
            INSTALL_DIR=/usr/local/bin; INSTALL_PATH="$INSTALL_DIR/$APP"
            DESKTOP_DIR=/usr/share/applications; DESKTOP_FILE="$DESKTOP_DIR/$APP.desktop" ;;
        demo)
            INSTALL_DIR="$HOME/.local/bin/sakurasuit"; INSTALL_PATH="$INSTALL_DIR/$APP"
            DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"; DESKTOP_FILE="$DESKTOP_DIR/$APP.desktop" ;;
        *)
            INSTALL_DIR="$HOME/.local/bin/sakurasuit"; INSTALL_PATH="$INSTALL_DIR/$APP"
            DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"; DESKTOP_FILE="$DESKTOP_DIR/$APP.desktop" ;;
    esac
}

# ── Installer requirements ───────────────────────────────────────────────────
# One usable backend is enough for the monitor to start. Individual tools in
# the recommended/optional groups only unlock additional capabilities.
requirements_probe_ok() {
    (( ICMP_OK )) || [[ -n $CURL_BIN || -n $WGET_BIN || -n $DNS_TOOL ]]
}

requirement_item() { # label available detail -> REQ_LINE
    local label=$1 available=$2 detail=${3:-} icon tone
    if [[ $available == 1 ]]; then
        icon="${GREEN}${G_OK}${RESET}"; tone=$GREEN
    else
        icon="${RED}${G_BAD}${RESET}"; tone=$RED
    fi
    REQ_LINE="$icon ${tone}${label}${RESET}"
    [[ -n $detail ]] && REQ_LINE+=" ${GRAY}· ${detail}${RESET}"
}

append_requirements_box() {
    local rw i wifi_ok dns_ok proc_ok ping_note
    get_size
    rw=$(( COLS - 8 ))
    (( rw > 86 )) && rw=86
    (( rw < 42 )) && rw=$(( COLS - 4 ))
    (( rw < 32 )) && rw=32

    box_top "$rw" "Requirements" "$CYAN"; SCREEN+=("$BOX")

    box_mid "$rw" "MUST BE INSTALLED" "$CYAN"; SCREEN+=("$BOX")
    requirement_item "Bash >= 4" "$(( BASH_VERSINFO[0] >= 4 ))" "runtime"
    box_row "$rw" "$REQ_LINE" "$CYAN"; SCREEN+=("$BOX")
    if requirements_probe_ok; then i=1; else i=0; fi
    requirement_item "Probe backend" "$i" "any one: ping / curl / wget / DNS"
    box_row "$rw" "$REQ_LINE" "$CYAN"; SCREEN+=("$BOX")

    box_mid "$rw" "BETTER TO INSTALL" "$CYAN"; SCREEN+=("$BOX")
    requirement_item "curl" "$([[ -n $CURL_BIN ]] && echo 1 || echo 0)" "HTTPS probes + Speed Test"
    box_row "$rw" "$REQ_LINE" "$CYAN"; SCREEN+=("$BOX")
    ping_note="ICMP latency checks"
    [[ -n $PING_BIN && $ICMP_OK == 0 ]] && ping_note="installed; ICMP permission unavailable"
    requirement_item "ping" "$([[ -n $PING_BIN ]] && echo 1 || echo 0)" "$ping_note"
    box_row "$rw" "$REQ_LINE" "$CYAN"; SCREEN+=("$BOX")
    requirement_item "wget" "$([[ -n $WGET_BIN ]] && echo 1 || echo 0)" "HTTPS fallback"
    box_row "$rw" "$REQ_LINE" "$CYAN"; SCREEN+=("$BOX")
    requirement_item "ip" "$([[ -n $IP_BIN ]] && echo 1 || echo 0)" "iproute2 · route details"
    box_row "$rw" "$REQ_LINE" "$CYAN"; SCREEN+=("$BOX")
    requirement_item "timeout" "$([[ -n $TIMEOUT_BIN ]] && echo 1 || echo 0)" "coreutils · probe limits"
    box_row "$rw" "$REQ_LINE" "$CYAN"; SCREEN+=("$BOX")

    box_mid "$rw" "OPTIONAL" "$CYAN"; SCREEN+=("$BOX")
    dns_ok=0; [[ -n $SYS_DNS_TOOL ]] && dns_ok=1
    requirement_item "DNS lookup" "$dns_ok" "getent / dig / host / nslookup"
    box_row "$rw" "$REQ_LINE" "$CYAN"; SCREEN+=("$BOX")
    wifi_ok=0; [[ -n $IWGETID_BIN || -n $IW_BIN || -n $NMCLI_BIN ]] && wifi_ok=1
    requirement_item "Wi-Fi details" "$wifi_ok" "iwgetid / iw / nmcli"
    box_row "$rw" "$REQ_LINE" "$CYAN"; SCREEN+=("$BOX")
    # Keep both cleanup helpers visible, with independent install status.
    requirement_item "pgrep" "$([[ -n $PGREP_BIN ]] && echo 1 || echo 0)" "process detection"
    local pgrep_line=$REQ_LINE
    requirement_item "pkill" "$([[ -n $PKILL_BIN ]] && echo 1 || echo 0)" "cleanup"
    REQ_LINE="$pgrep_line   $REQ_LINE"
    box_row "$rw" "$REQ_LINE" "$CYAN"; SCREEN+=("$BOX")

    box_bottom "$rw" "" "$CYAN"; SCREEN+=("$BOX")
}

choose_install_mode() {
    local selected=2 redraw=1 remembered=1 choice_rc last_cols=-1 last_rows=-1
    local -a choices=("System-wide install" "Local install" "Demo mode")
    while true; do
        # Do not depend only on SIGWINCH: some terminals/multiplexers can delay
        # or drop it. Compare the actual dimensions on each installer-loop wake.
        get_size
        if (( COLS != last_cols || ROWS != last_rows )); then
            last_cols=$COLS; last_rows=$ROWS; redraw=1
        fi
        if (( RESIZED )); then RESIZED=0; redraw=1; fi
        if (( redraw )); then
            SCREEN=("${BOLD}${PINK}SAKURA NETSCOPE${RESET}" "Choose how Sakura NetScope should run on this computer.")
            append_requirements_box
            if requirements_probe_ok; then
                local i line
                for ((i=0; i<${#choices[@]}; i++)); do
                    if ((i==selected)); then line="${ROSE}${G_MARK}${RESET} ${BOLD}${choices[i]}${RESET}"; else line="  ${choices[i]}"; fi
                    SCREEN+=("$line")
                done
            else
                SCREEN+=("${RED}${G_BAD} Installation blocked: a required probe backend is missing.${RESET}")
                SCREEN+=("${GRAY}Install at least one of: working ping, curl, wget, dig, host or nslookup.${RESET}")
            fi
            draw_screen "First-run setup" "Up/Down select   Enter confirm   ,/. change theme   q quit"
            redraw=0
        fi
        if ! read_key 0.25; then
            # The next loop-top poll catches a resize even if SIGWINCH was not
            # delivered. A resize redraw must never need an arrow key.
            continue
        fi
        # A key and resize can arrive together. Preserve the key, but schedule
        # a resize redraw with the newly measured dimensions.
        get_size
        if (( RESIZED )); then RESIZED=0; redraw=1; fi
        if (( COLS != last_cols || ROWS != last_rows )); then
            last_cols=$COLS; last_rows=$ROWS; redraw=1
        fi
        case $KEY in
            THEME_CHANGED) redraw=1 ;;
            UP|k) if requirements_probe_ok; then (( selected>0 )) && selected=$((selected-1)); redraw=1; fi ;;
            DOWN|j) if requirements_probe_ok; then (( selected<2 )) && selected=$((selected+1)); redraw=1; fi ;;
            q|Q|ESC) tty_leave; return 2 ;;
            ENTER)
                requirements_probe_ok || return 1
                case $selected in 0) INSTALL_MODE=system ;; 1) INSTALL_MODE=local ;; 2) INSTALL_MODE=demo ;; esac
                tty_leave
                if [[ $INSTALL_MODE == demo ]]; then
                    ask_yes_no "Remember Demo mode for future launches?" n
                    remembered=0; [[ $REPLY == y ]] && remembered=1
                fi
                if (( remembered )); then save_install_mode "$INSTALL_MODE" || { printf 'Could not save installation mode in %s\n' "$INSTALL_CONF" >&2; return 1; }
                else rm -f -- "$INSTALL_CONF"; set_install_paths; fi
                return 0 ;;
        esac
    done
}

# ── Configuration ────────────────────────────────────────────────────────────
load_settings() {
    local k v
    [[ -f $SETTINGS_FILE ]] || return 0
    while IFS='=' read -r k v || [[ -n $k ]]; do
        k="$(trim "${k%$'\r'}")"
        [[ -z $k || $k == \#* ]] && continue
        v="$(trim "${v%$'\r'}")"; v="${v#\"}"; v="${v%\"}"
        case $k in
            interval)
                # Migrate the old one-second default to a safer five-second refresh.
                if [[ $v == 1 ]]; then INTERVAL=5; SETTINGS_MIGRATED=1; else set_num INTERVAL "$v" 2 60; fi ;;
            scan_global_providers) [[ $v == 0 || $v == 1 ]] && SCAN_GLOBAL_PROVIDERS=$v ;;
            scan_global_sites)     [[ $v == 0 || $v == 1 ]] && SCAN_GLOBAL_SITES=$v ;;
            scan_inside_providers) [[ $v == 0 || $v == 1 ]] && SCAN_INSIDE_PROVIDERS=$v ;;
            scan_inside_sites)     [[ $v == 0 || $v == 1 ]] && SCAN_INSIDE_SITES=$v ;;
            scan_global_mirrors)   [[ $v == 0 || $v == 1 ]] && SCAN_GLOBAL_MIRRORS=$v ;;
            scan_inside_mirrors)   [[ $v == 0 || $v == 1 ]] && SCAN_INSIDE_MIRRORS=$v ;;
            window)           set_num WINDOW "$v" 3 200 ;;
            min_samples)      set_num MIN_SAMPLES "$v" 1 1 ;; # use first-sample feedback; avoid long artificial warm-up
            probe_timeout)    set_num PROBE_TIMEOUT "$v" 1 15 ;;
            degraded_rtt)     set_num DEGRADED_RTT "$v" 10 5000 ;;
            global_via_proxy) [[ $v == 0 || $v == 1 ]] && GLOBAL_VIA_PROXY=$v ;;
            ascii)            [[ $v == 0 || $v == 1 ]] && UI_ASCII=$v ;;
            theme)
                case $v in
                    sakura) v=hanakage; SETTINGS_MIGRATED=1 ;;
                    aero-water) v=aqualume; SETTINGS_MIGRATED=1 ;;
                    red-white) v=kohaku; SETTINGS_MIGRATED=1 ;;
                esac
                theme_index "$v" >/dev/null && THEME=$v ;;
            dns_test_host)    [[ $v =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] && DNS_TEST_HOST=$v ;;
            proxy_url)        [[ -z ${NETSCOPE_PROXY:-} && $v =~ ^[^[:space:]]*$ ]] && PROXY_URL=$v ;;
        esac
    done < "$SETTINGS_FILE"
    (( MIN_SAMPLES > WINDOW )) && MIN_SAMPLES=$WINDOW
    return 0
}

save_settings() {
    mkdir -p -- "$CONF_DIR" 2>/dev/null || return 1
    (
        umask 077
        {
            printf '# Sakura NetScope settings\n'
            printf 'interval=%s\nwindow=%s\nmin_samples=%s\nprobe_timeout=%s\ndegraded_rtt=%s\n' \
                "$INTERVAL" "$WINDOW" "$MIN_SAMPLES" "$PROBE_TIMEOUT" "$DEGRADED_RTT"
            printf 'global_via_proxy=%s\nascii=%s\ntheme=%s\ndns_test_host=%s\n' "$GLOBAL_VIA_PROXY" "$UI_ASCII" "$THEME" "$DNS_TEST_HOST"
            printf 'scan_global_providers=%s\nscan_global_sites=%s\nscan_inside_providers=%s\nscan_inside_sites=%s\nscan_global_mirrors=%s\nscan_inside_mirrors=%s\n' \
                "$SCAN_GLOBAL_PROVIDERS" "$SCAN_GLOBAL_SITES" "$SCAN_INSIDE_PROVIDERS" "$SCAN_INSIDE_SITES" "$SCAN_GLOBAL_MIRRORS" "$SCAN_INSIDE_MIRRORS"
            [[ -z ${NETSCOPE_PROXY:-} ]] && printf 'proxy_url=%s\n' "$PROXY_URL"
        } > "$SETTINGS_FILE"
    )
}

# Providers ------------------------------------------------------------------
NPROV=0
P_NAME=(); P_HOST=(); P_CHK=(); P_NOTE=(); P_CAT=(); P_GRP=()
P_HIST=(); P_IHIST=(); P_RTTS=(); P_LASTRTT=(); P_CURRTT=(); P_VIA=()
P_ICMP=(); P_HTTPS=(); P_HCODE=(); P_HMS=(); P_DNS=()
LIST0=""; LIST1=""; LIST2=""; LIST3=""
SITE_START=(-1 -1 -1 -1); LCNT=(0 0 0 0); NSEP=(0 0)
COL_G=(); COL_GS=(); COL_I=(); COL_IS=(); COL_GM=(); COL_IM=()

validate_provider() { # name host checks
    local name host chk t
    name="$(trim "$1")"; host="$(trim "$2")"; chk="${3//[[:space:]]/}"
    [[ -n $name && ${#name} -le 20 ]] || return 1
    [[ $host =~ ^([A-Za-z0-9][A-Za-z0-9._:-]*|https?://[A-Za-z0-9][A-Za-z0-9._:-]*(/[A-Za-z0-9._~:/?%+\$-]*)?)$ ]] || return 1
    [[ -n $chk ]] || chk="icmp,https"
    [[ $host == http://* || $host == https://* ]] && [[ ,$chk, != *,icmp,* ]] && return 1
    local -a toks
    IFS=',' read -ra toks <<< "$chk"
    for t in "${toks[@]}"; do
        case $t in icmp|https|dns) ;; *) return 1 ;; esac
    done
    return 0
}

collect_providers() { # text -> COL_* arrays (validated raw lines)
    COL_G=(); COL_GS=(); COL_I=(); COL_IS=(); COL_GM=(); COL_IM=()
    local sec="" line name host chk note
    while IFS= read -r line; do
        line="$(trim "${line%$'\r'}")"
        [[ -z $line || $line == \#* ]] && continue
        case "${line,,}" in
            "[global]")                             sec=g;  continue ;;
            "[global-sites]"|"[global_sites]")      sec=gs; continue ;;
            "[inside]")                             sec=i;  continue ;;
            "[inside-sites]"|"[inside_sites]")      sec=is; continue ;;
            "[mirrors-global]"|"[global-mirrors]")  sec=gm; continue ;;
            "[mirrors-inside]"|"[inside-mirrors]")  sec=im; continue ;;
        esac
        [[ -n $sec ]] || continue
        IFS='|' read -r name host chk note <<< "$line"
        validate_provider "$name" "${host:-}" "${chk:-}" || continue
        case $sec in
            g)  COL_G+=("$line") ;;
            gs) COL_GS+=("$line") ;;
            i)  COL_I+=("$line") ;;
            is) COL_IS+=("$line") ;;
            gm) COL_GM+=("$line") ;;
            im) COL_IM+=("$line") ;;
        esac
    done <<< "$1"
}

add_provider() { # cat(0 global,1 inside,2 global mirrors,3 inside mirrors) grp rawline
    local name host chk note
    IFS='|' read -r name host chk note <<< "$3"
    name="$(trim "$name")"; host="$(trim "$host")"; chk="${chk//[[:space:]]/}"
    [[ -n $chk ]] || chk="icmp,https"
    P_NAME[NPROV]=$name; P_HOST[NPROV]=$host; P_CHK[NPROV]=$chk; P_NOTE[NPROV]="$(trim "${note:-}")"
    P_CAT[NPROV]=$1; P_GRP[NPROV]=$2
    P_HIST[NPROV]=""; P_IHIST[NPROV]=""; P_RTTS[NPROV]=""; P_LASTRTT[NPROV]="-"; P_CURRTT[NPROV]="-"
    P_VIA[NPROV]="-"; P_ICMP[NPROV]=na; P_HTTPS[NPROV]=na; P_HCODE[NPROV]="-"; P_HMS[NPROV]="-"; P_DNS[NPROV]=na
    if [[ $2 == 1 && ${SITE_START[$1]} -lt 0 ]]; then SITE_START[$1]=${LCNT[$1]}; fi
    LCNT[$1]=$(( ${LCNT[$1]} + 1 ))
    case $1 in
        0) LIST0+="$NPROV " ;; 1) LIST1+="$NPROV " ;; 2) LIST2+="$NPROV " ;; *) LIST3+="$NPROV " ;;
    esac
    NPROV=$(( NPROV + 1 ))
}

load_providers() {
    local -a eg egs ei eis egm eim usergm userim legacygm legacyim legacyim_current
    local l item found local_match migrate_g=1 migrate_i=1
    collect_providers "$DEFAULT_PROVIDERS"
    eg=("${COL_G[@]}"); egs=("${COL_GS[@]}"); ei=("${COL_I[@]}"); eis=("${COL_IS[@]}")
    egm=("${COL_GM[@]}"); eim=("${COL_IM[@]}")
    # each section of providers.conf that has at least one valid entry replaces
    # the built-in list for that section only. Exact copies of v1.4's bundled
    # mirror defaults are migrated to the new six-entry lists; custom lists stay untouched.
    legacygm=(
        'Ubuntu archive|archive.ubuntu.com|icmp,https|apt: Ubuntu packages'
        'Debian|deb.debian.org|icmp,https|apt: Debian packages'
        'Fedora|dl.fedoraproject.org|icmp,https|dnf: Fedora packages'
        'Flathub|dl.flathub.org|icmp,https|Flatpak apps store'
        'Snap Store|api.snapcraft.io|icmp,https|Snap packages store'
    )
    legacyim=(
        'ArvanCloud mirror|mirror.arvancloud.ir|icmp,https|Iranian mirror (hosting not verified)'
        'Pardisco mirror|mirrors.pardisco.co|icmp,https|Iranian mirror (hosting not verified)'
        'IranServer mirror|mirror.iranserver.com|icmp,https|Iranian mirror (hosting not verified)'
        'AminIDC mirror|mirror.aminidc.com|icmp,https|Iranian mirror (hosting not verified)'
        'Mobinhost mirror|mirror.mobinhost.com|icmp,https|Iranian mirror (hosting not verified)'
    )
    # Pristine v1.9.3/v1.9.4 six-entry defaults: refresh them after the ArvanCloud mirror was replaced.
    legacyim_current=(
        'Isfahan U|repo.iut.ac.ir|https|Isfahan University of Technology; supports Arch, Debian, Ubuntu, Fedora and more'
        'Shatel|mirror.shatel.ir|https|Iranian Ubuntu and Debian mirror'
        'ArvanCloud|mirror.arvancloud.ir|https|Iranian Linux package mirrors'
        'IranServer|mirror.iranserver.com|https|Iranian Debian and Ubuntu mirrors'
        'PardisCo|mirrors.pardisco.co|https|Iranian Linux and programming package mirrors'
        'ITO|repo-portal.ito.gov.ir|https|Information Technology Organization repository portal'
    )
    if [[ -f $PROVIDERS_FILE ]]; then
        collect_providers "$(cat -- "$PROVIDERS_FILE" 2>/dev/null)"
        usergm=("${COL_GM[@]}"); userim=("${COL_IM[@]}")
        if (( ${#usergm[@]} != ${#legacygm[@]} )); then migrate_g=0; else
            for item in "${legacygm[@]}"; do found=0; for l in "${usergm[@]}"; do [[ $l == "$item" ]] && found=1; done; (( found )) || migrate_g=0; done
        fi
        migrate_i=0
        if (( ${#userim[@]} == ${#legacyim[@]} )); then
            found=1
            for item in "${legacyim[@]}"; do
                local_match=0
                for l in "${userim[@]}"; do [[ $l == "$item" ]] && local_match=1; done
                (( local_match )) || found=0
            done
            (( found )) && migrate_i=1
        fi
        if (( ! migrate_i && ${#userim[@]} == ${#legacyim_current[@]} )); then
            found=1
            for item in "${legacyim_current[@]}"; do
                local_match=0
                for l in "${userim[@]}"; do [[ $l == "$item" ]] && local_match=1; done
                (( local_match )) || found=0
            done
            (( found )) && migrate_i=1
        fi
        (( ${#COL_G[@]} ))  && eg=("${COL_G[@]}")
        (( ${#COL_GS[@]} )) && egs=("${COL_GS[@]}")
        (( ${#COL_I[@]} ))  && ei=("${COL_I[@]}")
        (( ${#COL_IS[@]} )) && eis=("${COL_IS[@]}")
        if (( ${#usergm[@]} )); then (( migrate_g )) || egm=("${usergm[@]}"); fi
        if (( ${#userim[@]} )); then (( migrate_i )) || eim=("${userim[@]}"); fi
    fi
    NPROV=0; LIST0=""; LIST1=""; LIST2=""; LIST3=""; SITE_START=(-1 -1 -1 -1); LCNT=(0 0 0 0)
    for l in "${eg[@]}";  do add_provider 0 0 "$l"; done
    for l in "${egs[@]}"; do add_provider 0 1 "$l"; done
    for l in "${ei[@]}";  do add_provider 1 0 "$l"; done
    for l in "${eis[@]}"; do add_provider 1 1 "$l"; done
    for l in "${egm[@]}"; do add_provider 2 0 "$l"; done
    for l in "${eim[@]}"; do add_provider 3 0 "$l"; done
    NSEP=(0 0)
    (( SITE_START[0] >= 0 )) && NSEP[0]=1
    (( SITE_START[1] >= 0 )) && NSEP[1]=1
    return 0
}

provider_scan_enabled() { # provider index -> success if this provider's section is active
    local i=$1 cat=${P_CAT[$1]} grp=${P_GRP[$1]}
    case "$cat:$grp" in
        0:0) (( SCAN_GLOBAL_PROVIDERS )) ;;
        0:1) (( SCAN_GLOBAL_SITES )) ;;
        1:0) (( SCAN_INSIDE_PROVIDERS )) ;;
        1:1) (( SCAN_INSIDE_SITES )) ;;
        2:*) (( SCAN_GLOBAL_MIRRORS )) ;;
        3:*) (( SCAN_INSIDE_MIRRORS )) ;;
        *) return 1 ;;
    esac
}

scan_section_label() { # panel category and group -> ACTIVE or INACTIVE
    case "$1:$2" in
        0:0) (( SCAN_GLOBAL_PROVIDERS )) && printf ACTIVE || printf INACTIVE ;;
        0:1) (( SCAN_GLOBAL_SITES )) && printf ACTIVE || printf INACTIVE ;;
        1:0) (( SCAN_INSIDE_PROVIDERS )) && printf ACTIVE || printf INACTIVE ;;
        1:1) (( SCAN_INSIDE_SITES )) && printf ACTIVE || printf INACTIVE ;;
        2:*) (( SCAN_GLOBAL_MIRRORS )) && printf ACTIVE || printf INACTIVE ;;
        3:*) (( SCAN_INSIDE_MIRRORS )) && printf ACTIVE || printf INACTIVE ;;
        *) printf INACTIVE ;;
    esac
}

write_config_template() {
    if [[ -f $PROVIDERS_FILE ]]; then
        printf 'Already exists: %s\n' "$PROVIDERS_FILE"
        return 0
    fi
    mkdir -p -- "$CONF_DIR" || return 1
    {
        printf '# Sakura NetScope providers\n'
        printf '# Format: Name|host|checks|note     checks: icmp,https,dns\n'
        printf '# Sections: [global] [global-sites] [inside] [inside-sites] [mirrors-global] [mirrors-inside]\n'
        printf '# (*-sites are drawn under a SITES line; mirrors fill the Linux Mirrors boxes)\n'
        printf '# A section that lists at least one valid entry replaces the built-in list of that section.\n'
        printf '# Only use endpoints whose owner and location you have verified.\n\n'
        printf '%s\n' "$DEFAULT_PROVIDERS"
    } > "$PROVIDERS_FILE"
    printf 'Wrote %s\n' "$PROVIDERS_FILE"
    write_speedtest_template
}

# ── Proxy resolution ─────────────────────────────────────────────────────────
EFF_PROXY=""; PROXY_EP=""; PROXY_H=""; PROXY_PORT=""
resolve_proxy() {
    local v url rest scheme
    EFF_PROXY="$PROXY_URL"
    if [[ -z $EFF_PROXY ]]; then
        for v in ALL_PROXY all_proxy HTTPS_PROXY https_proxy HTTP_PROXY http_proxy; do
            if [[ -n ${!v:-} ]]; then EFF_PROXY="${!v}"; break; fi
        done
    fi
    PROXY_EP=""; PROXY_H=""; PROXY_PORT=""
    [[ -n $EFF_PROXY ]] || return 0
    url="$EFF_PROXY"; scheme="http"
    if [[ $url == *"://"* ]]; then scheme="${url%%://*}"; url="${url#*://}"; fi
    url="${url%%/*}"; url="${url##*@}"
    if [[ $url == *:* ]]; then PROXY_H="${url%:*}"; PROXY_PORT="${url##*:}"
    else
        PROXY_H="$url"
        case ${scheme,,} in socks*) PROXY_PORT=1080 ;; https) PROXY_PORT=443 ;; *) PROXY_PORT=80 ;; esac
    fi
    if [[ $PROXY_H =~ ^[A-Za-z0-9._-]+$ && $PROXY_PORT =~ ^[0-9]+$ ]]; then
        PROXY_EP="$PROXY_H:$PROXY_PORT"
    else
        PROXY_H=""; PROXY_PORT=""; PROXY_EP="invalid"
    fi
}

# ── Probes (run inside background subshells) ─────────────────────────────────
probe_icmp() { # host -> prints rtt in ms
    local out i f re='time[=<]([0-9]+)(\.([0-9]+))?'
    out="$(LC_ALL=C run_to $((PROBE_TIMEOUT + 1)) "$PING_BIN" -c 1 -W "$PROBE_TIMEOUT" "$1" 2>/dev/null)" || return 1
    [[ $out =~ $re ]] || return 1
    i=${BASH_REMATCH[1]}; f=${BASH_REMATCH[3]:-0}
    i=$((10#$i))
    (( 10#${f:0:1} >= 5 )) && i=$((i + 1))
    (( i < 1 )) && i=1
    printf '%d' "$i"
}

probe_https() { # hostname or URL [proxy] -> prints "code ms"
    local host=$1 via=${2:-} out code t ms int dec t0 t1 url
    if [[ $host == http://* || $host == https://* ]]; then url=$host; else url="https://$host/"; fi
    if [[ -n $CURL_BIN ]]; then
        if [[ $via == proxy && -n $EFF_PROXY ]]; then
            out="$(LC_ALL=C https_proxy="$EFF_PROXY" HTTPS_PROXY="$EFF_PROXY" all_proxy="$EFF_PROXY" ALL_PROXY="$EFF_PROXY" \
                "$CURL_BIN" -sS -o /dev/null -I -L -w '%{http_code} %{time_total}' \
                --connect-timeout "$PROBE_TIMEOUT" --max-time "$((PROBE_TIMEOUT + 2))" "$url" 2>/dev/null)"
        else
            out="$(LC_ALL=C "$CURL_BIN" -sS -o /dev/null -I -L -w '%{http_code} %{time_total}' --noproxy '*' \
                --connect-timeout "$PROBE_TIMEOUT" --max-time "$((PROBE_TIMEOUT + 2))" "$url" 2>/dev/null)"
        fi
        code=${out%% *}
        [[ $code =~ ^[1-9][0-9][0-9]$ ]] || return 1
        t=${out#* }; int=${t%.*}; dec="${t#*.}000"
        [[ $int =~ ^[0-9]+$ && ${dec:0:3} =~ ^[0-9]+$ ]] || { printf '%s -' "$code"; return 0; }
        ms=$(( 10#$int * 1000 + 10#${dec:0:3} ))
        printf '%s %s' "$code" "$ms"
        return 0
    fi
    now_ms; t0=$NOW_MS
    if [[ $via == proxy && -n $EFF_PROXY ]]; then
        https_proxy="$EFF_PROXY" LC_ALL=C run_to $((PROBE_TIMEOUT + 2)) "$WGET_BIN" -q --spider -T "$PROBE_TIMEOUT" -t 1 "$url" >/dev/null 2>&1 || return 1
    else
        LC_ALL=C run_to $((PROBE_TIMEOUT + 2)) "$WGET_BIN" -q --spider -T "$PROBE_TIMEOUT" -t 1 --no-proxy "$url" >/dev/null 2>&1 || return 1
    fi
    now_ms; t1=$NOW_MS
    printf '200 %s' $(( t1 - t0 ))
}

probe_dns() { # server -> 0 if it answers an A query
    local server=$1 out q=$DNS_TEST_HOST re=$'(^|\n)[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+'
    case $DNS_TOOL in
        dig)
            out="$(LC_ALL=C run_to $((PROBE_TIMEOUT + 2)) dig +time="$PROBE_TIMEOUT" +tries=1 +short "@$server" "$q" A 2>/dev/null)" || true
            [[ $out =~ $re ]] ;;
        nslookup)
            out="$(LC_ALL=C run_to $((PROBE_TIMEOUT + 2)) nslookup -timeout="$PROBE_TIMEOUT" -retry=1 "$q" "$server" 2>/dev/null)" || true
            [[ $out == *Name:* ]] ;;
        host)
            out="$(LC_ALL=C run_to $((PROBE_TIMEOUT + 2)) host -W "$PROBE_TIMEOUT" -t A "$q" "$server" 2>/dev/null)" || true
            [[ $out == *"has address"* ]] ;;
        *) return 1 ;;
    esac
}

probe_provider() { # index -> $CDIR/p<i>
    local i=$1 host t out via=""
    local icmp=na rtt=- https=na hcode=- hms=- dns=na
    local -a toks
    host=${P_HOST[$i]}
    [[ ( ${P_CAT[$i]} == 0 || ${P_CAT[$i]} == 2 ) && $GLOBAL_VIA_PROXY == 1 ]] && via=proxy
    IFS=',' read -ra toks <<< "${P_CHK[$i]}"
    for t in "${toks[@]}"; do
        case $t in
            icmp)
                if (( ICMP_OK )); then
                    if rtt="$(probe_icmp "$host")"; then icmp=ok; else icmp=fail; rtt=-; fi
                fi ;;
            https)
                if [[ -n $CURL_BIN || -n $WGET_BIN ]]; then
                    if out="$(probe_https "$host" "$via")"; then
                        https=ok; hcode=${out% *}; hms=${out#* }
                    elif [[ ${P_CAT[$i]} == 2 || ${P_CAT[$i]} == 3 ]] && [[ $host != http://* && $host != https://* ]]; then
                        if out="$(probe_https "http://$host/" "")"; then https=ok; hcode=${out% *}; hms=${out#* }; else https=fail; fi
                    else https=fail; fi
                fi ;;
            dns)
                if [[ -n $DNS_TOOL ]]; then
                    if probe_dns "$host"; then dns=ok; else dns=fail; fi
                fi ;;
        esac
    done
    printf 'icmp=%s rtt=%s https=%s hcode=%s hms=%s dns=%s\n' "$icmp" "$rtt" "$https" "$hcode" "$hms" "$dns" \
        > "$CDIR/p$i.tmp" && mv -f "$CDIR/p$i.tmp" "$CDIR/p$i"
}

# ── System inspection (runs in a background subshell each cycle) ─────────────
hex2ip() { local h=$1; printf '%d.%d.%d.%d' $((16#${h:6:2})) $((16#${h:4:2})) $((16#${h:2:2})) $((16#${h:0:2})); }

is_tunnel_if() {
    local n=$1
    [[ -e /sys/class/net/$n/tun_flags ]] && return 0
    case $n in
        tun*|tap*|wg*|tailscale*|ppp*|nordlynx|proton*|ipsec*|zt*|vti*|mullvad*|warp*|CloudflareWARP|sing*|Meta|mihomo*|xray*|utun*) return 0 ;;
    esac
    return 1
}

if_is_up() {
    local fl
    read -r fl < "/sys/class/net/$1/flags" 2>/dev/null || return 1
    [[ $fl =~ ^0x[0-9a-fA-F]+$ ]] || return 1
    (( fl & 1 ))
}

gather_env() {
    local deep=${1:-1}
    local egress="" gw="" src="" route=no phys="" type="UNKNOWN" ssid="N/A" ip4=""
    local tun="" tunstate="none" vpnname="" line k i d physgw="" dv vv
    local gwstate="${E_GWSTATE:-na}" gwrtt="${E_GWRTT:--}"
    local dnsstate="${E_DNS:-na}" dnsms="${E_DNSMS:--}" pstate="${E_PROXY:-none}"
    local rx_bytes=-1 tx_bytes=-1 sample_ms
    local -a toks defdevs=()

    if [[ -n $IP_BIN ]]; then
        line="$(LC_ALL=C "$IP_BIN" -4 route get 1.1.1.1 2>/dev/null | head -n1)"
        if [[ -n $line ]]; then
            route=yes
            read -ra toks <<< "$line"
            for (( i = 0; i < ${#toks[@]}; i++ )); do
                case ${toks[i]} in
                    via) gw=${toks[i+1]:-} ;;
                    dev) egress=${toks[i+1]:-} ;;
                    src) src=${toks[i+1]:-} ;;
                esac
            done
        fi
        while read -r line; do
            read -ra toks <<< "$line"
            dv=""; vv=""
            for (( i = 0; i < ${#toks[@]}; i++ )); do
                [[ ${toks[i]} == dev ]] && dv=${toks[i+1]:-}
                [[ ${toks[i]} == via ]] && vv=${toks[i+1]:-}
            done
            [[ -n $dv ]] && defdevs+=("$dv")
            if [[ -n $dv && -z $physgw && -n $vv ]] && ! is_tunnel_if "$dv"; then physgw=$vv; fi
        done < <(LC_ALL=C "$IP_BIN" -4 route show default 2>/dev/null)
    elif [[ -r /proc/net/route ]]; then
        local ifn dest gwhex rest
        while read -r ifn dest gwhex rest; do
            [[ $dest == 00000000 ]] || continue
            defdevs+=("$ifn")
            if [[ $route == no ]]; then
                route=yes; egress=$ifn
                [[ $gwhex != 00000000 ]] && gw="$(hex2ip "$gwhex")"
            fi
        done < <(tail -n +2 /proc/net/route)
    fi

    # physical interface = first default-route device that is not a tunnel
    for d in ${defdevs[@]+"${defdevs[@]}"}; do
        if ! is_tunnel_if "$d"; then phys=$d; break; fi
    done
    [[ -z $phys && -n $egress ]] && phys=$egress
    # when a tunnel carries the default route, show the physical gateway instead
    if [[ -n $egress ]] && is_tunnel_if "$egress" && [[ -n $physgw ]]; then gw=$physgw; fi

    if [[ -n $phys ]]; then
        if [[ -d /sys/class/net/$phys/wireless || -d /sys/class/net/$phys/phy80211 ]]; then type="Wi-Fi"
        elif is_tunnel_if "$phys"; then type="Tunnel"
        elif [[ -d /sys/class/net/$phys/bridge ]]; then type="Bridge"
        else
            case $phys in
                ww*|rmnet*|usb*) type="Mobile" ;;
                en*|eth*|em*) type="Ethernet" ;;
                wl*) type="Wi-Fi" ;;
                *) type="Other" ;;
            esac
        fi
        if [[ $type == Wi-Fi ]]; then
            if [[ -n $IWGETID_BIN ]]; then ssid="$(run_to 2 "$IWGETID_BIN" -r "$phys" 2>/dev/null)"
            elif [[ -n $IW_BIN ]]; then
                ssid="$(run_to 2 "$IW_BIN" dev "$phys" link 2>/dev/null | sed -n 's/^[[:space:]]*SSID: //p' | head -n1)"
            elif [[ -n $NMCLI_BIN ]]; then
                ssid="$(run_to 3 "$NMCLI_BIN" -t -f active,ssid dev wifi 2>/dev/null | sed -n 's/^yes://p' | head -n1)"
            fi
            [[ -n $ssid ]] || ssid="N/A"
        fi
        if [[ -n $IP_BIN ]]; then
            line="$(LC_ALL=C "$IP_BIN" -4 -o addr show dev "$phys" scope global 2>/dev/null | head -n1)"
            [[ $line =~ inet\ ([0-9.]+) ]] && ip4=${BASH_REMATCH[1]}
        fi
        [[ -z $ip4 && $phys == "$egress" ]] && ip4=$src
        if [[ -z $ip4 ]] && have hostname; then ip4="$(hostname -I 2>/dev/null | awk '{print $1}')"; fi
    fi

    # tunnels: prefer the one carrying the default route
    if [[ -n $egress ]] && is_tunnel_if "$egress"; then
        tun=$egress; tunstate=routing
    else
        for d in /sys/class/net/*; do
            k=${d##*/}
            [[ $k == lo || $k == '*' ]] && continue
            if is_tunnel_if "$k" && if_is_up "$k"; then tun=$k; tunstate=idle; break; fi
        done
    fi

    # Gateway, DNS and proxy checks are slower; refresh them on a slower cadence.
    if (( deep )); then
        if [[ -z $gw ]]; then
            [[ $route == yes ]] && gwstate="onlink" || gwstate="na"
            gwrtt="-"
        elif (( ICMP_OK )) && [[ $gw =~ ^[0-9.]+$ ]]; then
            if gwrtt="$(probe_icmp "$gw")"; then gwstate="reply"; else gwstate="noreply"; gwrtt="-"; fi
        else gwstate="na"; gwrtt="-"; fi

        # system DNS (what applications actually use)
        dnsstate=na; dnsms=-
        local t0 t1 out
        if [[ -n $SYS_DNS_TOOL ]]; then
        now_ms; t0=$NOW_MS
        case $SYS_DNS_TOOL in
            getent)   out="$(run_to 5 getent ahostsv4 "$DNS_TEST_HOST" 2>/dev/null)"; [[ -n $out ]] && dnsstate=ok || dnsstate=fail ;;
            host)     out="$(run_to 5 host -W 3 "$DNS_TEST_HOST" 2>/dev/null)"; [[ $out == *"has address"* ]] && dnsstate=ok || dnsstate=fail ;;
            nslookup) out="$(run_to 5 nslookup "$DNS_TEST_HOST" 2>/dev/null)"; [[ $out == *Name:* ]] && dnsstate=ok || dnsstate=fail ;;
            dig)      out="$(run_to 5 dig +time=3 +tries=1 +short "$DNS_TEST_HOST" A 2>/dev/null)"; [[ -n $out && $out != *";;"* ]] && dnsstate=ok || dnsstate=fail ;;
        esac
            now_ms; t1=$NOW_MS; dnsms=$(( t1 - t0 ))
        fi

        # proxy reachability (TCP connect only)
        pstate=none
        if [[ -n $PROXY_EP ]]; then
            if [[ -n $PROXY_H ]] && run_to 3 bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$PROXY_H" "$PROXY_PORT" 2>/dev/null; then pstate=ok
            else pstate=fail; fi
        fi
    elif [[ $gw != ${E_GW:-} ]]; then
        gwstate=na; gwrtt="-"
    fi

    if [[ -n $tun && -n $NMCLI_BIN && $deep == 1 ]]; then
        vpnname="$(LC_ALL=C run_to 3 "$NMCLI_BIN" -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null | awk -F: -v dev="$tun" '$3==dev {print $1; exit}')"
    fi
    [[ -n $vpnname ]] || vpnname="$tun"

    # Lightweight live throughput sampling from the routed interface counters.
    if [[ -n $egress && -r /sys/class/net/$egress/statistics/rx_bytes && -r /sys/class/net/$egress/statistics/tx_bytes ]]; then
        read -r rx_bytes < "/sys/class/net/$egress/statistics/rx_bytes" 2>/dev/null || rx_bytes=-1
        read -r tx_bytes < "/sys/class/net/$egress/statistics/tx_bytes" 2>/dev/null || tx_bytes=-1
    fi
    now_ms; sample_ms=$NOW_MS

    printf 'route=%s\negress=%s\nphys=%s\ntype=%s\nssid=%s\nip=%s\ngw=%s\ngwstate=%s\ngwrtt=%s\n' \
        "$route" "$egress" "$phys" "$type" "${ssid//[[:cntrl:]]/}" "$ip4" "$gw" "$gwstate" "$gwrtt"
    printf 'tun=%s\ntunstate=%s\nvpnname=%s\ndns=%s\ndnsms=%s\nproxy=%s\n' "$tun" "$tunstate" "$vpnname" "$dnsstate" "$dnsms" "$pstate"
    printf 'rx_bytes=%s\ntx_bytes=%s\nsample_ms=%s\n' "$rx_bytes" "$tx_bytes" "$sample_ms"
}

E_ROUTE=""; E_EGRESS=""; E_PHYS=""; E_TYPE=""; E_SSID=""; E_IP=""; E_GW=""; E_GWSTATE=""; E_GWRTT=""
E_TUN=""; E_TUNSTATE=""; E_DNS=""; E_DNSMS=""; E_PROXY=""; E_VPN_NAME=""
E_EGRESS=""; E_RX_BYTES=-1; E_TX_BYTES=-1; E_SAMPLE_MS=0
E_DOWNLOAD_BPS=0; E_UPLOAD_BPS=0; E_RATE_VALID=0
LAST_DEEP_CHECK=0
SYS_PROXY_STATE="unknown"; SYS_PROXY_SOURCE="not detected"; SYS_PROXY_URL="N/A"
ENV_VALID=0

redact_proxy_url() { # URL -> URL without embedded credentials
    local u=$1 scheme rest
    [[ -n $u ]] || { printf 'N/A'; return; }
    if [[ $u == *://* ]]; then scheme=${u%%://*}://; rest=${u#*://}; else scheme=""; rest=$u; fi
    rest=${rest##*@}
    printf '%s%s' "$scheme" "$rest"
}

detect_system_proxy() {
    local mode host port url cfg ptype line val desktop="${XDG_CURRENT_DESKTOP:-} ${DESKTOP_SESSION:-}"
    desktop=${desktop,,}
    SYS_PROXY_STATE="unknown"; SYS_PROXY_SOURCE="not detected"; SYS_PROXY_URL="N/A"

    # GNOME / GTK desktops: query the desktop's actual proxy mode, not just shell variables.
    # Do not let a default GNOME schema mask Plasma's own kioslaverc settings.
    if have gsettings && [[ $desktop == *gnome* || $desktop == *cinnamon* || $desktop == *unity* || $desktop == *mate* ]]; then
        mode="$(gsettings get org.gnome.system.proxy mode 2>/dev/null || true)"
        mode=${mode//\'/}; mode=${mode//\"/}
        case $mode in
            none)
                SYS_PROXY_STATE="inactive"; SYS_PROXY_SOURCE="GNOME"; SYS_PROXY_URL="N/A"; return 0 ;;
            manual)
                for cfg in http https socks; do
                    host="$(gsettings get "org.gnome.system.proxy.$cfg" host 2>/dev/null || true)"
                    port="$(gsettings get "org.gnome.system.proxy.$cfg" port 2>/dev/null || true)"
                    host=${host//\'/}; host=${host//\"/}; port=${port//[^0-9]/}
                    if [[ -n $host ]]; then
                        [[ -n $port ]] || { [[ $cfg == socks ]] && port=1080 || port=8080; }
                        url="$cfg://$host:$port"
                        SYS_PROXY_STATE="active"; SYS_PROXY_SOURCE="GNOME manual"; SYS_PROXY_URL="$url"; return 0
                    fi
                done
                SYS_PROXY_STATE="active"; SYS_PROXY_SOURCE="GNOME manual"; SYS_PROXY_URL="configured (endpoint unavailable)"; return 0 ;;
            auto)
                url="$(gsettings get org.gnome.system.proxy autoconfig-url 2>/dev/null || true)"
                url=${url#\'}; url=${url%\'}; url=${url#\"}; url=${url%\"}
                SYS_PROXY_STATE="active"; SYS_PROXY_SOURCE="GNOME auto/PAC"; SYS_PROXY_URL="$(redact_proxy_url "${url:-automatic configuration}")"; return 0 ;;
        esac
    fi

    # KDE Plasma / KIO proxy settings.
    cfg="${XDG_CONFIG_HOME:-$HOME/.config}/kioslaverc"
    if [[ ( $desktop == *kde* || $desktop == *plasma* || ( -z ${XDG_CURRENT_DESKTOP:-} && -z ${DESKTOP_SESSION:-} ) ) && -r $cfg ]]; then
        ptype="$(awk -F= '/^\[Proxy Settings\]/{s=1;next} /^\[/{s=0} s && /^ProxyType=/{print $2;exit}' "$cfg" 2>/dev/null)"
        case $ptype in
            0) SYS_PROXY_STATE="inactive"; SYS_PROXY_SOURCE="KDE"; SYS_PROXY_URL="N/A"; return 0 ;;
            1)
                for cfg in httpProxy httpsProxy socksProxy; do
                    url="$(awk -F= -v k="$cfg" '/^\[Proxy Settings\]/{s=1;next} /^\[/{s=0} s && $1==k {sub(/^[^=]*=/,"");print;exit}' "${XDG_CONFIG_HOME:-$HOME/.config}/kioslaverc" 2>/dev/null)"
                    if [[ -n $url ]]; then SYS_PROXY_STATE="active"; SYS_PROXY_SOURCE="KDE manual"; SYS_PROXY_URL="$(redact_proxy_url "$url")"; return 0; fi
                done
                SYS_PROXY_STATE="active"; SYS_PROXY_SOURCE="KDE manual"; SYS_PROXY_URL="configured (endpoint unavailable)"; return 0 ;;
            2|3) SYS_PROXY_STATE="active"; SYS_PROXY_SOURCE="KDE automatic"; SYS_PROXY_URL="PAC/WPAD"; return 0 ;;
        esac
    fi

    # Environment proxies are real for programs inheriting this environment, but aren't proof that every desktop app uses them.
    for cfg in ALL_PROXY all_proxy HTTPS_PROXY https_proxy HTTP_PROXY http_proxy; do
        val=${!cfg:-}
        if [[ -n $val ]]; then
            SYS_PROXY_STATE="active"; SYS_PROXY_SOURCE="environment ($cfg)"; SYS_PROXY_URL="$(redact_proxy_url "$val")"; return 0
        fi
    done
    SYS_PROXY_STATE="unknown"; SYS_PROXY_SOURCE="desktop setting unavailable"; SYS_PROXY_URL="N/A"
}

ingest_env() {
    local f="$CDIR/env" k v rx=-1 tx=-1 sample=0 old_rx=$E_RX_BYTES old_tx=$E_TX_BYTES old_ms=$E_SAMPLE_MS
    local old_egress=$E_EGRESS
    [[ -f $f ]] || return 0
    while IFS='=' read -r k v || [[ -n $k ]]; do
        case $k in
            route) E_ROUTE=$v ;; egress) E_EGRESS=$v ;; phys) E_PHYS=$v ;; type) E_TYPE=$v ;;
            ssid) E_SSID=$v ;; ip) E_IP=$v ;; gw) E_GW=$v ;; gwstate) E_GWSTATE=$v ;; gwrtt) E_GWRTT=$v ;;
            tun) E_TUN=$v ;; tunstate) E_TUNSTATE=$v ;; vpnname) E_VPN_NAME=$v ;;
            dns) E_DNS=$v ;; dnsms) E_DNSMS=$v ;; proxy) E_PROXY=$v ;;
            rx_bytes) rx=$v ;; tx_bytes) tx=$v ;; sample_ms) sample=$v ;;
        esac
    done < "$f"
    E_RATE_VALID=0; E_DOWNLOAD_BPS=0; E_UPLOAD_BPS=0
    if [[ $rx =~ ^[0-9]+$ && $tx =~ ^[0-9]+$ && $sample =~ ^[0-9]+$ ]]; then
        if [[ $old_egress == "$E_EGRESS" && $old_rx =~ ^[0-9]+$ && $old_tx =~ ^[0-9]+$ && $old_ms =~ ^[0-9]+$ ]] && (( sample > old_ms )); then
            local elapsed=$((sample - old_ms)) drx=$((rx - old_rx)) dtx=$((tx - old_tx))
            if (( drx >= 0 && dtx >= 0 )); then
                E_DOWNLOAD_BPS=$(( drx * 1000 / elapsed ))
                E_UPLOAD_BPS=$(( dtx * 1000 / elapsed ))
                E_RATE_VALID=1
            fi
        fi
        E_RX_BYTES=$rx; E_TX_BYTES=$tx; E_SAMPLE_MS=$sample
    else
        E_RX_BYTES=-1; E_TX_BYTES=-1; E_SAMPLE_MS=0
    fi
    ENV_VALID=1
}

# ── Cycle management ─────────────────────────────────────────────────────────
TMPD=""; CDIR=""; CPIDS=(); CYCLE_RUNNING=0; CYCLE_T0=0; CYCLES=0; NEXT_AT=0
CYCLE_INGESTED=(); PARTIAL_CHANGED=0
PAUSED=0; REFRESH_REQ=0; LAST_UPDATE=""
SYS_PROXY_FILE=""; SYS_PROXY_PID=""; SYS_PROXY_READY=0

terminate_process_tree() { # terminate a tracked job and descendants (including ping/curl/timeout)
    local root=${1:-} pid ppid changed
    local snapshot
    local -a descendants=()
    local -A seen=()
    [[ $root =~ ^[0-9]+$ ]] || return 0
    # One process-table snapshot avoids running pgrep once per child on shutdown/refresh.
    snapshot="$(ps -eo pid=,ppid= 2>/dev/null || true)"
    seen["$root"]=1
    while :; do
        changed=0
        while read -r pid ppid; do
            [[ $pid =~ ^[0-9]+$ && $ppid =~ ^[0-9]+$ ]] || continue
            [[ -n ${seen[$ppid]:-} && -z ${seen[$pid]:-} ]] || continue
            seen["$pid"]=1
            descendants+=("$pid")
            changed=1
        done <<< "$snapshot"
        (( changed )) || break
    done
    kill -TERM "$root" 2>/dev/null || true
    for pid in "${descendants[@]}"; do kill -TERM "$pid" 2>/dev/null || true; done
}


kill_children() {
    local p job
    local -a running=() tracked=()
    # Never signal stale PIDs: only process IDs still reported as live shell jobs.
    while IFS= read -r p; do [[ -n $p ]] && running+=("$p"); done < <(jobs -pr)
    for p in "${CPIDS[@]+${CPIDS[@]}}"; do
        for job in "${running[@]}"; do
            if [[ $p == "$job" ]]; then tracked+=("$p"); break; fi
        done
    done
    for p in "${tracked[@]}"; do terminate_process_tree "$p"; done
    for p in "${CPIDS[@]+${CPIDS[@]}}"; do wait "$p" 2>/dev/null || true; done
    CPIDS=()
}

reap_children() { # wait only for scheduler/environment jobs reported complete by the cycle
    local p
    for p in "${CPIDS[@]+${CPIDS[@]}}"; do wait "$p" 2>/dev/null || true; done
    CPIDS=()
}

run_probe_pool() { # scheduler lives in the background; never blocks the keyboard/event loop
    local i active=0 p
    local -a children=()
    for (( i = 0; i < NPROV; i++ )); do
        provider_scan_enabled "$i" || continue
        ( probe_provider "$i" ) &
        children+=("$!")
        active=$((active + 1))
        if (( active >= MAX_PARALLEL_PROBES )); then
            if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3) )); then
                wait -n 2>/dev/null || true
            else
                # Compatibility path for older Bash; any wait delay stays outside the TUI.
                p=${children[0]:-}
                [[ -n $p ]] && wait "$p" 2>/dev/null || true
            fi
            active=$((active - 1))
        fi
    done
    for p in "${children[@]}"; do wait "$p" 2>/dev/null || true; done
}

start_system_proxy_detection() { # asynchronous: a desktop D-Bus query may be slow or unavailable
    [[ -n $SYS_PROXY_FILE ]] || return 1
    if [[ -n $SYS_PROXY_PID ]] && kill -0 "$SYS_PROXY_PID" 2>/dev/null; then return 0; fi
    SYS_PROXY_READY=0
    rm -f -- "$SYS_PROXY_FILE" "$SYS_PROXY_FILE.tmp"
    (
        detect_system_proxy
        printf 'state=%s\nsource=%s\nurl=%s\n' "$SYS_PROXY_STATE" "$SYS_PROXY_SOURCE" "$SYS_PROXY_URL" > "$SYS_PROXY_FILE.tmp" &&
            mv -f -- "$SYS_PROXY_FILE.tmp" "$SYS_PROXY_FILE"
    ) >/dev/null 2>&1 &
    SYS_PROXY_PID=$!
}

load_system_proxy_result() {
    local k v
    (( SYS_PROXY_READY )) && return 1
    [[ -r $SYS_PROXY_FILE ]] || return 1
    while IFS='=' read -r k v || [[ -n $k ]]; do
        case $k in state) SYS_PROXY_STATE=$v ;; source) SYS_PROXY_SOURCE=$v ;; url) SYS_PROXY_URL=$v ;; esac
    done < "$SYS_PROXY_FILE"
    SYS_PROXY_READY=1
    if [[ -n $SYS_PROXY_PID ]]; then wait "$SYS_PROXY_PID" 2>/dev/null || true; SYS_PROXY_PID=""; fi
    return 0
}

start_cycle() {
    local deep=0
    rm -rf -- "$CDIR"; mkdir -p -- "$CDIR" || return 1
    CPIDS=(); CYCLE_INGESTED=(); PARTIAL_CHANGED=0
    (( CYCLES == 0 || SECONDS - LAST_DEEP_CHECK >= ENV_DEEP_INTERVAL )) && deep=1
    (( deep )) && LAST_DEEP_CHECK=$SECONDS
    # The worker scheduler enforces the cap in a separate process. Start-up and
    # keyboard handling return immediately even when network endpoints time out.
    ( run_probe_pool ) &
    CPIDS+=("$!")
    ( gather_env "$deep" > "$CDIR/env.tmp" 2>/dev/null; mv -f "$CDIR/env.tmp" "$CDIR/env" ) &
    CPIDS+=("$!")
    CYCLE_RUNNING=1; CYCLE_T0=$SECONDS; CYCLE_TIMED_OUT=0
}

CYCLE_TIMED_OUT=0
cycle_finished() {
    local i
    (( CYCLE_RUNNING )) || return 1
    if (( SECONDS - CYCLE_T0 >= CYCLE_MAX )); then CYCLE_TIMED_OUT=1; return 0; fi
    [[ -f $CDIR/env ]] || return 1
    for (( i = 0; i < NPROV; i++ )); do
        provider_scan_enabled "$i" || continue
        [[ -f $CDIR/p$i ]] || return 1
    done
    return 0
}

ingest_probe_result() { # index -> 0 if a fresh result was ingested
    local i=$1 line kv icmp rtt https hcode hms dns ok via
    local -a a
    [[ ${CYCLE_INGESTED[$i]:-0} == 1 ]] && return 1
    provider_scan_enabled "$i" || { CYCLE_INGESTED[i]=1; return 1; }
    [[ -f $CDIR/p$i ]] || return 1
    read -r line < "$CDIR/p$i" || return 1
    icmp=na; rtt=-; https=na; hcode=-; hms=-; dns=na
    for kv in $line; do
        case ${kv%%=*} in
            icmp) icmp=${kv#*=} ;; rtt) rtt=${kv#*=} ;; https) https=${kv#*=} ;;
            hcode) hcode=${kv#*=} ;; hms) hms=${kv#*=} ;; dns) dns=${kv#*=} ;;
        esac
    done
    CYCLE_INGESTED[i]=1
    ok=-1
    if [[ $icmp == ok || $https == ok || $dns == ok ]]; then ok=1
    elif [[ $icmp == fail || $https == fail || $dns == fail ]]; then ok=0; fi
    (( ok == -1 )) && return 1

    P_HIST[i]="${P_HIST[i]}$ok"
    (( ${#P_HIST[i]} > WINDOW )) && P_HIST[i]=${P_HIST[i]: -WINDOW}
    if [[ $icmp != na ]]; then
        if [[ $icmp == ok ]]; then P_IHIST[i]="${P_IHIST[i]}1"; else P_IHIST[i]="${P_IHIST[i]}0"; fi
        (( ${#P_IHIST[i]} > WINDOW )) && P_IHIST[i]=${P_IHIST[i]: -WINDOW}
    fi
    if [[ $icmp == ok && $rtt =~ ^[0-9]+$ ]]; then
        read -ra a <<< "${P_RTTS[i]} $rtt"
        (( ${#a[@]} > WINDOW )) && a=("${a[@]: -WINDOW}")
        P_RTTS[i]="${a[*]}"
        P_LASTRTT[i]=$rtt; P_CURRTT[i]=$rtt
    else
        P_CURRTT[i]="-"
    fi
    via=""
    [[ $icmp == ok ]] && via+="i"
    [[ $https == ok ]] && via+="${via:+.}h"
    [[ $dns == ok ]] && via+="${via:+.}d"
    P_VIA[i]=${via:--}
    P_ICMP[i]=$icmp; P_HTTPS[i]=$https; P_HCODE[i]=$hcode; P_HMS[i]=$hms; P_DNS[i]=$dns
    return 0
}

ingest_partial_results() { # consume each provider as soon as its result file appears
    local i changed=0
    (( CYCLE_RUNNING )) || return 1
    for (( i = 0; i < NPROV; i++ )); do
        if ingest_probe_result "$i"; then changed=1; fi
    done
    (( changed )) && PARTIAL_CHANGED=1
    return 0
}

ingest_cycle() {
    local i
    ingest_env
    # Results already shown during the cycle are marked and never counted twice.
    for (( i = 0; i < NPROV; i++ )); do ingest_probe_result "$i" || true; done
    CYCLES=$(( CYCLES + 1 ))
    printf -v LAST_UPDATE '%(%H:%M:%S)T' -1
}

# ── Metrics ──────────────────────────────────────────────────────────────────
prov_metrics() { # index -> M_SAMPLES M_ONES M_PCT M_STATE M_LASTOK
    local i=$1 h=${P_HIST[$1]} ones cur=${P_CURRTT[$1]}
    M_SAMPLES=${#h}
    ones=${h//0/}; M_ONES=${#ones}
    if (( M_SAMPLES == 0 )); then M_STATE=PENDING; M_PCT=-1; M_LASTOK=-1; return; fi
    M_LASTOK=${h: -1}
    # Show the current reachability immediately; do not hide the bar during warm-up.
    M_PCT=$(( M_ONES * 100 / M_SAMPLES ))
    if (( M_SAMPLES < MIN_SAMPLES )); then M_STATE="WARMING UP"; return; fi
    if (( M_PCT == 0 )); then M_STATE=DOWN
    elif [[ $M_LASTOK == 0 ]]; then
        if (( M_PCT >= 50 )); then M_STATE=DEGRADED; else M_STATE=DOWN; fi
    elif (( M_PCT < 80 )) || { [[ $cur != - ]] && (( cur >= DEGRADED_RTT )); }; then M_STATE=DEGRADED
    else M_STATE=UP; fi
    # The rolling percentage remains useful for history, but a current DOWN
    # result must not leave a visibly green/partially-full bar during an outage.
    [[ $M_STATE == DOWN ]] && M_PCT=0
}

QUAL_NAMES=(EXCELLENT GOOD DECENT USABLE POOR AWFUL)
SUM_CACHE_KEY=("" "")
SUM_CACHE_EL=(0 0); SUM_CACHE_RE=(0 0); SUM_CACHE_N=(0 0)
SUM_CACHE_MEAN=(N/A N/A); SUM_CACHE_MED=(N/A N/A); SUM_CACHE_LOSS=(N/A N/A)
SUM_CACHE_STATUS=(UNKNOWN UNKNOWN); SUM_CACHE_QUAL=(N/A N/A); SUM_CACHE_PCT=(-1 -1)

store_summary_cache() { # category key; cache current S_* results for reuse while rendering a frame
    local c=$1 key=$2
    SUM_CACHE_KEY[c]=$key; SUM_CACHE_EL[c]=$S_EL; SUM_CACHE_RE[c]=$S_RE; SUM_CACHE_N[c]=$S_N
    SUM_CACHE_MEAN[c]=$S_MEAN; SUM_CACHE_MED[c]=$S_MED; SUM_CACHE_LOSS[c]=$S_LOSS
    SUM_CACHE_STATUS[c]=$S_STATUS; SUM_CACHE_QUAL[c]=$S_QUAL; SUM_CACHE_PCT[c]=$S_PCT
}

cat_summary() { # category -> S_* globals; cached per cycle/settings to avoid repeated sorting
    local c=$1 key list i h el=0 re=0 n=0 sum=0 it=0 ifail=0 z
    local -a all=() sorted=()
    key="${CYCLES}:${WINDOW}:${MIN_SAMPLES}:${DEGRADED_RTT}:${SCAN_GLOBAL_PROVIDERS}${SCAN_GLOBAL_SITES}${SCAN_INSIDE_PROVIDERS}${SCAN_INSIDE_SITES}${SCAN_GLOBAL_MIRRORS}${SCAN_INSIDE_MIRRORS}"
    if [[ ${SUM_CACHE_KEY[$c]:-} == "$key" ]]; then
        S_EL=${SUM_CACHE_EL[$c]}; S_RE=${SUM_CACHE_RE[$c]}; S_N=${SUM_CACHE_N[$c]}
        S_MEAN=${SUM_CACHE_MEAN[$c]}; S_MED=${SUM_CACHE_MED[$c]}; S_LOSS=${SUM_CACHE_LOSS[$c]}
        S_STATUS=${SUM_CACHE_STATUS[$c]}; S_QUAL=${SUM_CACHE_QUAL[$c]}; S_PCT=${SUM_CACHE_PCT[$c]}
        return 0
    fi
    [[ $c == 0 ]] && list=$LIST0 || list=$LIST1
    for i in $list; do
        provider_scan_enabled "$i" || continue
        prov_metrics "$i"
        if (( M_SAMPLES >= MIN_SAMPLES )); then
            el=$((el + 1))
            (( M_LASTOK == 1 )) && re=$((re + 1))
        fi
        if [[ -n ${P_RTTS[$i]} ]]; then all+=(${P_RTTS[$i]}); fi
        h=${P_IHIST[$i]}
        if [[ -n $h ]]; then z=${h//1/}; it=$((it + ${#h})); ifail=$((ifail + ${#z})); fi
    done
    S_EL=$el; S_RE=$re; S_N=${#all[@]}
    S_MEAN="N/A"; S_MED="N/A"; S_LOSS="N/A"
    if (( S_N > 0 )); then
        for i in "${all[@]}"; do sum=$((sum + i)); done
        S_MEAN=$(( sum / S_N ))
        mapfile -t sorted < <(printf '%s\n' "${all[@]}" | sort -n)
        if (( S_N % 2 )); then S_MED=${sorted[S_N / 2]}
        else S_MED=$(( (sorted[S_N / 2 - 1] + sorted[S_N / 2]) / 2 )); fi
    fi
    (( it > 0 )) && S_LOSS=$(( ifail * 100 / it ))
    if (( el == 0 )); then
        S_STATUS=UNKNOWN; S_QUAL="N/A"; S_PCT=-1
        store_summary_cache "$c" "$key"
        return 0
    fi
    S_PCT=$(( re * 100 / el ))
    if (( re == 0 )); then S_STATUS=DISCONNECTED
    elif (( S_PCT >= 60 )); then S_STATUS=CONNECTED
    else S_STATUS=DEGRADED; fi
    if (( re == 0 )); then S_QUAL="N/A"; store_summary_cache "$c" "$key"; return 0; fi
    local qr qm=0
    if   (( S_PCT >= 95 )); then qr=0
    elif (( S_PCT >= 85 )); then qr=1
    elif (( S_PCT >= 70 )); then qr=2
    elif (( S_PCT >= 50 )); then qr=3
    elif (( S_PCT >= 25 )); then qr=4
    else qr=5; fi
    if (( S_N > 0 )); then
        if   (( S_MEAN <= 40 )); then qm=0
        elif (( S_MEAN <= 80 )); then qm=1
        elif (( S_MEAN <= 150 )); then qm=2
        elif (( S_MEAN <= 300 )); then qm=3
        elif (( S_MEAN <= 600 )); then qm=4
        else qm=5; fi
    fi
    (( qm > qr )) && qr=$qm
    S_QUAL=${QUAL_NAMES[qr]}
    store_summary_cache "$c" "$key"
}

# colour for a label (result in CLR)
clr_for() {
    case $1 in
        CONNECTED|UP|EXCELLENT|GOOD|ok|reply|working) CLR=$GREEN ;;
        DEGRADED|DECENT|USABLE|"LOCAL ONLY"|warn) CLR=$YELLOW ;;
        DISCONNECTED|DOWN|POOR|AWFUL|bad|FAILING) CLR=$RED ;;
        *) CLR=$GRAY ;;
    esac
}

# ── Frame building blocks ────────────────────────────────────────────────────
OUT=()

box_top() { # outer_w title border_colour
    local w=$1 t=$2 bc=$3 title_len
    # Titles may contain ANSI colours (e.g. INACTIVE); count visible cells only.
    vlen "$t"; title_len=$VL
    hline $(( w - title_len - 5 ))
    BOX="${bc}${B_TL}${B_H} ${BOLD}${PINK}${t}${RESET}${bc} ${HL}${B_TR}${RESET}"
}
box_mid() { # outer_w title border_colour [right_text]
    local w=$1 t=$2 bc=$3 r=${4:-} title_len right_len
    # Bash string length includes ANSI escape bytes, which shortens the divider
    # and breaks the heading whenever the title contains coloured text.
    vlen "$t"; title_len=$VL
    if [[ -n $r ]]; then
        vlen "$r"; right_len=$VL
        hline $(( w - title_len - 5 - right_len - 3 ))
        BOX="${bc}${B_ML}${B_H} ${BOLD}${PINK}${t}${RESET}${bc} ${HL} ${GRAY}${r}${RESET}${bc} ${B_H}${B_MR}${RESET}"
    else
        hline $(( w - title_len - 5 ))
        BOX="${bc}${B_ML}${B_H} ${BOLD}${PINK}${t}${RESET}${bc} ${HL}${B_MR}${RESET}"
    fi
}
box_bottom() { hline $(( $1 - 2 )); BOX="${3}${B_BL}${HL}${B_BR}${RESET}"; }
box_row() { # outer_w content border_colour
    padr "$2" $(( $1 - 4 ))
    BOX="${3}${B_V}${RESET} ${PADDED} ${3}${B_V}${RESET}"
}

# key/value row: state label value
kv() {
    local st=$1 label=$2 value=$3 ic col
    case $st in
        ok)   ic="${GREEN}${G_OK}${RESET}";   col=$GREEN ;;
        warn) ic="${YELLOW}${G_WARN}${RESET}"; col=$YELLOW ;;
        bad)  ic="${RED}${G_BAD}${RESET}";     col=$RED ;;
        unk)  ic="${GRAY}${G_UNK}${RESET}";    col=$GRAY ;;
        *)    ic="${GRAY}${G_DOT}${RESET}";    col='' ;;
    esac
    printf -v KV '%s %s%-10s%s %s%s%s' "$ic" "$CYAN" "$label" "$RESET" "$col" "$value" "$RESET"
}

# Sakura logo: the same tree and title as Sakura Downloader (26 columns, 10 rows)
TREE_BIG=(
'        .@@@@@@.'
'     .@@@o@@@@@o@@.   .'
'    @@o@@@@@@@@@@o@@@'
'     ~@@@o@@@@@@@o@@~'
'  ,    ~~@@@@\|/@@@~~  .'
'     .         |         ,'
'   ,          /|\    .'
'           ___|___'
'      S A K U R A'
'        NetScope'
)
TREE_SMALL=(
'  .@@@@@.  '
' @@o@@@o@@ '
'  ~@\|/@~  '
'    \|/    '
'     |     '
'  Sakura   '
)

colorize_art() { # line -> ART
    local line=$1 out="" c i
    if [[ $line == *"S A K U R A"* || $line == *Sakura* ]]; then ART="${BOLD}${PINK}${line}${RESET}"; return; fi
    if [[ $line == *NetScope* ]]; then ART="${ROSE}${line}${RESET}"; return; fi
    for (( i = 0; i < ${#line}; i++ )); do
        c=${line:i:1}
        case $c in
            '@') out+="${PINK}@" ;;
            'o') out+="${ROSE}o" ;;
            '.'|',') out+="${PINK}${c}" ;;
            '~') out+="${ROSE}~" ;;
            '|'|'/'|'\'|'_') out+="${BROWN}${c}" ;;
            *) out+="$c" ;;
        esac
    done
    ART="${out}${RESET}"
}

print_tree() {
    local l
    printf '\n'
    for l in "${TREE_BIG[@]}"; do colorize_art "$l"; printf '  %s\n' "$ART"; done
    printf '\n'
}

internet_state() { # -> INET_LABEL INET_STATE
    cat_summary 0; local ge=$S_EL gr=$S_RE
    cat_summary 1; local ie=$S_EL ir=$S_RE
    if (( ! ENV_VALID && CYCLES == 0 )); then INET_LABEL=UNKNOWN; INET_STATE=unk; return; fi
    if [[ $E_ROUTE == no ]]; then INET_LABEL=DISCONNECTED; INET_STATE=bad; return; fi
    if (( gr > 0 )); then INET_LABEL=CONNECTED; INET_STATE=ok
    elif (( ir > 0 )); then INET_LABEL="LOCAL ONLY"; INET_STATE=warn
    elif (( ge + ie == 0 )); then INET_LABEL=UNKNOWN; INET_STATE=unk
    else INET_LABEL=DISCONNECTED; INET_STATE=bad; fi
}

# privacy helpers: hide proxy / resolvers, shorten home paths
pv() { if (( PRIVACY )); then printf 'hidden (privacy mode)'; else printf '%s' "$1"; fi; }
hp() { local t='~'; if (( PRIVACY )); then printf '%s' "${1/#$HOME/$t}"; else printf '%s' "$1"; fi; }

# Sakura grove for privacy mode (deterministic, so it never changes between frames)
declare -A FOREST_CACHE_DATA=()
FOREST_CACHE_KEYS=()
FOREST_CACHE_LIMIT=8

FT_L=(
'   .@@@@@.   '
' .@@o@@@o@@. '
'@@@o@@@@@o@@@'
' ~@@o@@@o@@~ '
'    ~\|/~    '
'      |      '
'    _/|\_    '
)
FT_M=(
' .@@@@@. '
'@@o@@@o@@'
' ~@\|/@~ '
'    |    '
'   _|_   '
)
FT_S=(
'.@@@.'
'~@|@~'
'  |  '
)

build_forest() { # inner_width -> FOREST; bounded, multi-key cache avoids rebuilding each inactive panel every frame
    local W=$1 H=$FOREST_H TARGET_W=$1 TARGET_H=$FOREST_H x y k i r c ch cl rows_n tw tx y0 th cx spec size pct line cur code cache_key cached
    (( W < 1 )) && W=1
    (( H < 1 )) && H=1
    # Avoid unbounded Bash cell arrays on unusually large terminals.
    # Normal layouts are untouched; huge canvases use a safe maximum working area.
    (( W > 320 )) && W=320
    (( H > 64 )) && H=64
    while (( W * H > 20000 )); do
        if (( W >= H && W > 80 )); then W=$(( (W + 1) / 2 )); else H=$(( (H + 1) / 2 )); fi
    done
    cache_key="${TARGET_W}:${TARGET_H}:${UI_ASCII}:${THEME}"
    if [[ -n ${FOREST_CACHE_DATA[$cache_key]+x} ]]; then
        mapfile -t FOREST <<< "${FOREST_CACHE_DATA[$cache_key]}"
        FOREST_CACHE_KEY=$cache_key
        return 0
    fi
    local -a CH=() CL=() occ=() rows=()
    local -a PET=('.' ',' '*' 'o' '~')
    for (( i = 0; i < W * H; i++ )); do CH[i]=' '; CL[i]=' '; done
    # petals in the air and on the ground
    for (( y = 0; y < H; y++ )); do
        for (( x = 0; x < W; x++ )); do
            i=$(( y * W + x ))
            if (( y == H - 1 )); then
                k=$(( ((x * 1103515245 + 12345) >> 8) % 13 ))
                if (( k < 9 )); then CH[i]=${PET[(((x * 1664525 + 1013904223) >> 11) % 5)]}; (( (x + k) % 2 )) && CL[i]=p || CL[i]=r; fi
            elif (( y == H - 2 )); then
                if (( (((x + 7) * 1103515245 + 12345) >> 9) % 11 < 2 )); then CH[i]=${PET[(((x + 3) * 1664525 + 1013904223) >> 12) % 5]}; (( x % 2 )) && CL[i]=p || CL[i]=r; fi
            elif (( (((x * 31 + y * 17 + 5) * 1103515245 + 12345) >> 10) % 29 == 0 )); then
                CH[i]='.'; (( y % 2 )) && CL[i]=p || CL[i]=r
            fi
        done
    done
    for (( x = 0; x < W; x++ )); do occ[x]=0; done
    # trees of different sizes (largest first, skipped when they would overlap)
    for spec in L:8 L:93 M:25 M:75 S:17 S:34 S:44 S:57 S:66 S:84 M:50; do
        size=${spec%%:*}; pct=${spec##*:}
        case $size in
            L) rows=("${FT_L[@]}") ;;
            M) rows=("${FT_M[@]}") ;;
            *) rows=("${FT_S[@]}") ;;
        esac
        th=${#rows[@]}; tw=${#rows[0]}
        cx=$(( W * pct / 100 )); tx=$(( cx - tw / 2 ))
        (( tx < 0 || tx + tw > W )) && continue
        k=0
        for (( x = tx - 1; x <= tx + tw; x++ )); do (( x >= 0 && x < W && occ[x] )) && k=1; done
        (( k )) && continue
        for (( x = tx; x < tx + tw; x++ )); do occ[x]=1; done
        y0=$(( H - 1 - th ))
        for (( r = 0; r < th; r++ )); do
            for (( c = 0; c < tw; c++ )); do
                ch=${rows[r]:c:1}
                [[ $ch == ' ' ]] && continue
                case $ch in
                    '@'|'.'|',') cl=p ;;
                    'o'|'~') cl=r ;;
                    *) cl=b ;;
                esac
                i=$(( (y0 + r) * W + tx + c )); CH[i]=$ch; CL[i]=$cl
            done
        done
    done
    FOREST=()
    for (( y = 0; y < H; y++ )); do
        line=""; cur=' '
        for (( x = 0; x < W; x++ )); do
            i=$(( y * W + x )); c=${CL[i]}
            if [[ $c != "$cur" ]]; then
                case $c in
                    p) code=$PINK ;; r) code=$ROSE ;; b) code=$BROWN ;; t) code="${BOLD}${PINK}" ;; *) code="" ;;
                esac
                line+="${RESET}${code}"; cur=$c
            fi
            line+=${CH[i]}
        done
        FOREST+=("${line}${RESET}")
    done
    # If the terminal is wider/taller than the bounded drawing canvas, pad safely.
    if (( TARGET_W > W )); then
        local padleft=$(( (TARGET_W - W) / 2 )) padded
        for (( i=0; i<${#FOREST[@]}; i++ )); do
            printf -v padded '%*s%s' "$padleft" '' "${FOREST[i]}"
            FOREST[i]=$padded
        done
    fi
    if (( TARGET_H > H )); then
        local top_pad=$(( (TARGET_H - H) / 2 )) bottom_pad
        bottom_pad=$(( TARGET_H - H - top_pad ))
        local -a padded_rows=()
        for (( i=0; i<top_pad; i++ )); do padded_rows+=(""); done
        padded_rows+=("${FOREST[@]}")
        for (( i=0; i<bottom_pad; i++ )); do padded_rows+=(""); done
        FOREST=("${padded_rows[@]}")
    fi
    # Keep a small LRU-like cache. The single-key cache caused each panel to
    # rebuild its grove on every frame because panels have different dimensions.
    FOREST_CACHE_DATA[$cache_key]=$(printf '%s\n' "${FOREST[@]}")
    FOREST_CACHE_KEYS+=("$cache_key")
    if (( ${#FOREST_CACHE_KEYS[@]} > FOREST_CACHE_LIMIT )); then
        local evict=${FOREST_CACHE_KEYS[0]}
        unset "FOREST_CACHE_DATA[$evict]"
        FOREST_CACHE_KEYS=("${FOREST_CACHE_KEYS[@]:1}")
    fi
    FOREST_CACHE_KEY=$cache_key
}

MAIN_W=80; MAIN_MINROWS=0; HINT_BESIDE=0
build_main() {
    if (( PRIVACY )); then
        local w=$MAIN_W inner=$(( MAIN_W - 4 )) y
        FOREST_H=8; (( HINT_BESIDE )) && FOREST_H=${#HINT_ROWS[@]}
        [[ $FOREST_W == "$inner:$FOREST_H" ]] || { build_forest "$inner"; FOREST_W="$inner:$FOREST_H"; }
        MAIN=()
        box_top "$w" "${G_BLOSSOM} Sakura NetScope ${G_DOT} Privacy Mode" "$PINK"; MAIN+=("$BOX")
        for (( y = 0; y < FOREST_H; y++ )); do box_row "$w" "${FOREST[y]}" "$PINK"; MAIN+=("$BOX"); done
        box_bottom "$w" "" "$PINK"; MAIN+=("$BOX")
        return
    fi
    build_main_normal
}

format_net_rate() { # bytes/sec -> MB/s (Mbps); decimal network units
    local bytes=${1:-0} mb_whole mb_frac mbps_whole mbps_frac
    [[ $bytes =~ ^[0-9]+$ ]] || bytes=0
    mb_whole=$(( bytes / 1000000 )); mb_frac=$(( (bytes % 1000000) / 10000 ))
    mbps_whole=$(( bytes * 8 / 1000000 )); mbps_frac=$(( (bytes * 8 % 1000000) / 10000 ))
    printf '%d.%02d MB/s (%d.%02d Mbps)' "$mb_whole" "$mb_frac" "$mbps_whole" "$mbps_frac"
}

build_main_normal() {
    local w=$MAIN_W inner=$(( MAIN_W - 4 ))
    local -a L=() R=()
    local lw rw gap=3 treew=0 ts=-1 k rows i v st
    local -a TREEL=()

    internet_state
    kv "$INET_STATE" "Internet:" "$INET_LABEL"; L+=("$KV")
    if (( ENV_VALID )); then
        [[ -n $E_TYPE && $E_TYPE != UNKNOWN ]] && st=ok || st=unk
        kv "$st" "Network:" "${E_TYPE:-UNKNOWN}"; L+=("$KV")
        if [[ $E_TYPE == Wi-Fi ]]; then
            [[ $E_SSID != "N/A" ]] && st=ok || st=unk
            kv "$st" "SSID:" "${E_SSID:-N/A}"
        else kv unk "SSID:" "N/A"; fi
        L+=("$KV")
        if [[ -n $E_PHYS ]]; then kv info "Interface:" "$E_PHYS"; else kv unk "Interface:" "UNKNOWN"; fi; L+=("$KV")
        if [[ -n $E_IP ]]; then kv info "Local IP:" "$E_IP"; else kv unk "Local IP:" "UNKNOWN"; fi; L+=("$KV")
        case $E_GWSTATE in
            reply)   kv ok "Gateway:" "$E_GW (reply ${E_GWRTT}ms)" ;;
            noreply) kv warn "Gateway:" "$E_GW (no ICMP reply)" ;;
            onlink)  kv ok "Gateway:" "on-link route" ;;
            *)       if [[ $E_ROUTE == no ]]; then kv bad "Gateway:" "no default route"
                     elif [[ -n $E_GW ]]; then kv info "Gateway:" "$E_GW"
                     else kv unk "Gateway:" "UNKNOWN"; fi ;;
        esac
        L+=("$KV")
    else
        for v in "Network:" "SSID:" "Interface:" "Local IP:" "Gateway:"; do kv unk "$v" "measuring..."; L+=("$KV"); done
    fi
    kv info "Updated:" "${LAST_UPDATE:---:--:--}"; L+=("$KV")
    if (( E_RATE_VALID )); then
        kv ok "Download:" "$(format_net_rate "$E_DOWNLOAD_BPS")"; L+=("$KV")
        kv ok "Upload:" "$(format_net_rate "$E_UPLOAD_BPS")"; L+=("$KV")
    elif [[ -n $E_EGRESS ]]; then
        kv unk "Download:" "sampling link rate..."; L+=("$KV")
        kv unk "Upload:" "sampling link rate..."; L+=("$KV")
    else
        kv unk "Download:" "N/A"; L+=("$KV")
        kv unk "Upload:" "N/A"; L+=("$KV")
    fi

    # Desktop system proxy is independent from NetScope's own probe proxy.
    case $SYS_PROXY_STATE in
        active)   kv ok "System proxy:" "$SYS_PROXY_SOURCE" ;;
        inactive) kv unk "System proxy:" "$SYS_PROXY_SOURCE (off)" ;;
        *)        kv unk "System proxy:" "$SYS_PROXY_SOURCE" ;;
    esac
    R+=("$KV")
    local sysurl="$SYS_PROXY_URL"
    (( PRIVACY )) && sysurl="hidden (privacy mode)"
    kv info "System endpoint:" "$sysurl"; R+=("$KV")
    if [[ -z $PROXY_EP ]]; then kv unk "NetScope proxy:" "not configured"
    elif [[ $E_PROXY == ok ]]; then kv ok "NetScope proxy:" "reachable"
    elif [[ $E_PROXY == fail ]]; then kv bad "NetScope proxy:" "UNREACHABLE"
    else kv unk "NetScope proxy:" "UNKNOWN"; fi
    R+=("$KV")
    if [[ -n $PROXY_EP ]]; then kv info "Endpoint:" "$(pv "$PROXY_EP")"; else kv unk "Endpoint:" "N/A"; fi; R+=("$KV")
    case $E_TUNSTATE in
        routing) kv ok "VPN/Tunnel:" "ACTIVE (${E_VPN_NAME:-$E_TUN})" ;;
        idle)    kv warn "VPN/Tunnel:" "UP (${E_VPN_NAME:-$E_TUN}, not default route)" ;;
        none)    kv unk "VPN/Tunnel:" "NONE detected" ;;
        *)       kv unk "VPN/Tunnel:" "UNKNOWN" ;;
    esac
    R+=("$KV")
    if [[ -n $E_TUN ]]; then kv info "Tunnel IF:" "$(pv "$E_TUN")"; else kv unk "Tunnel IF:" "N/A"; fi; R+=("$KV")
    case $E_DNS in
        ok)   kv ok "DNS:" "working (${E_DNSMS}ms)" ;;
        fail) kv bad "DNS:" "FAILING" ;;
        *)    kv unk "DNS:" "UNKNOWN / cached" ;;
    esac
    R+=("$KV")
    local pr="direct"
    (( GLOBAL_VIA_PROXY )) && [[ -n $EFF_PROXY ]] && pr="GLOBAL via proxy"
    kv info "Refresh:" "${INTERVAL}s | probes ${pr}"; R+=("$KV")
    if (( PAUSED )); then kv warn "Monitor:" "PAUSED"
    elif (( CYCLE_RUNNING )); then kv ok "Monitor:" "ACTIVE (probing, cycle $((CYCLES + 1)))"
    elif (( CYCLES == 0 )); then kv unk "Monitor:" "STARTING"
    else kv ok "Monitor:" "ACTIVE (cycle $CYCLES)"; fi
    R+=("$KV")

    MAIN=()
    box_top "$w" "${G_BLOSSOM} Sakura NetScope" "$PINK"; MAIN+=("$BOX")

    local hdrL="${BOLD}${PINK}CONNECTION${RESET}" hdrR="${BOLD}${PINK}ROUTING & SETTINGS${RESET}"
    if (( MAIN_W >= 76 )); then
        if   (( MAIN_W >= 116 )); then TREEL=("${TREE_BIG[@]}");   treew=26; ts=-1
        elif (( MAIN_W >= 96 ));  then TREEL=("${TREE_SMALL[@]}"); treew=11; ts=0
        fi
        if (( treew )); then lw=$(( (inner - treew - 2 * gap) / 2 )); rw=$(( inner - treew - 2 * gap - lw ))
        else lw=$(( (inner - gap) / 2 )); rw=$(( inner - gap - lw )); fi
        rows=${#L[@]}; (( ${#R[@]} > rows )) && rows=${#R[@]}
        (( treew && ${#TREEL[@]} + ts > rows )) && rows=$(( ${#TREEL[@]} + ts ))
        (( rows < MAIN_MINROWS )) && rows=$MAIN_MINROWS
        local sp l r tr
        printf -v sp '%*s' "$gap" ''
        for (( i = -1; i < rows; i++ )); do
            if (( i < 0 )); then l=$hdrL; r=$hdrR; else l=${L[i]:-}; r=${R[i]:-}; fi
            padr "$l" "$lw"; l=$PADDED
            padr "$r" "$rw"; r=$PADDED
            tr=""
            if (( treew )); then
                k=$(( i - ts ))
                if (( k >= 0 && k < ${#TREEL[@]} )); then colorize_art "${TREEL[k]}"; tr="${sp}${ART}"
                else printf -v tr '%*s' $(( treew + gap )) ''; fi
            fi
            box_row "$w" "${l}${sp}${r}${tr}" "$PINK"; MAIN+=("$BOX")
        done
    else
        box_row "$w" "$hdrL" "$PINK"; MAIN+=("$BOX")
        for v in "${L[@]}"; do box_row "$w" "$v" "$PINK"; MAIN+=("$BOX"); done
        box_row "$w" "$hdrR" "$PINK"; MAIN+=("$BOX")
        for v in "${R[@]}"; do box_row "$w" "$v" "$PINK"; MAIN+=("$BOX"); done
    fi
    box_bottom "$w" "" "$PINK"; MAIN+=("$BOX")
}

# progress bar: width pct colour -> BARSTR   (pct < 0 = unknown)
make_bar() {
    local w=$1 p=$2 col=$3 n f e
    (( w < 3 )) && w=3
    if (( p < 0 )); then n=0; col=$GRAY; else n=$(( (p * w + 50) / 100 )); fi
    (( n > w )) && n=$w
    printf -v f '%*s' "$n" ''; f=${f// /$BAR_FULL}
    printf -v e '%*s' $(( w - n )) ''; e=${e// /$BAR_EMPTY}
    BARSTR="${GRAY}[${col}${f}${GRAY}${e}]${RESET}"
}

pct_text() { if (( $1 >= 0 )); then printf -v PCTT '%3d%%' "$1"; else PCTT=' N/A'; fi; }

# "── SITES ──" separator line (result in SEPLINE)
make_sep() { # inner panel-category
    local c=$2 state lab
    state=$(scan_section_label "$c" 1)
    lab=" SITES ${G_DOT} ${state} "
    hline $(( $1 - 2 - ${#lab} ))
    SEPLINE="${GRAY}${B_H}${B_H}${RESET}${BOLD}${PINK}${lab}${RESET}${GRAY}${HL}${RESET}"
}

# does a separator go before provider row r, when the window starts at off?
sep_before() { # r off   (uses ss from build_panel)
    (( ss >= 0 )) || return 1
    (( $1 == ss )) && return 0
    (( $1 == $2 && $2 > ss )) && return 0
    return 1
}

# how many providers fit when the window starts at off (sets WV)
calc_window() { # off   (uses n ss unit budget from build_panel)
    local off=$1 r used=0 cost
    WV=0
    for (( r = off; r < n; r++ )); do
        cost=$unit
        sep_before "$r" "$off" && cost=$(( cost + 1 ))
        (( used + cost > budget )) && break
        used=$(( used + cost )); WV=$(( WV + 1 ))
    done
    (( WV < 1 )) && WV=1
    (( WV > n )) && WV=n
}

# one provider as 2 lines (full) or 1 line (compact)
provider_rows() { # idx inner nw mode selected focused  -> PROWS array
    local i=$1 inner=$2 nw=$3 mode=$4 sel=$5 foc=$6
    local mark=" " scol rtt name state need via nm
    prov_metrics "$i"
    if ! provider_scan_enabled "$i"; then
        M_STATE=INACTIVE; M_PCT=0; M_LASTOK=-1
    fi
    clr_for "$M_STATE"; scol=$CLR
    if (( sel && ! NOSEL )); then
        if (( foc )); then mark="${ROSE}${G_MARK}${RESET}"; else mark="${GRAY}${G_MARK}${RESET}"; fi
    fi
    printf -v name '%-*s' "$nw" "${P_NAME[$i]}"
    if (( sel && ! NOSEL )) && [[ -n $REV ]]; then          # big, solid selection bar
        local hc=$GRAY; (( foc )) && hc=$ROSE
        # In the light Crystal Rose variant, use the flower purple on the cream selection surface.
        [[ $THEME == lightly-rose ]] && hc=$PINK
        mark=""; name="${REV}${BOLD}${hc}${G_MARK}${name}${RESET}"
    fi
    if [[ $M_STATE == INACTIVE ]]; then state='----------' ; else printf -v state '%-10s' "$M_STATE"; fi
    PROWS=()
    local bar_pct=$M_PCT
    if [[ $M_STATE == INACTIVE ]]; then
        rtt='none'
        pct_text -1
        bar_pct=-1
        scol=$GRAY
    else
        pct_text "$M_PCT"
    fi
    if [[ $mode == full ]]; then
        if [[ $M_STATE != INACTIVE ]]; then
            if [[ ${P_LASTRTT[$i]} != - ]]; then printf -v rtt 'RTT: %4sms' "${P_LASTRTT[$i]}"; else rtt='RTT:   --  '; fi
        fi
        via=""
        need=$(( 1 + nw + 2 + 10 + 2 + 11 ))
        (( M_STATE != INACTIVE && inner >= need + 7 )) && via="  ${GRAY}[${P_VIA[$i]}]${RESET}"
        if (( inner < need )) && [[ $M_STATE != INACTIVE ]]; then
            if [[ ${P_LASTRTT[$i]} != - ]]; then printf -v rtt '%4sms' "${P_LASTRTT[$i]}"; else rtt='   -- '; fi
        fi
        if [[ $M_STATE == INACTIVE ]]; then PROWS+=("${mark}${name}  ${state}  ${CYAN}${rtt}${RESET}${via}")
        else PROWS+=("${mark}${name}  ${scol}${state}${RESET}  ${CYAN}${rtt}${RESET}${via}"); fi
        make_bar $(( inner - 2 - 1 - 4 - 2 )) "$bar_pct" "$scol"
        PROWS+=("  ${BARSTR} ${scol}${PCTT}${RESET}")
    else
        if [[ $M_STATE != INACTIVE ]]; then
            if [[ ${P_LASTRTT[$i]} != - ]]; then printf -v rtt '%4sms' "${P_LASTRTT[$i]}"; else rtt='   -- '; fi
        fi
        make_bar $(( inner - (1 + nw + 1 + 10 + 1 + 6 + 1 + 1 + 4) - 2 )) "$bar_pct" "$scol"
        if [[ $M_STATE == INACTIVE ]]; then PROWS+=("${mark}${name} ${state} ${CYAN}${rtt}${RESET} ${BARSTR} ${scol}${PCTT}${RESET}")
        else PROWS+=("${mark}${name} ${scol}${state}${RESET} ${CYAN}${rtt}${RESET} ${BARSTR} ${scol}${PCTT}${RESET}"); fi
    fi
}

PRIVACY=0; FOREST_W=-1; FOREST_H=8; FOREST=(); FOREST_CACHE_KEY=""
FORCE_REDRAW=0
NOSEL=0
TITLES=(GLOBAL INSIDE)
SEL=(0 0)
SCR=(0 0)
FOCUS=0

# build_panel cat outer_w H mode -> PANEL array of boxed lines
build_panel() {
    local c=$1 w=$2 H=$3 mode=$4 inner=$(( $2 - 4 ))
    local bc=$PINK list i n=0 nw=4 hrows vis off sel lines=0 r rt ss unit budget
    local -a idx=() body=()
    (( c == FOCUS )) && bc="${BOLD}${PINK}"
    [[ $c == 0 ]] && list=$LIST0 || list=$LIST1
    for i in $list; do
        idx+=("$i"); n=$((n + 1))
        (( ${#P_NAME[$i]} > nw )) && nw=${#P_NAME[$i]}
    done
    (( nw > 20 )) && nw=20
    cat_summary "$c"

    PANEL=()

    # --- summary: connection state in the frame, six metrics in a tidy 3x2 grid ---
    local st ql s1 s2 bw half third left right tail
    local sum_status sum_quality sum_reach sum_reach_pct sum_mean sum_med sum_loss
    clr_for "$S_STATUS"
    sum_status="${CLR}${S_STATUS}${PINK}"
    local panel_title="${TITLES[c]} ${G_DOT} ${sum_status}"
    box_top "$w" "$panel_title" "$bc"; PANEL=("$BOX")
    third=$(( (inner - 6) / 3 )); (( third < 1 )) && third=1
    local c3=$(( inner - 2*third - 6 )) qlabel='Quality:' rlabel='Reachable:' plabel='Reachability:' mlabel='Mean ping:' medlabel='Median:' llabel='Packet loss:'
    # Keep the requested full labels when the panel is wide; compact them rather
    # than clipping values when both panels share a narrower terminal.
    if (( third < 16 )); then rlabel='Reach:'; plabel='Reach %:'; mlabel='Mean:'; llabel='Loss:'; fi
    clr_for "$S_QUAL"; sum_quality="${CYAN}${qlabel}${RESET} ${CLR}${S_QUAL}${RESET}"
    if (( S_EL > 0 )); then
        sum_reach="${CYAN}${rlabel}${RESET} ${S_RE}/${S_EL}"
        sum_reach_pct="${CYAN}${plabel}${RESET} ${S_PCT}%"
    else
        sum_reach="${CYAN}${rlabel}${RESET} -/-"
        sum_reach_pct="${GRAY}${plabel} N/A${RESET}"
    fi
    sum_mean="${CYAN}${mlabel}${RESET} ${S_MEAN}"; [[ $S_MEAN != "N/A" ]] && sum_mean+="ms"
    sum_med="${CYAN}${medlabel}${RESET} ${S_MED}"; [[ $S_MED != "N/A" ]] && sum_med+="ms"
    sum_loss="${CYAN}${llabel}${RESET} ${S_LOSS}"; [[ $S_LOSS != "N/A" ]] && sum_loss+="%"
    padr "$sum_quality" "$third"; left=$PADDED
    padr "$sum_reach" "$third"; right=$PADDED
    padr "$sum_reach_pct" "$c3"; tail=$PADDED
    box_row "$w" "${left}${GRAY} ${B_V} ${RESET}${right}${GRAY} ${B_V} ${RESET}${tail}" "$bc"; PANEL+=("$BOX")
    padr "$sum_mean" "$third"; left=$PADDED
    padr "$sum_med" "$third"; right=$PADDED
    padr "$sum_loss" "$c3"; tail=$PADDED
    box_row "$w" "${left}${GRAY} ${B_V} ${RESET}${right}${GRAY} ${B_V} ${RESET}${tail}" "$bc"; PANEL+=("$BOX")
    bw=$(( inner - 7 ))
    if (( S_PCT >= 0 )); then clr_for "$S_STATUS"; make_bar "$bw" "$S_PCT" "$CLR"; pct_text "$S_PCT"
    else make_bar "$bw" -1 "$GRAY"; PCTT=' N/A'; fi
    box_row "$w" "${BARSTR} ${CLR:-$GRAY}${PCTT}${RESET}" "$bc"; PANEL+=("$BOX")
    # --- providers + sites ---
    # Keep normal rows for inactive sections: status is grey, RTT says none, bars are empty.
    hrows=$(( H - 7 )); (( hrows < 2 )) && hrows=2
    ss=${SITE_START[c]}
    sel=${SEL[c]}; (( sel >= n )) && sel=$(( n - 1 )); (( sel < 0 )) && sel=0; SEL[c]=$sel
    if [[ $mode == full ]]; then unit=2; budget=100000; else unit=1; budget=$hrows; fi
    off=${SCR[c]}; (( off >= n )) && off=0
    (( sel < off )) && off=$sel
    calc_window "$off"
    while (( sel >= off + WV && off < n - 1 )); do off=$(( off + 1 )); calc_window "$off"; done
    while (( off > 0 )); do                       # use spare room: pull the window back
        calc_window $(( off - 1 ))
        if (( off - 1 + WV >= n )); then off=$(( off - 1 )); else break; fi
    done
    calc_window "$off"
    vis=$WV; SCR[c]=$off
    local rtxt=""
    if (( vis < n )); then
        rtxt="$((off + 1))-$((off + vis))/${n}"
        (( off > 0 )) && rtxt="${G_UP} ${rtxt}"
        (( off + vis < n )) && rtxt="${rtxt} ${G_DN}"
    fi
    local provider_state provider_title
    provider_state=$(scan_section_label "$c" 0)
    if [[ $provider_state == INACTIVE ]]; then provider_title="PROVIDERS ${G_DOT} INACTIVE"; else provider_title="PROVIDERS ${G_DOT} ACTIVE"; fi
    box_mid "$w" "$provider_title" "$bc" "$rtxt"; PANEL+=("$BOX")
    for (( r = off; r < off + vis; r++ )); do
        if sep_before "$r" "$off"; then
            make_sep "$inner" "$c"; box_row "$w" "$SEPLINE" "$bc"; body+=("$BOX"); lines=$((lines + 1))
        fi
        provider_rows "${idx[r]}" "$inner" "$nw" "$mode" $(( r == sel && c == FOCUS )) $(( c == FOCUS ))
        for rt in "${PROWS[@]}"; do
            box_row "$w" "$rt" "$bc"; body+=("$BOX"); lines=$((lines + 1))
        done
    done
    PANEL+=("${body[@]}")
    while (( ${#PANEL[@]} < H - 1 )); do box_row "$w" "" "$bc"; PANEL+=("$BOX"); done
    (( ${#PANEL[@]} > H - 1 )) && PANEL=("${PANEL[@]:0:H-1}")
    box_bottom "$w" "" "$bc"; PANEL+=("$BOX")
}

STATUS_MSG=""; MSG_UNTIL=0

# Hint rows are grouped by topic. Each regular row has two key/description cells;
# section labels are rendered as horizontal separators inside the Hints panel.
HINT_ROWS=(
"# NAVIGATION"
"q|quit|Tab|switch panel"
"Up/Dn|select item|Enter|item details"
"# MONITORING"
"r|refresh|p|pause/resume"
"+/-|interval|t|speed test"
"# TOOLS & PRIVACY"
"k|glossary|x|privacy mode"
"j|test mirrors|g|diagnostics"
"# THEME & SETTINGS"
"@setting||@theme|"
)
HINT_ROWS_DEFAULT=("${HINT_ROWS[@]}")

hint_separator() { # inner_width title -> HINT_SEP; title aligned right
    local inner=$1 title="$2" remain lhs
    remain=$(( inner - ${#title} - 1 )); (( remain < 0 )) && remain=0
    hline "$remain"; lhs=$HL
    HINT_SEP="${GRAY}${lhs}${RESET}${BOLD}${PINK} ${title}${RESET}"
}

build_hints() { # outer_w total_height -> HINTS
    local w=$1 h=$2 e k1 d1 k2 d2 row keycolor1 keycolor2 left right inner cw
    inner=$(( w - 4 )); cw=$(( (inner - 3) / 2 ))
    HINTS=()
    HINT_ROWS=("${HINT_ROWS_DEFAULT[@]}")
    box_top "$w" "Hints" "$PINK"; HINTS+=("$BOX")
    for e in "${HINT_ROWS[@]}"; do
        (( ${#HINTS[@]} >= h - 1 )) && break
        if [[ $e == \#* ]]; then
            hint_separator "$inner" "${e#\#}"
            box_row "$w" "$HINT_SEP" "$PINK"; HINTS+=("$BOX")
            continue
        fi
        IFS='|' read -r k1 d1 k2 d2 <<< "$e"
        keycolor1="${BOLD}${PINK}"; keycolor2="${BOLD}${PINK}"
        [[ $k1 == x ]] && { if (( PRIVACY )); then keycolor1="${BOLD}${PINK}"; else keycolor1="${BOLD}${ROSE}"; fi; }
        [[ $k2 == x ]] && { if (( PRIVACY )); then keycolor2="${BOLD}${PINK}"; else keycolor2="${BOLD}${ROSE}"; fi; }
        if [[ $k1 == @setting ]]; then
            # Decorative cue only; theme cycling itself uses the global ,/. keys.
            left="${BOLD}${PINK}<${RESET} ${ROSE}setting${RESET}"
        else
            printf -v left '%s%-5s%s %s%s%s' "$keycolor1" "$k1" "$RESET" "$ROSE" "$d1" "$RESET"
        fi
        if [[ $k2 == @theme ]]; then
            # Show a compact theme carousel; the active name is always live.
            right="${BOLD}${PINK}<${RESET} ${ROSE}$(theme_name "$THEME") ${BOLD}${PINK}>${RESET}"
        elif [[ -n $k2 ]]; then
            printf -v right '%s%-5s%s %s%s%s' "$keycolor2" "$k2" "$RESET" "$ROSE" "$d2" "$RESET"
        else
            right=""
        fi
        padr "$left" "$cw"; left=$PADDED
        if [[ -n $k2 ]]; then padr "$right" "$cw"; right=$PADDED
        else printf -v right '%*s' "$cw" ''; fi
        row="${left}   ${right}"
        box_row "$w" "$row" "$PINK"; HINTS+=("$BOX")
    done
    while (( ${#HINTS[@]} < h - 1 )); do box_row "$w" "" "$PINK"; HINTS+=("$BOX"); done
    box_bottom "$w" "" "$PINK"; HINTS+=("$BOX")
}

build_mirror_box() { # cat(2|3) outer_w -> MBOX; six providers displayed as three paired rows
    local c=$1 w=$2 inner=$(( $2 - 4 )) list i j row colw nw barw name state rtt pct stcolor status title
    local -a ids=()
    [[ $c == 2 ]] && list=$LIST2 || list=$LIST3
    for i in $list; do ids+=("$i"); done
    colw=$(( (inner - 3) / 2 )); (( colw < 18 )) && colw=18
    nw=10
    if [[ $c == 2 ]]; then title="Global Linux Mirrors"; else title="Inside Linux Mirrors"; fi
    if [[ $(scan_section_label "$c" 0) == INACTIVE ]]; then title+=" ${G_DOT} INACTIVE"; else title+=" ${G_DOT} ACTIVE"; fi
    MBOX=()
    box_top "$w" "$title" "$PINK"; MBOX+=("$BOX")
    for (( j=0; j<${#ids[@]}; j+=2 )); do
        row=""
        for (( i=j; i<j+2 && i<${#ids[@]}; i++ )); do
            local pi=${ids[i]}
            prov_metrics "$pi"
            if ! provider_scan_enabled "$pi"; then M_STATE=INACTIVE; M_PCT=0; M_LASTOK=-1; fi
            clr_for "$M_STATE"; stcolor=$CLR
            status=$M_STATE; [[ $status == "WARMING UP" ]] && status=WARM
            rtt=${P_LASTRTT[$pi]}; [[ $rtt == - ]] && rtt=--
            pct=$M_PCT
            if [[ $status == INACTIVE ]]; then stcolor=$GRAY; pct=-1; rtt=none; status='----'; fi
            pct_text "$pct"
            barw=$(( colw - nw - 19 )); (( barw < 3 )) && barw=3
            make_bar "$barw" "$pct" "$stcolor"
            printf -v name '%-10.10s' "${P_NAME[$pi]}"
            if [[ $status == '----' ]]; then local cell="${name} ${status} ${CYAN}$(printf '%3sms' "$rtt")${RESET} ${BARSTR} ${stcolor}${PCTT}${RESET}"
            else local cell="${name} ${stcolor}$(printf '%-4.4s' "$status")${RESET} ${CYAN}$(printf '%3sms' "$rtt")${RESET} ${BARSTR} ${stcolor}${PCTT}${RESET}"; fi
            # Pad each cell to its own half-width before positioning the second one.
            # This prevents the right-hand mirror column from drifting left on wide TTYs.
            padr "$cell" "$colw"; cell=$PADDED
            if (( i == j )); then row=$cell; else row+="   ${cell}"; fi
        done
        box_row "$w" "$row" "$PINK"; MBOX+=("$BOX")
    done
    box_bottom "$w" "" "$PINK"; MBOX+=("$BOX")
}
compose_frame() {
    local avail n0 n1 s0 s1 H H0 H1 mode wl wr i f0 f1 fm c0 c1 cm nf mh=0 mmode=none hw=50 hn k
    OUT=()
    if (( COLS < 40 || ROWS < 14 )); then
        OUT+=("Terminal too small: need 40x14, have ${COLS}x${ROWS}")
        return
    fi
    hn=$(( ${#HINT_ROWS[@]} + 2 ))
    HINT_BESIDE=0; MAIN_W=$COLS; MAIN_MINROWS=0
    if (( COLS >= 118 )); then HINT_BESIDE=1; MAIN_W=$(( COLS - hw - 1 )); MAIN_MINROWS=$(( hn - 3 )); fi
    build_main
    if (( HINT_BESIDE )); then
        build_hints "$hw" "${#MAIN[@]}"
        for (( i = 0; i < ${#MAIN[@]}; i++ )); do OUT+=("${HINTS[i]} ${MAIN[i]}"); done
    else
        OUT=("${MAIN[@]}")
    fi
    # The dashboard intentionally has no command strip at the bottom; all keys
    # are documented in the grouped Hints box, and the rest of the terminal stays clear.
    nf=0
    n0=${LCNT[0]}; n1=${LCNT[1]}; s0=${NSEP[0]}; s1=${NSEP[1]}
    avail=$(( ROWS - ${#OUT[@]} - nf ))
    # Linux Mirrors boxes (only when they leave the two main panels enough room)
    if (( LCNT[2] + LCNT[3] > 0 )); then
        k=${LCNT[2]}; (( LCNT[3] > k )) && k=${LCNT[3]}
        if (( COLS >= 98 )); then mh=$(( 2 + (k + 1) / 2 )); mmode=wide; else mh=$(( 4 + (LCNT[2] + 1) / 2 + (LCNT[3] + 1) / 2 )); mmode=stack; fi
        if (( avail - mh < 12 )); then mh=0; mmode=none; fi
    fi
    avail=$(( avail - mh ))
    if (( COLS >= 98 )); then
        wl=$(( (COLS - 1) / 2 )); wr=$(( COLS - 1 - wl ))
        f0=$(( 2 * n0 + s0 )); f1=$(( 2 * n1 + s1 )); fm=$f0; (( f1 > fm )) && fm=$f1
        c0=$(( n0 + s0 ));     c1=$(( n1 + s1 ));     cm=$c0; (( c1 > cm )) && cm=$c1
        if   (( 7 + fm <= avail )); then H=$(( 7 + fm )); mode=full
        elif (( 7 + cm <= avail )); then H=$(( 7 + cm )); mode=compact
        else H=$avail; mode=compact; fi
        (( H < 9 )) && H=9
        build_panel 0 "$wl" "$H" "$mode"; local -a PA=("${PANEL[@]}")
        build_panel 1 "$wr" "$H" "$mode"
        for (( i = 0; i < ${#PA[@]}; i++ )); do OUT+=("${PA[i]} ${PANEL[i]}"); done
    else
        local share=$(( avail / 2 ))
        if   (( 7 + 2 * n0 + s0 <= share )); then H0=$(( 7 + 2 * n0 + s0 )); mode=full
        elif (( 7 + n0 + s0 <= share )); then H0=$(( 7 + n0 + s0 )); mode=compact
        else H0=$share; mode=compact; fi
        (( H0 < 9 )) && H0=9
        build_panel 0 "$COLS" "$H0" "$mode"; OUT+=("${PANEL[@]}")
        local rest=$(( avail - H0 ))
        if   (( 7 + 2 * n1 + s1 <= rest )); then H1=$(( 7 + 2 * n1 + s1 )); mode=full
        elif (( 7 + n1 + s1 <= rest )); then H1=$(( 7 + n1 + s1 )); mode=compact
        else H1=$rest; mode=compact; fi
        (( H1 < 9 )) && H1=9
        build_panel 1 "$COLS" "$H1" "$mode"; OUT+=("${PANEL[@]}")
    fi
    if [[ $mmode == wide ]]; then
        build_mirror_box 2 "$wl"; local -a MA=("${MBOX[@]}")
        build_mirror_box 3 "$wr"
        for (( i = 0; i < mh; i++ )); do
            local a=${MA[i]:-} b=${MBOX[i]:-}
            [[ -n $a ]] || printf -v a '%*s' "$wl" ''
            [[ -n $b ]] || printf -v b '%*s' "$wr" ''
            OUT+=("$a $b")
        done
    elif [[ $mmode == stack ]]; then
        build_mirror_box 2 "$COLS"; OUT+=("${MBOX[@]}")
        build_mirror_box 3 "$COLS"; OUT+=("${MBOX[@]}")
    fi
}

# ── Terminal handling ────────────────────────────────────────────────────────
ROWS=24; COLS=80; FORCE_COLS=""; FORCE_ROWS=""; RESIZED=0
TTY_ACTIVE=0; STTY_SAVED=""
# Terminal dimensions are used for layout only; no minimum-size warning/clearing guard.
get_size() {
    local r c
    if [[ -n $FORCE_COLS ]]; then COLS=$FORCE_COLS; ROWS=${FORCE_ROWS:-45}; return; fi
    if read -r r c < <(stty size 2>/dev/null) && [[ $r =~ ^[0-9]+$ && $c =~ ^[0-9]+$ ]] && (( r > 0 && c > 0 )); then
        ROWS=$r; COLS=$c
    else
        ROWS=${LINES:-24}; COLS=${COLUMNS:-80}
    fi
}

paint() { # OUT -> terminal, no flicker
    local buf=$'\e[H'"${RESET}" i n=${#OUT[@]}
    (( n > ROWS )) && n=$ROWS
    for (( i = 0; i < n; i++ )); do
        buf+="${OUT[i]}${RESET}"$'\e[K'
        (( i < n - 1 )) && buf+=$'\n'
    done
    buf+=$'\e[J'
    printf '%s' "$buf"
}

tty_enter() { STTY_SAVED="$(stty -g 2>/dev/null || true)"; printf '\e[?1049h\e[?25l\e[2J'; TTY_ACTIVE=1; }
tty_leave() { (( TTY_ACTIVE )) || return 0; printf '\e[0m\e[?25h\e[?1049l'; [[ -n $STTY_SAVED ]] && stty "$STTY_SAVED" 2>/dev/null; TTY_ACTIVE=0; }

read_key() { # timeout -> KEY ; rc 1 timeout, 2 EOF
    local k seq rc
    KEY=""
    IFS= read -rsn1 -t "$1" k; rc=$?
    if (( rc > 128 )); then return 1; elif (( rc != 0 )); then return 2; fi
    if [[ $k == $'\e' ]]; then
        seq=""; IFS= read -rsn2 -t 0.05 seq 2>/dev/null
        case $seq in
            '[A') KEY=UP ;; '[B') KEY=DOWN ;; '[C') KEY=RIGHT ;; '[D') KEY=LEFT ;;
            '[H') KEY=HOME ;; '[F') KEY=END ;;
            '[5') IFS= read -rsn1 -t 0.05 seq 2>/dev/null; KEY=PGUP ;;
            '[6') IFS= read -rsn1 -t 0.05 seq 2>/dev/null; KEY=PGDN ;;
            *) KEY=ESC ;;
        esac
    elif [[ -z $k ]]; then KEY=ENTER
    elif [[ $k == $'\t' ]]; then KEY=TAB
    elif [[ $k == ',' ]]; then theme_shortcut -1
    elif [[ $k == '.' ]]; then theme_shortcut 1
    else KEY=$k; fi
    return 0
}

# generic responsive frame: small screens are centered; long/list screens use the terminal.
draw_screen() {
    local title=$1 foot=$2 w l i maxline=0 full=0 boxh top padx pad
    local -a CONTENT=()
    get_size
    for l in "${SCREEN[@]}"; do
        vlen "$l"
        (( VL > maxline )) && maxline=$VL
    done
    # Long content and scrolling/list views benefit from the full terminal.
    (( ${#SCREEN[@]} >= ROWS / 2 || maxline > 100 )) && full=1
    case $title in Settings|Glossary*) full=1 ;; System\ Mirrors*) full=0 ;; esac
    if (( full )); then
        w=$COLS; (( w < 40 )) && w=40
    else
        w=$(( maxline + 4 )); (( w < 40 )) && w=40; (( w > 110 )) && w=110; (( w > COLS )) && w=$COLS
    fi
    OUT=()
    box_top "$w" "${G_BLOSSOM} $title" "$PINK"; CONTENT+=("$BOX")
    for l in "${SCREEN[@]}"; do box_row "$w" "$l" "$PINK"; CONTENT+=("$BOX"); done
    box_bottom "$w" "" "$PINK"; CONTENT+=("$BOX")
    if declare -p SCREEN_OUTSIDE >/dev/null 2>&1; then for l in "${SCREEN_OUTSIDE[@]}"; do CONTENT+=("$l"); done; SCREEN_OUTSIDE=(); fi
    if (( full )); then
        # Fill the terminal height so the frame scales with terminal resizes.
        boxh=${#CONTENT[@]}
        while (( boxh < ROWS - 1 )); do
            box_row "$w" "" "$PINK"; CONTENT+=("$BOX"); boxh=$((boxh + 1))
        done
        (( boxh > ROWS - 1 )) && CONTENT=("${CONTENT[@]:0:ROWS-1}")
        OUT=("${CONTENT[@]}" "${GRAY}${foot}${RESET}")
    else
        boxh=${#CONTENT[@]}
        top=$(( (ROWS - boxh - 1) / 2 )); (( top < 0 )) && top=0
        padx=$(( (COLS - w) / 2 )); (( padx < 0 )) && padx=0
        printf -v pad '%*s' "$padx" ''
        for (( i=0; i<top; i++ )); do OUT+=(""); done
        for l in "${CONTENT[@]}"; do OUT+=("${pad}${l}"); done
        OUT+=("${pad}${GRAY}${foot}${RESET}")
    fi
    paint
}

# ── Diagnostics ──────────────────────────────────────────────────────────────
tool_row() { # name path purpose hint
    local ic
    if [[ -n $2 ]]; then ic="${GREEN}${G_OK}${RESET}"; printf -v TR '%s %-10s %s%s%s' "$ic" "$1" "$GRAY" "$2" "$RESET"
    else ic="${YELLOW}${G_BAD}${RESET}"; printf -v TR '%s %-10s %smissing%s %s(%s; install: %s)%s' "$ic" "$1" "$YELLOW" "$RESET" "$GRAY" "$3" "$4" "$RESET"; fi
}

build_diag() {
    SCREEN=()
    local t m
    SCREEN+=("${BOLD}${PINK}TOOLS${RESET}")
    tool_row ping "$PING_BIN" "ICMP probes" "iputils / iputils-ping / inetutils-ping"; SCREEN+=("$TR")
    tool_row curl "$CURL_BIN" "HTTPS probes" "curl"; SCREEN+=("$TR")
    tool_row wget "$WGET_BIN" "HTTPS fallback" "wget"; SCREEN+=("$TR")
    tool_row ip "$IP_BIN" "routes/addresses, falls back to /proc" "iproute2 / iproute"; SCREEN+=("$TR")
    tool_row timeout "$TIMEOUT_BIN" "limits probe time" "coreutils"; SCREEN+=("$TR")
    tool_row "dns tool" "$DNS_TOOL" "DNS provider checks" "bind-utils / dnsutils / bind-tools"; SCREEN+=("$TR")
    tool_row "wifi" "${IWGETID_BIN:-${IW_BIN:-$NMCLI_BIN}}" "SSID lookup" "wireless-tools / iw / networkmanager"; SCREEN+=("$TR")
    tool_row pkill "$PKILL_BIN" "quick child clean-up" "procps / procps-ng"; SCREEN+=("$TR")
    SCREEN+=("")
    SCREEN+=("${BOLD}${PINK}CAPABILITIES${RESET}")
    if (( ICMP_OK )); then SCREEN+=("${GREEN}${G_OK}${RESET} ${CYAN}ICMP${RESET}      usable")
    else SCREEN+=("${YELLOW}${G_BAD}${RESET} ${CYAN}ICMP${RESET}      ${YELLOW}${ICMP_NOTE}${RESET}"); fi
    if [[ -n $CURL_BIN || -n $WGET_BIN ]]; then SCREEN+=("${GREEN}${G_OK}${RESET} ${CYAN}HTTPS${RESET}     available")
    else SCREEN+=("${YELLOW}${G_BAD}${RESET} ${CYAN}HTTPS${RESET}     ${YELLOW}no curl/wget: HTTPS checks are skipped${RESET}"); fi
    if (( ! ICMP_OK )) && [[ -z $CURL_BIN && -z $WGET_BIN && -z $DNS_TOOL ]]; then
        SCREEN+=("${RED}${G_BAD}${RESET} ${RED}No probe method available — install ping or curl.${RESET}")
    fi
    SCREEN+=("")
    SCREEN+=("${BOLD}${PINK}ENVIRONMENT${RESET}")
    m="no"; (( UI_ASCII )) && m="ASCII fallback" || m="Unicode"
    SCREEN+=("${CYAN}Terminal${RESET}   ${COLS}x${ROWS}, ${m}, TERM=${TERM:-unset}")
    if [[ -n $EFF_PROXY ]]; then SCREEN+=("${CYAN}Proxy${RESET}      $(pv "$PROXY_EP") (credentials hidden)")
    else SCREEN+=("${CYAN}Proxy${RESET}      not configured"); fi
    SCREEN+=("${CYAN}Providers${RESET}  ${NPROV} (config: ${PROVIDERS_FILE##*/}$( [[ -f $PROVIDERS_FILE ]] && printf ' found' || printf ' not present'))")
    SCREEN+=("${CYAN}Settings${RESET}   $(hp "$SETTINGS_FILE")")
    SCREEN+=("${CYAN}Theme${RESET}      $(theme_name "$THEME")")
    SCREEN+=("${CYAN}Version${RESET}    ${APP} version ${VERSION}")
    SCREEN+=("${CYAN}Install mode${RESET} $(install_mode_label)")
    if [[ -x $INSTALL_PATH ]]; then SCREEN+=("${CYAN}Installed${RESET}  $(hp "$INSTALL_PATH")")
    else SCREEN+=("${CYAN}Installed${RESET}  ${YELLOW}no${RESET}"); fi
    t="$(grep -E '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | head -n3 | tr '\n' ' ')"
    SCREEN+=("${CYAN}Resolvers${RESET}  $(pv "${t:-unknown}")")
}

# ── Provider details ─────────────────────────────────────────────────────────
details_screen() {
    local c=$FOCUS list pi k
    local -a l
    [[ $c == 0 ]] && list=$LIST0 || list=$LIST1
    read -ra l <<< "$list"
    pi=${l[${SEL[c]}]:-}
    [[ -n $pi ]] || return 0
    while true; do
        prov_metrics "$pi"
        clr_for "$M_STATE"
        local h=${P_HIST[$pi]} hs="" ch s mean="N/A" mn="N/A" mx="N/A" ilos="N/A" z v sum=0 cnt=0
        for (( k = 0; k < ${#h}; k++ )); do
            ch=${h:k:1}
            if [[ $ch == 1 ]]; then hs+="${GREEN}${BAR_FULL}"; else hs+="${RED}x"; fi
        done
        hs+="${RESET}"
        for v in ${P_RTTS[$pi]}; do
            sum=$((sum + v)); cnt=$((cnt + 1))
            [[ $mn == "N/A" || v -lt mn ]] && mn=$v
            [[ $mx == "N/A" || v -gt mx ]] && mx=$v
        done
        (( cnt )) && mean=$(( sum / cnt ))
        z=${P_IHIST[$pi]}
        if [[ -n $z ]]; then s=${z//1/}; ilos=$(( ${#s} * 100 / ${#z} ))%; fi
        SCREEN=()
        local gl="provider"; [[ ${P_GRP[$pi]} == 1 ]] && gl="site"
        SCREEN+=("${BOLD}${PINK}${P_NAME[$pi]}${RESET}  ${GRAY}(${TITLES[c]} ${gl})${RESET}")
        SCREEN+=("${CYAN}Host${RESET}        ${P_HOST[$pi]}")
        SCREEN+=("${CYAN}Checks${RESET}      ${P_CHK[$pi]}")
        [[ -n ${P_NOTE[$pi]} ]] && SCREEN+=("${CYAN}Note${RESET}        ${P_NOTE[$pi]}")
        SCREEN+=("")
        SCREEN+=("${CYAN}State${RESET}       ${CLR}${M_STATE}${RESET}")
        pct_text "$M_PCT"; SCREEN+=("${CYAN}Reachability${RESET} ${PCTT# }   (${M_ONES}/${M_SAMPLES} cycles, window ${WINDOW}, warm-up ${MIN_SAMPLES})")
        SCREEN+=("${CYAN}ICMP${RESET}        last ${P_ICMP[$pi]}, latest RTT ${P_LASTRTT[$pi]}ms, mean ${mean}ms, min ${mn}ms, max ${mx}ms, loss ${ilos}")
        SCREEN+=("${CYAN}HTTPS${RESET}       last ${P_HTTPS[$pi]}, HTTP ${P_HCODE[$pi]}, ${P_HMS[$pi]}ms")
        SCREEN+=("${CYAN}DNS${RESET}         last ${P_DNS[$pi]}")
        SCREEN+=("${CYAN}Last via${RESET}    ${P_VIA[$pi]}   ${GRAY}(i = ICMP, h = HTTPS, d = DNS)${RESET}")
        SCREEN+=("")
        SCREEN+=("${CYAN}History${RESET}     ${hs:-${GRAY}no samples yet${RESET}}")
        draw_screen "Provider details" ", previous theme   . next theme   any other key: back"
        if read_key 0.5; then
            [[ $KEY == THEME_CHANGED ]] && continue
            return 0
        fi
        if cycle_finished; then
            if (( CYCLE_TIMED_OUT )); then kill_children; else reap_children; fi
            ingest_cycle; CYCLE_RUNNING=0; CYCLE_TIMED_OUT=0; NEXT_AT=$(( SECONDS + INTERVAL ))
        fi
        if (( ! CYCLE_RUNNING && ! PAUSED && SECONDS >= NEXT_AT )); then start_cycle; fi
    done
}

diag_screen() {
    build_diag
    draw_screen "Diagnostics" ", previous theme   . next theme   any other key: back"
    while true; do
        if read_key 0.5; then
            if [[ $KEY == THEME_CHANGED ]]; then
                build_diag
                draw_screen "Diagnostics" ", previous theme   . next theme   any other key: back"
                continue
            fi
            return 0
        fi
        if (( RESIZED )); then
            RESIZED=0; build_diag
            draw_screen "Diagnostics" ", previous theme   . next theme   any other key: back"
        fi
    done
}

install_mode_label() {
    case ${INSTALL_MODE:-local} in system) printf 'System-wide' ;; local) printf 'Local' ;; demo) printf 'Demo mode' ;; *) printf 'Not selected' ;; esac
}

# ── Read-only test of active system package sources (key j) ───────────────────
SYS_MIRROR_URLS=(); SYS_MIRROR_NAMES=(); SYS_MIRROR_SOURCES=(); SYS_MIRROR_STATES=(); SYS_MIRROR_CODES=(); SYS_MIRROR_TIMES=()
SYS_OS_NAME="Linux"; SYS_OS_ID="unknown"; SYS_OS_VERSION=""; SYS_ARCH=""

system_mirror_add() { # source-label url
    local src=$1 url=$2 old arch
    url="$(trim "$url")"; url=${url%,}; url=${url%\"}; url=${url#\"}
    [[ $url =~ ^https?://[^[:space:]]+$ ]] || return 0
    arch=${SYS_ARCH:-$(uname -m 2>/dev/null || printf unknown)}
    url=${url//\$repo/core}
    url=${url//\$\{arch\}/$arch}; url=${url//\$arch/$arch}
    url=${url//\$\{basearch\}/$arch}; url=${url//\$basearch/$arch}
    url=${url//\$\{releasever\}/${SYS_OS_VERSION:-current}}
    url=${url//\$releasever/${SYS_OS_VERSION:-current}}
    [[ $url == *'$'* ]] && return 0
    for old in "${SYS_MIRROR_URLS[@]}"; do [[ $old == "$url" ]] && return 0; done
    SYS_MIRROR_URLS+=("$url")
    SYS_MIRROR_NAMES+=("$src")
    SYS_MIRROR_SOURCES+=("$src")
    SYS_MIRROR_STATES+=("WAIT")
    SYS_MIRROR_CODES+=("--")
    SYS_MIRROR_TIMES+=("--")
}

read_os_identity() {
    local k v
    SYS_OS_NAME="Linux"; SYS_OS_ID="unknown"; SYS_OS_VERSION=""; SYS_ARCH="$(uname -m 2>/dev/null || printf unknown)"
    if [[ -r /etc/os-release ]]; then
        while IFS='=' read -r k v; do
            v=${v%$'\r'}; v=${v%\"}; v=${v#\"}; v=${v%\'}; v=${v#\'}
            case $k in ID) SYS_OS_ID=${v,,} ;; VERSION_ID) SYS_OS_VERSION=$v ;; PRETTY_NAME) SYS_OS_NAME=$v ;; esac
        done < /etc/os-release
    fi
}

collect_active_system_mirrors() {
    local f url pair name source value
    local -a files=()
    SYS_MIRROR_URLS=(); SYS_MIRROR_NAMES=(); SYS_MIRROR_SOURCES=(); SYS_MIRROR_STATES=(); SYS_MIRROR_CODES=(); SYS_MIRROR_TIMES=()
    read_os_identity

    # APT: classic .list syntax and Deb822 .sources syntax, ignoring comments/disabled stanzas.
    for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
        [[ -r $f && -f $f ]] || continue
        while IFS= read -r url; do system_mirror_add "APT:$(basename "$f")" "$url"; done < <(awk '
            /^[[:space:]]*#/ {next}
            { if ($1 == "deb" || $1 == "deb-src") { i=2; if ($2 ~ /^\[/) i=3; if ($i ~ /^https?:\/\//) print $i } }
        ' "$f" 2>/dev/null)
    done
    for f in /etc/apt/sources.list.d/*.sources; do
        [[ -r $f && -f $f ]] || continue
        while IFS= read -r url; do system_mirror_add "APT:$(basename "$f")" "$url"; done < <(awk '
            BEGIN { enabled=1 }
            function flush(){ if (enabled) for (i=1;i<=n;i++) print uri[i]; n=0; delete uri; enabled=1; inuris=0 }
            /^[[:space:]]*#/ {next}
            /^[[:space:]]*$/ {flush(); next}
            /^[^[:space:]][^:]*:/ {
                key=tolower($1); val=$0; sub(/^[^:]*:[[:space:]]*/, "", val)
                if (key == "enabled:") { v=tolower(val); if (v=="no" || v=="false" || v=="0") enabled=0; inuris=0; next }
                if (key == "uris:") { inuris=1; gsub(/,/, " ", val); m=split(val,a,/[[:space:]]+/); for(j=1;j<=m;j++) if(a[j] ~ /^https?:\/\//) uri[++n]=a[j]; next }
                inuris=0; next
            }
            inuris { val=$0; gsub(/,/, " ", val); m=split(val,a,/[[:space:]]+/); for(j=1;j<=m;j++) if(a[j] ~ /^https?:\/\//) uri[++n]=a[j] }
            END {flush()}
        ' "$f" 2>/dev/null)
    done

    # Arch: active Server entries from pacman's standard mirrorlist and pacman.conf.
    for f in /etc/pacman.d/mirrorlist /etc/pacman.conf; do
        [[ -r $f && -f $f ]] || continue
        while IFS= read -r url; do system_mirror_add "pacman:$(basename "$f")" "$url"; done < <(sed -nE 's/^[[:space:]]*Server[[:space:]]*=[[:space:]]*(https?:\/\/[^[:space:]#]+).*/\1/p' "$f" 2>/dev/null)
    done

    # RPM repositories (Fedora/RHEL/openSUSE): use only enabled repo sections.
    for f in /etc/yum.repos.d/*.repo /etc/dnf/repos.d/*.repo /etc/zypp/repos.d/*.repo; do
        [[ -r $f && -f $f ]] || continue
        while IFS= read -r url; do system_mirror_add "repo:$(basename "$f")" "$url"; done < <(awk -F= '
            function flush(){ if (enabled) for (i=1;i<=n;i++) print urls[i]; n=0; delete urls; enabled=1 }
            /^[[:space:]]*[#;]/ {next}
            /^[[:space:]]*\[[^]]+\]/ {flush(); next}
            {
                key=tolower($1); gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
                val=$0; sub(/^[^=]*=/, "", val); gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
                if (key=="enabled" && val ~ /^0([[:space:]]|$)/) {enabled=0; next}
                if (key=="baseurl" || key=="metalink" || key=="mirrorlist") { m=split(val,a,/[[:space:]]+/); for(j=1;j<=m;j++) if(a[j] ~ /^https?:\/\//) urls[++n]=a[j] }
            }
            END {flush()}
        ' "$f" 2>/dev/null)
    done

    # Nix binary cache substituters from current config and `nix show-config`.
    for f in /etc/nix/nix.conf "${XDG_CONFIG_HOME:-$HOME/.config}/nix/nix.conf"; do
        [[ -r $f && -f $f ]] || continue
        while IFS= read -r url; do system_mirror_add "nix:$(basename "$f")" "$url"; done < <(awk -F= '/^[[:space:]]*#/ {next} tolower($1) ~ /^[[:space:]]*substituters[[:space:]]*$/ {gsub(/,/, " ", $2); n=split($2,a,/[[:space:]]+/); for(i=1;i<=n;i++) if(a[i] ~ /^https?:\/\//) print a[i]}' "$f" 2>/dev/null)
    done
    if have nix; then
        while IFS= read -r url; do system_mirror_add "nix:active-config" "$url"; done < <(nix show-config substituters 2>/dev/null | awk -F= '{gsub(/,/, " ", $2); n=split($2,a,/[[:space:]]+/); for(i=1;i<=n;i++) if(a[i] ~ /^https?:\/\//) print a[i]}')
    fi

    # Flatpak: the remotes the user actually has configured.
    if have flatpak; then
        while IFS='|' read -r name url; do
            [[ $name == Name || $name == "" ]] && continue
            system_mirror_add "flatpak:$name" "$url"
        done < <(flatpak remotes --show-details --columns=name,url 2>/dev/null | awk 'NF>=2 && $2 ~ /^https?:\/\// {print $1 "|" $2}')
    fi
}

system_mirror_probe() { # URL -> SYS_PROBE_STATE SYS_PROBE_CODE SYS_PROBE_MS
    local url=$1 out code seconds ms t0 t1
    SYS_PROBE_STATE=DOWN; SYS_PROBE_CODE="--"; SYS_PROBE_MS="--"
    if [[ -n $CURL_BIN ]]; then
        out="$(LC_ALL=C "$CURL_BIN" -sS -o /dev/null -I -L -w '%{http_code} %{time_total}' --noproxy '*' --connect-timeout 2 --max-time 4 --max-redirs 4 "$url" 2>/dev/null)" || out=""
        code=${out%% *}; seconds=${out#* }
        if [[ $code =~ ^[1-5][0-9][0-9]$ ]]; then
            SYS_PROBE_CODE=$code
            t=${seconds#*.}; seconds=${seconds%%.*}; t="${t}000"; [[ $seconds =~ ^[0-9]+$ ]] || seconds=0; [[ ${t:0:3} =~ ^[0-9]+$ ]] || t=000
            ms=$(( 10#$seconds * 1000 + 10#${t:0:3} )); SYS_PROBE_MS=$ms
            if (( 10#$code < 400 )); then SYS_PROBE_STATE=UP
            elif (( 10#$code < 500 )); then SYS_PROBE_STATE="HTTP $code"
            else SYS_PROBE_STATE="HTTP $code"; fi
            return 0
        fi
    elif [[ -n $WGET_BIN ]]; then
        now_ms; t0=$NOW_MS
        if LC_ALL=C run_to 4 "$WGET_BIN" -q --spider -T 3 -t 1 --no-proxy "$url" >/dev/null 2>&1; then
            now_ms; t1=$NOW_MS; SYS_PROBE_STATE=UP; SYS_PROBE_CODE="OK"; SYS_PROBE_MS=$((t1-t0)); return 0
        fi
    else SYS_PROBE_STATE="NO CURL/WGET"; fi
    return 1
}

system_mirror_render() { # offset message
    local off=${1:-0} message=${2:-} i n w vis inner urlw url src state statecolor code ms line sp np tp cp maxoff
    get_size; w=$COLS; (( w < 40 )) && w=40
    n=${#SYS_MIRROR_URLS[@]}; vis=$(( ROWS - 9 )); (( vis < 3 )) && vis=3
    maxoff=$(( n - vis )); (( maxoff < 0 )) && maxoff=0; (( off < 0 )) && off=0; (( off > maxoff )) && off=$maxoff
    inner=$(( w - 8 ))
    if (( w < 70 )); then urlw=$(( inner - 18 )); else urlw=$(( inner - 46 )); fi
    (( urlw < 8 )) && urlw=8
    SCREEN=("${BOLD}${PINK}${SYS_OS_NAME}${RESET}  ${GRAY}(ID=${SYS_OS_ID}${SYS_OS_VERSION:+, version $SYS_OS_VERSION}; arch=$SYS_ARCH)${RESET}" \
            "${CYAN}Read-only scan:${RESET} active package/cache URLs discovered in local configuration; nothing is changed." "")
    if (( n == 0 )); then
        SCREEN+=("${YELLOW}No active HTTP(S) package mirrors were found in supported configuration files.${RESET}" \
                 "Supported: APT sources, pacman mirrorlist, RPM .repo files, Nix substituters and Flatpak remotes." )
    else
        for (( i=off; i<off+vis && i<n; i++ )); do
            url=${SYS_MIRROR_URLS[i]}; src=${SYS_MIRROR_SOURCES[i]}; state=${SYS_MIRROR_STATES[i]}; code=${SYS_MIRROR_CODES[i]}; ms=${SYS_MIRROR_TIMES[i]}
            # Never print URL user-info (possible username/password) on the TUI.
            if [[ $url == *://*@* ]]; then local scheme=${url%%://*} rest=${url#*://}; rest=${rest#*@}; url="$scheme://$rest"; fi
            case $state in UP) statecolor=$GREEN ;; WAIT|TESTING) statecolor=$YELLOW ;; *HTTP*) statecolor=$YELLOW ;; DOWN) statecolor=$RED ;; *) statecolor=$GRAY ;; esac
            [[ ${#url} -gt $urlw ]] && url="${url:0:$((urlw-1))}…"
            if (( w < 70 )); then
                printf -v sp '%-10.10s' "$state"; printf -v tp '%5sms' "$ms"
                SCREEN+=("${statecolor}${sp}${RESET} ${CYAN}${tp}${RESET} ${url}")
            else
                printf -v sp '%-12s' "$state"; printf -v np '%-18.18s' "$src"; printf -v tp '%5sms' "$ms"; printf -v cp '%-5s' "$code"
                SCREEN+=("${statecolor}${sp}${RESET} ${GRAY}${np}${RESET} ${CYAN}${tp}${RESET} ${GRAY}${cp}${RESET} ${url}")
            fi
        done
        SCREEN+=("")
        if [[ -n $message ]]; then SCREEN+=("${BOLD}${PINK}${message}${RESET}")
        else SCREEN+=("Results are connection checks, not a package-signature or mirror-sync validation."); fi
        (( off > 0 )) && SCREEN+=("${GRAY}Showing $(($off+1))-$(( off + vis < n ? off + vis : n )) of $n endpoints.${RESET}")
    fi
    SCREEN_OUTSIDE=()
    draw_screen "System Mirrors" "Up/Down scroll   r rescan   ,/. change theme   j / q / Esc back"
}

system_mirrors_screen() {
    local i off=0 n batch=0 cpid keymsg="" cancelled=0 leave=0
    collect_active_system_mirrors
    n=${#SYS_MIRROR_URLS[@]}
    system_mirror_render 0 "${n} active mirror/cache endpoint(s) found; preparing checks..."
    if (( n > 0 )); then
        for (( i=0; i<n; i++ )); do
            SYS_MIRROR_STATES[i]=TESTING
            system_mirror_render "$off" "Testing endpoint $((i+1)) of $n... (c stop, Esc stop & back)"
            # Run each probe asynchronously so key handling remains responsive.
            local result_file="$TMPD/sysmirror-result-$i"
            rm -f "$result_file"
            ( system_mirror_probe "${SYS_MIRROR_URLS[i]}"; printf '%s\n' "$SYS_PROBE_STATE|$SYS_PROBE_CODE|$SYS_PROBE_MS" > "$result_file" ) &
            cpid=$!
            while kill -0 "$cpid" 2>/dev/null; do
                if read_key 0.1; then
                    case $KEY in
                        c|C) cancelled=1; keymsg="Scan stopped by user."; pkill -TERM -P "$cpid" 2>/dev/null || :; kill "$cpid" 2>/dev/null; wait "$cpid" 2>/dev/null || :; break ;;
                        ESC|q|Q|j|J) cancelled=1; leave=1; keymsg="Scan stopped; returning to dashboard."; pkill -TERM -P "$cpid" 2>/dev/null || :; kill "$cpid" 2>/dev/null; wait "$cpid" 2>/dev/null || :; break ;;
                        r|R) keymsg="Scan is running; press c to stop or Esc to stop and return." ;;
                        UP|k) (( off > 0 )) && off=$((off-1)) ;;
                        DOWN) get_size; local vis=$(( ROWS - 9 )); (( vis < 3 )) && vis=3; (( off + vis < n )) && off=$((off+1)) ;;
                    esac
                    system_mirror_render "$off" "${keymsg:-Testing endpoint $((i+1)) of $n... (c stop, Esc stop & back)}"
                    keymsg=""
                elif (( RESIZED )); then RESIZED=0; system_mirror_render "$off" "Testing endpoint $((i+1)) of $n... (c stop, Esc stop & back)"; fi
            done
            wait "$cpid" 2>/dev/null || :
            if (( leave )); then rm -f "$TMPD/sysmirror-result-"*; return 0; fi
            if (( cancelled )); then SYS_MIRROR_STATES[i]=STOPPED; break; fi
            local rf="$TMPD/sysmirror-result-$i"
            if [[ -f $rf ]]; then
                IFS='|' read -r SYS_MIRROR_STATES[i] SYS_MIRROR_CODES[i] SYS_MIRROR_TIMES[i] < "$rf"
                rm -f "$rf"
            else SYS_MIRROR_STATES[i]=DOWN; SYS_MIRROR_CODES[i]="--"; SYS_MIRROR_TIMES[i]="--"; fi
            get_size; local vis=$(( ROWS - 9 )); (( vis < 3 )) && vis=3
            (( i >= off + vis )) && off=$(( i - vis + 1 ))
            system_mirror_render "$off" "Tested $((i+1)) of $n configured endpoint(s). (c stop, Esc back)"
        done
    fi
    (( cancelled )) || system_mirror_render "$off" "Scan complete: $n endpoint(s) checked."
    while true; do
        if ! read_key 0.4; then (( RESIZED )) && { RESIZED=0; system_mirror_render "$off" "${cancelled:+Scan stopped.} Scan complete."; }; continue; fi
        case $KEY in
            THEME_CHANGED) system_mirror_render "$off" "Scan complete." ;;
            q|Q|ESC|j|J) return 0 ;;
            c|C) return 0 ;;
            UP|k) (( off > 0 )) && off=$((off-1)); system_mirror_render "$off" "Scan complete." ;;
            DOWN) get_size; local vis=$(( ROWS - 9 )); (( vis < 3 )) && vis=3; (( off + vis < n )) && off=$((off+1)); system_mirror_render "$off" "Scan complete." ;;
            r|R) system_mirrors_screen; return 0 ;;
        esac
    done
}

# ── Settings screen ──────────────────────────────────────────────────────────
edit_text() { # prompt current -> EDITED (rc 1 = cancelled)
    local v
    get_size
    printf '\e[%d;1H\e[K\e[?25h%s' "$ROWS" "$1 "
    IFS= read -re -i "$2" v || { printf '\e[?25l'; return 1; }
    printf '\e[?25l'
    EDITED="$(trim "$v")"
}

scan_settings_changed() {
    # Stop obsolete work immediately; otherwise leaving Settings could wait for probes
    # belonging to a section that has just been disabled.
    if (( CYCLE_RUNNING )); then
        kill_children
        CYCLE_RUNNING=0; CYCLE_TIMED_OUT=0
    fi
    REFRESH_REQ=1
    NEXT_AT=0
}

settings_screen() {
    local si=0 redraw=1 dir top=0 visible=10
    local -a names=("Theme" "ASCII mode" "Refresh interval" "History window" "Probe timeout" "Degraded RTT" "GLOBAL via proxy" "Proxy URL" "DNS test host" "GLOBAL providers scan" "GLOBAL sites scan" "INSIDE providers scan" "INSIDE sites scan" "GLOBAL mirrors scan" "INSIDE mirrors scan" "Uninstall")
    while true; do
        if (( redraw )); then
            local i val shown chips total=${#names[@]}
            get_size
            visible=$(( ROWS - 13 )); (( visible < 5 )) && visible=5
            (( visible > total )) && visible=$total
            (( si < top )) && top=$si
            (( si >= top + visible )) && top=$((si - visible + 1))
            SCREEN=("${BOLD}${PINK}SETTINGS${RESET}" "${GRAY}, previous theme   . next theme (works globally); ←/→ change selected values.${RESET}" "${GRAY}Options $((top+1))-$((top+visible)) of $total${RESET}")
            for (( i = top; i < top + visible && i < ${#names[@]}; i++ )); do
                case $i in
                    0) SCREEN+=("${GRAY}$(printf '%*s' 4 '' | tr ' ' '-') APPEARANCE $(printf '%*s' 35 '' | tr ' ' '-')${RESET}") ;;
                    2) SCREEN+=("${GRAY}$(printf '%*s' 4 '' | tr ' ' '-') MONITORING $(printf '%*s' 34 '' | tr ' ' '-')${RESET}") ;;
                    6) SCREEN+=("${GRAY}$(printf '%*s' 4 '' | tr ' ' '-') ROUTING & DNS $(printf '%*s' 30 '' | tr ' ' '-')${RESET}") ;;
                    9) SCREEN+=("${GRAY}$(printf '%*s' 4 '' | tr ' ' '-') SCANNING $(printf '%*s' 36 '' | tr ' ' '-')${RESET}") ;;
                    15) SCREEN+=("${GRAY}$(printf '%*s' 4 '' | tr ' ' '-') APPLICATION $(printf '%*s' 32 '' | tr ' ' '-')${RESET}") ;;
                esac
                vcolor=$GREEN
                case $i in
                    0) chips="${PINK}${BAR_FULL}${BAR_FULL}${RESET}${ROSE}${BAR_FULL}${BAR_FULL}${RESET}${CYAN}${BAR_FULL}${BAR_FULL}${RESET}${GREEN}${BAR_FULL}${BAR_FULL}${RESET}"; val="< $(theme_name "$THEME") >  ${chips}" ;;
                    1) (( UI_ASCII )) && val="on" || val="off" ;;
                    2) val="${INTERVAL} s" ;;
                    3) val="${WINDOW} cycles" ;;
                    4) val="${PROBE_TIMEOUT} s" ;;
                    5) val="${DEGRADED_RTT} ms" ;;
                    6) (( GLOBAL_VIA_PROXY )) && val="on" || val="off" ;;
                    7) if [[ -n $PROXY_URL ]]; then resolve_proxy; val="$(pv "$PROXY_EP") (credentials hidden)"; else val="not set"; fi ;;
                    8) val="$DNS_TEST_HOST" ;;
                    9) if (( SCAN_GLOBAL_PROVIDERS )); then val="ACTIVE"; vcolor=$GREEN; else val="INACTIVE"; vcolor=$GRAY; fi ;;
                    10) if (( SCAN_GLOBAL_SITES )); then val="ACTIVE"; vcolor=$GREEN; else val="INACTIVE"; vcolor=$GRAY; fi ;;
                    11) if (( SCAN_INSIDE_PROVIDERS )); then val="ACTIVE"; vcolor=$GREEN; else val="INACTIVE"; vcolor=$GRAY; fi ;;
                    12) if (( SCAN_INSIDE_SITES )); then val="ACTIVE"; vcolor=$GREEN; else val="INACTIVE"; vcolor=$GRAY; fi ;;
                    13) if (( SCAN_GLOBAL_MIRRORS )); then val="ACTIVE"; vcolor=$GREEN; else val="INACTIVE"; vcolor=$GRAY; fi ;;
                    14) if (( SCAN_INSIDE_MIRRORS )); then val="ACTIVE"; vcolor=$GREEN; else val="INACTIVE"; vcolor=$GRAY; fi ;;
                    15) val="[ Uninstall Sakura NetScope ]" ;;
                esac
                if (( i == si )); then shown="${ROSE}${G_MARK}${RESET} ${BOLD}$(printf '%-22s' "${names[i]}")${RESET} ${vcolor}${val}${RESET}"
                else shown="  $(printf '%-22s' "${names[i]}") ${vcolor}${val}${RESET}"; fi
                SCREEN+=("$shown")
            done
            SCREEN+=("")
            SCREEN_OUTSIDE=(
                "${PINK}${APP} version ${VERSION}${RESET}"
                "${PINK}Install mode: $(install_mode_label)${RESET}"
                "${PINK}How to uninstall: ${APP} --uninstall or Settings > Uninstall${RESET}"
                "${GRAY}Recommended window size: X = 980, Y = 600${RESET}"
                "${GRAY}Theme shortcuts: , previous / . next (work on every screen)${RESET}"
                "${GRAY}Settings file: $(hp "$SETTINGS_FILE")${RESET}"
                "${GRAY}Providers: edit $(hp "$PROVIDERS_FILE") (run --write-config for a template)${RESET}"
                "${GRAY}Theme preview applies immediately; changes are saved automatically.${RESET}"
            )
            draw_screen "Settings" "Up/Down select   ,/. change theme anywhere   Left/Right other values   Enter edit/toggle   Esc back"
            redraw=0
        fi
        if ! read_key 0.4; then
            (( RESIZED )) && { RESIZED=0; redraw=1; }
            continue
        fi
        case $KEY in
            THEME_CHANGED) redraw=1 ;;
            ESC|q|Q)
                save_settings
                request_refresh
                return 0
                ;;
            UP|k) (( si > 0 )) && si=$((si - 1)); redraw=1 ;;
            DOWN|j) (( si < ${#names[@]} - 1 )) && si=$((si + 1)); redraw=1 ;;
            LEFT|RIGHT|ENTER|'+'|'-'|h|l)
                dir=1; [[ $KEY == LEFT || $KEY == '-' || $KEY == h ]] && dir=-1
                case $si in
                    0) theme_step "$dir"; init_colors; FOREST_W=-1; FOREST_CACHE_KEY=""; save_settings ;;
                    1) UI_ASCII=$(( 1 - UI_ASCII )); init_glyphs; FOREST_W=-1; FOREST_CACHE_KEY="" ;;
                    2) set_num INTERVAL $(( INTERVAL + dir )) 2 60 ;;
                    3) set_num WINDOW $(( WINDOW + 5 * dir )) 5 100; (( MIN_SAMPLES > WINDOW )) && MIN_SAMPLES=$WINDOW ;;
                    4) set_num PROBE_TIMEOUT $(( PROBE_TIMEOUT + dir )) 1 10 ;;
                    5) set_num DEGRADED_RTT $(( DEGRADED_RTT + 25 * dir )) 25 1000 ;;
                    6) GLOBAL_VIA_PROXY=$(( 1 - GLOBAL_VIA_PROXY )) ;;
                    7) if [[ $KEY == ENTER ]] && edit_text "Proxy URL (empty = none, e.g. http://127.0.0.1:2080):" "$PROXY_URL"; then
                           if [[ -z $EDITED || $EDITED =~ ^[A-Za-z0-9+.-]+://[^[:space:]]+$ || $EDITED =~ ^[A-Za-z0-9._-]+:[0-9]+$ ]]; then PROXY_URL=$EDITED
                           else STATUS_MSG="${RED}Invalid proxy URL${RESET}"; MSG_UNTIL=$((SECONDS + 4)); fi
                       fi ;;
                    8) if [[ $KEY == ENTER ]] && edit_text "DNS test host:" "$DNS_TEST_HOST"; then
                           [[ $EDITED =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] && DNS_TEST_HOST=$EDITED
                       fi ;;
                    9) SCAN_GLOBAL_PROVIDERS=$((1-SCAN_GLOBAL_PROVIDERS)); scan_settings_changed ;;
                    10) SCAN_GLOBAL_SITES=$((1-SCAN_GLOBAL_SITES)); scan_settings_changed ;;
                    11) SCAN_INSIDE_PROVIDERS=$((1-SCAN_INSIDE_PROVIDERS)); scan_settings_changed ;;
                    12) SCAN_INSIDE_SITES=$((1-SCAN_INSIDE_SITES)); scan_settings_changed ;;
                    13) SCAN_GLOBAL_MIRRORS=$((1-SCAN_GLOBAL_MIRRORS)); scan_settings_changed ;;
                    14) SCAN_INSIDE_MIRRORS=$((1-SCAN_INSIDE_MIRRORS)); scan_settings_changed ;;
                    15)
                        if [[ $KEY == ENTER ]]; then
                            tty_leave
                            if do_uninstall; then QUIT=1; return 0; fi
                            tty_enter
                            redraw=1
                        fi
                        ;;
                esac
                resolve_proxy; save_settings; redraw=1 ;;
        esac
    done
}

# ── Install / uninstall (independent of any package manager) ─────────────────
INSTALL_STATE="unknown"; INSTALL_NOTE=""

write_desktop_entry() {
    local content tmp
    content="[Desktop Entry]
Type=Application
Name=Sakura NetScope
Comment=TUI network monitor (GLOBAL / INSIDE connectivity)
Exec=\"$INSTALL_PATH\"
Icon=preferences-system-network
Terminal=true
Categories=Network;Monitor;
"
    if [[ ! -f $DESKTOP_FILE || "$(<"$DESKTOP_FILE")" != "${content%$'\n'}" ]]; then
        if [[ $INSTALL_MODE == system ]]; then
            command -v sudo >/dev/null 2>&1 || { INSTALL_NOTE="sudo is required for system-wide installation"; return 1; }
            tmp="${DESKTOP_FILE}.new.$$"
            printf '%s' "$content" | sudo tee "$tmp" >/dev/null || { INSTALL_NOTE="could not write system desktop entry"; return 1; }
            sudo chmod 644 "$tmp" && sudo mv -f -- "$tmp" "$DESKTOP_FILE" || { sudo rm -f -- "$tmp" 2>/dev/null || true; INSTALL_NOTE="could not install system desktop entry"; return 1; }
        else
            mkdir -p -- "$DESKTOP_DIR" 2>/dev/null || return 1
            tmp="${DESKTOP_FILE}.new.$$"
            printf '%s' "$content" > "$tmp" || return 1
            chmod 644 "$tmp" 2>/dev/null || true
            mv -f -- "$tmp" "$DESKTOP_FILE" || return 1
        fi
    fi
    have update-desktop-database && { if [[ $INSTALL_MODE == system ]]; then sudo update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true; else update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true; fi; }
    return 0
}

version_of_file() { sed -n 's/^VERSION="\([0-9][0-9.]*\)"$/\1/p' "$1" 2>/dev/null | head -n1; }
version_is_newer() { [[ -n $1 && -n $2 && $(printf '%s\n%s\n' "$2" "$1" | sort -V | tail -n1) == "$1" && $1 != "$2" ]]; }

ensure_installed() {
    INSTALL_STATE="ok"; INSTALL_NOTE=""
    [[ $INSTALL_MODE == demo ]] && { INSTALL_STATE=demo; return 0; }
    if [[ $SELF != "$INSTALL_PATH" ]]; then
        local should_copy=0 was_missing=0 installed_version="" tmp
        if [[ ! -e $INSTALL_PATH ]]; then should_copy=1; was_missing=1; fi
        if [[ -e $INSTALL_PATH ]]; then
            installed_version="$(version_of_file "$INSTALL_PATH")"
            # Development builds used a 1.9.x sequence. The public stable
            # release resets the displayed version to 1.0, but must replace
            # those development installs rather than being rejected as older.
            if [[ $VERSION == 1.0 && $installed_version == 1.9.* ]]; then should_copy=1
            elif version_is_newer "$VERSION" "$installed_version"; then should_copy=1
            elif version_is_newer "$installed_version" "$VERSION"; then INSTALL_STATE=older; INSTALL_NOTE="installed version $installed_version is newer than this file"; return 0
            fi
            cmp -s -- "$SELF" "$INSTALL_PATH" || [[ $should_copy == 1 ]] || should_copy=0
        fi
        if (( should_copy )); then
            if [[ $INSTALL_MODE == system ]]; then
                command -v sudo >/dev/null 2>&1 || { INSTALL_STATE=failed; INSTALL_NOTE="sudo is required to update $INSTALL_PATH"; return 1; }
                tmp="${INSTALL_PATH}.new.$$"
                sudo install -D -m 755 -- "$SELF" "$tmp" && [[ "$(version_of_file "$tmp")" == "$VERSION" ]] && sudo mv -f -- "$tmp" "$INSTALL_PATH" || { sudo rm -f -- "$tmp" 2>/dev/null || true; INSTALL_STATE=failed; INSTALL_NOTE="atomic update failed; old installation was kept"; return 1; }
            else
                mkdir -p -- "$INSTALL_DIR" 2>/dev/null || { INSTALL_STATE=failed; INSTALL_NOTE="could not create $INSTALL_DIR"; return 1; }
                tmp="${INSTALL_PATH}.new.$$"
                if ! cp -f -- "$SELF" "$tmp" || ! chmod +x "$tmp" || [[ "$(version_of_file "$tmp")" != "$VERSION" ]] || ! mv -f -- "$tmp" "$INSTALL_PATH"; then rm -f -- "$tmp"; INSTALL_STATE=failed; INSTALL_NOTE="atomic update failed; old installation was kept"; return 1; fi
            fi
            if (( was_missing )); then INSTALL_STATE=new; else INSTALL_STATE=updated; fi
        fi
    fi
    # Keep the command available through the existing ~/.local/bin PATH entry,
    # while the real application file lives inside the SakuraSuit directory.
    if [[ $INSTALL_MODE == local && -x $INSTALL_PATH ]]; then
        mkdir -p -- "$HOME/.local/bin" 2>/dev/null || true
        if [[ -d "$HOME/.local/bin/$APP" && ! -L "$HOME/.local/bin/$APP" ]]; then
            INSTALL_NOTE="legacy command path is a directory; could not create launcher link"
        else
            ln -sfn -- "$INSTALL_PATH" "$HOME/.local/bin/$APP" 2>/dev/null || true
        fi
    fi
    write_desktop_entry || { [[ -n $INSTALL_NOTE ]] || INSTALL_NOTE="menu entry could not be written"; }
    return 0
}

ask_yes_no() { # prompt default -> REPLY y|n
    local prompt=$1 default=${2:-n} a
    if [[ $default == y ]]; then printf '%s [Y/n]: ' "$prompt"; else printf '%s [y/N]: ' "$prompt"; fi
    read -r a || a=""
    a="${a,,}"
    if [[ -z $a ]]; then REPLY=$default; elif [[ $a == y || $a == yes ]]; then REPLY=y; else REPLY=n; fi
}

# Terminal-only flow:  sakura-netscope --uninstall   rc 0 = removed.
do_uninstall() {
    local f found=0 src bk stamp rmconf
    local -a targets=("$INSTALL_PATH" "$DESKTOP_FILE")
    [[ $INSTALL_MODE != system && -e $LEGACY_LOCAL_PATH ]] && targets+=("$LEGACY_LOCAL_PATH")
    print_tree
    printf '%sSakura NetScope uninstall%s\n' "$PINK" "$RESET"
    for f in "${targets[@]}"; do
        if [[ -e $f || -L $f ]]; then printf '  %s•%s %s\n' "$CYAN" "$RESET" "$f"; found=1; fi
    done
    [[ -d $CONF_DIR ]] && { printf '  %s•%s %s (optional user settings/data)\n' "$CYAN" "$RESET" "$CONF_DIR"; found=1; }
    if (( ! found )); then printf '%sNothing to remove — not installed.%s\n' "$YELLOW" "$RESET"; return 1; fi
    printf '\n'
    ask_yes_no "Do you want to uninstall Sakura NetScope?" n
    [[ $REPLY == y ]] || { printf '%sCancelled. Nothing was removed.%s\n' "$YELLOW" "$RESET"; return 1; }
    if [[ -e $INSTALL_PATH ]]; then
        ask_yes_no "Do you want to keep a copy of the script?" y
        if [[ $REPLY == y ]]; then
            src=$INSTALL_PATH
            printf -v stamp '%(%Y%m%d-%H%M%S)T' -1
            bk="$BACKUP_DIR/$APP-backup-$stamp.sh"
            if ! mkdir -p -- "$BACKUP_DIR" 2>/dev/null || ! cp -- "$src" "$bk" 2>/dev/null || ! chmod +x "$bk" 2>/dev/null; then
                printf '%sCould not save a copy to %s — nothing was removed.%s\n' "$YELLOW" "$BACKUP_DIR" "$RESET"
                return 1
            fi
            printf '%s%s Script copy saved:%s %s\n' "$GREEN" "$G_OK" "$RESET" "$bk"
        fi
    fi
    ask_yes_no "Also remove settings and providers (${CONF_DIR})?" n
    rmconf=$REPLY
    if [[ $INSTALL_MODE == system ]]; then
        if ! command -v sudo >/dev/null 2>&1; then printf '%sCannot remove system files: sudo is unavailable.%s\n' "$RED" "$RESET"; return 1; fi
        sudo rm -f -- "${targets[@]}" || { printf '%sCould not remove all system files.%s\n' "$RED" "$RESET"; return 1; }
        sudo update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
    else
        rm -f -- "${targets[@]}" || { printf '%sCould not remove all local files.%s\n' "$RED" "$RESET"; return 1; }
        have update-desktop-database && update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
    fi
    if [[ $rmconf == y ]]; then rm -rf -- "$CONF_DIR"; else rm -f -- "$INSTALL_CONF"; fi
    printf '%s%s Sakura NetScope was uninstalled (command and menu entry removed).%s\n' "$GREEN" "$G_BLOSSOM" "$RESET"
    return 0
}

# ── Main loop ────────────────────────────────────────────────────────────────
QUIT=0

adjust_interval() { # delta
    local n=$(( INTERVAL + $1 ))
    if set_num INTERVAL "$n" 2 60; then
        save_settings
        STATUS_MSG="${CYAN}Refresh interval: ${INTERVAL}s${RESET}"; MSG_UNTIL=$((SECONDS + 3))
    fi
}

move_sel() { # delta; one selector traverses GLOBAL then INSIDE
    local n list s
    [[ $FOCUS == 0 ]] && list=$LIST0 || list=$LIST1
    n=$(wc -w <<< "$list")
    s=$(( SEL[FOCUS] + $1 ))
    if (( s < 0 )); then
        if (( FOCUS == 1 )); then FOCUS=0; n=$(wc -w <<< "$LIST0"); s=$(( n - 1 )); else s=0; fi
    elif (( s >= n )); then
        if (( FOCUS == 0 )); then FOCUS=1; s=0; else s=$(( n - 1 )); fi
    fi
    SEL[FOCUS]=$s
}

# ── Speed test ───────────────────────────────────────────────────────────────
# Runs twice: once against the Iranian national network (INSIDE), once against
# the international internet (GLOBAL). Each run = latency, download, upload.
# The final numbers come from curl's own counters; the live number and the
# sparkline come from the interface byte counters in /proc/net/dev.
SPEED_SECONDS=${NETSCOPE_SPEED_SECONDS:-8}   # length of one download / upload phase
SPEED_UP_BYTES=30000000    # size of the upload payload (zeros, created in the temp dir)
SPEED_CONF="$CONF_DIR/speedtest.conf"

ST_DEF_IN_DOWN=(
    "https://mirror.arvancloud.ir/ubuntu/ls-lR.gz"
    "https://mirrors.pardisco.co/ubuntu/ls-lR.gz"
    "https://mirror.iranserver.com/ubuntu/ls-lR.gz"
    "https://mirror.aminidc.com/ubuntu/ls-lR.gz"
    "https://repo.iut.ac.ir/"
    "https://mirror.shatel.ir/"
)
ST_DEF_IN_UP=(
    "https://mirror.arvancloud.ir/"
    "https://mirrors.pardisco.co/"
    "https://mirror.iranserver.com/"
    "https://speed.cloudflare.com/__up"
)
ST_DEF_GL_DOWN=(
    "https://speed.cloudflare.com/__down?bytes=200000000"
    "https://proof.ovh.net/files/100Mb.dat"
    "https://speedtest.tele2.net/100MB.zip"
    "https://download.thinkbroadband.com/100MB.zip"
    "https://speedtest.ftp.otenet.gr/files/test100Mb.db"
)
ST_DEF_GL_UP=(
    "https://speed.cloudflare.com/__up"
    "https://speedtest.tele2.net/upload.php"
    "https://speedtest.ftp.otenet.gr/upload.php"
)
ST_C0=(); ST_C1=(); ST_C2=(); ST_C3=(); ST_L=()
ST_UI=1; ST_ABORT=0; ST_FRAME=0; ST_CUR=-1
ST_PH=(wait wait wait wait)          # per row: wait | run | done | fail | skip
ST_VAL=("-" "-" "-" "-")              # per row: result text
ST_MBPS=(0 0 0 0)                     # per row: Mbps x100 (0 = none)
ST_APPROX=(0 0 0 0)
ST_SRV=("" "" "" "")                  # per row: server host
ST_LATTXT=("-" "-"); ST_LATMS=(0 0)
ST_PROG=0; ST_LIVEK=0; ST_SPARK=(); ST_WHY=""; ST_LIVE_OK=0
ST_TITLE=("INSIDE" "GLOBAL")
ST_SUB=("national internet (Iranian servers)" "international internet")

st_load_conf() {
    ST_C0=("${ST_DEF_IN_DOWN[@]}"); ST_C1=("${ST_DEF_IN_UP[@]}")
    ST_C2=("${ST_DEF_GL_DOWN[@]}"); ST_C3=("${ST_DEF_GL_UP[@]}")
    [[ -f $SPEED_CONF ]] || return 0
    local line k v
    local -a n0=() n1=() n2=() n3=()
    while IFS= read -r line || [[ -n $line ]]; do
        line="$(trim "${line%$'\r'}")"
        [[ -z $line || $line == \#* || $line != *=* ]] && continue
        k="$(trim "${line%%=*}")"; v="$(trim "${line#*=}")"
        [[ $v =~ ^https?://[^[:space:]]+$ ]] || continue
        case $k in
            inside-down) n0+=("$v") ;;
            inside-up)   n1+=("$v") ;;
            global-down) n2+=("$v") ;;
            global-up)   n3+=("$v") ;;
        esac
    done < "$SPEED_CONF"
    (( ${#n0[@]} )) && ST_C0=("${n0[@]}")
    (( ${#n1[@]} )) && ST_C1=("${n1[@]}")
    (( ${#n2[@]} )) && ST_C2=("${n2[@]}")
    (( ${#n3[@]} )) && ST_C3=("${n3[@]}")
    return 0
}

write_speedtest_template() {
    if [[ -f $SPEED_CONF ]]; then printf 'Already exists: %s\n' "$SPEED_CONF"; return 0; fi
    mkdir -p -- "$CONF_DIR" || return 1
    {
        printf '# Sakura NetScope speed-test servers (tried in order, first one that works is used)\n'
        printf '# keys: inside-down  inside-up  global-down  global-up\n'
        printf '# Built-in lists now include multiple fallback endpoints per test type.\n'
        printf '# A key that appears here replaces the built-in list for that key.\n'
        printf '# download URLs must be big static files (or a size-on-demand endpoint);\n'
        printf '# upload URLs must accept a large POST body.\n\n'
        local u
        for u in "${ST_DEF_IN_DOWN[@]}"; do printf 'inside-down=%s\n' "$u"; done
        for u in "${ST_DEF_IN_UP[@]}";   do printf 'inside-up=%s\n' "$u"; done
        for u in "${ST_DEF_GL_DOWN[@]}"; do printf 'global-down=%s\n' "$u"; done
        for u in "${ST_DEF_GL_UP[@]}";   do printf 'global-up=%s\n' "$u"; done
    } > "$SPEED_CONF"
    printf 'Wrote %s\n' "$SPEED_CONF"
}

st_list() { # stage kind(0 down, 1 up) -> ST_L
    case $(( $1 * 2 + $2 )) in
        0) ST_L=("${ST_C0[@]}") ;; 1) ST_L=("${ST_C1[@]}") ;;
        2) ST_L=("${ST_C2[@]}") ;; *) ST_L=("${ST_C3[@]}") ;;
    esac
}

st_host() { local h=${1#*://}; h=${h%%/*}; printf '%s' "$h"; }

# curl arguments: INSIDE never uses the proxy; GLOBAL uses it only when the
# "GLOBAL via proxy" setting is on and a proxy is configured.
st_curl_args() { # stage -> ST_ARGS
    ST_ARGS=(-sS -L --connect-timeout 5 -o /dev/null)
    if [[ $1 == 1 && $GLOBAL_VIA_PROXY == 1 && -n $EFF_PROXY ]]; then ST_ARGS+=(--proxy "$EFF_PROXY")
    else ST_ARGS+=(--noproxy '*'); fi
}

# bytes received / sent by the physical network interfaces (result ST_NB, -1 = unknown).
# Loopback and virtual devices (tun, wg, docker, veth, bridges) are skipped so that
# traffic is not counted twice when a tunnel is active.
NET_DEV=/proc/net/dev
st_net_bytes() { # rx|tx
    local dir=$1 line name sum=0 found=0
    local -a f
    [[ -r $NET_DEV ]] || { ST_NB=-1; return; }
    while IFS= read -r line; do
        [[ $line == *:* ]] || continue
        name=${line%%:*}; name=${name//[[:space:]]/}
        case $name in lo|tun*|tap*|wg*|docker*|veth*|br-*|virbr*|sing*|utun*|vmnet*|vboxnet*) continue ;; esac
        read -ra f <<< "${line#*:}"
        found=1
        if [[ $dir == rx ]]; then sum=$(( sum + ${f[0]:-0} )); else sum=$(( sum + ${f[8]:-0} )); fi
    done < "$NET_DEV"
    (( found )) && ST_NB=$sum || ST_NB=-1
}

st_ms() { # "1.234567" -> ST_MSV (integer milliseconds)
    local t=$1 int frac
    if [[ $t =~ ^([0-9]+)\.([0-9]+)$ ]]; then
        int=${BASH_REMATCH[1]}; frac="${BASH_REMATCH[2]}000"
        ST_MSV=$(( 10#$int * 1000 + 10#${frac:0:3} ))
    elif [[ $t =~ ^[0-9]+$ ]]; then ST_MSV=$(( 10#$t * 1000 ))
    else ST_MSV=0; fi
}

st_fmt() { # Mbps x100 -> ST_TXT  e.g. "87.40 Mbps (10.9 MB/s)"
    local n=$1 mb=$(( $1 / 8 ))
    printf -v ST_TXT '%d.%02d Mbps (%d.%d MB/s)' $(( n / 100 )) $(( n % 100 )) $(( mb / 100 )) $(( (mb % 100) / 10 ))
}

# latency = TCP connect time, 4 tries; sets ST_LAT_MS ST_JIT_MS (rc 1 = unreachable)
st_latency() { # stage url
    local i out ms prev=-1 sum=0 n=0 jit=0 jn=0
    st_curl_args "$1"
    for i in 1 2 3 4; do
        out="$(LC_ALL=C "$CURL_BIN" "${ST_ARGS[@]}" -I --max-time 3 -w '%{time_connect}' "$2" 2>/dev/null)" || continue
        out=${out##*$'\n'}
        st_ms "$out"; ms=$ST_MSV
        (( ms < 1 )) && ms=1
        sum=$(( sum + ms )); n=$(( n + 1 ))
        if (( prev >= 0 )); then jit=$(( jit + (ms > prev ? ms - prev : prev - ms) )); jn=$(( jn + 1 )); fi
        prev=$ms
    done
    (( n > 0 )) || return 1
    ST_LAT_MS=$(( sum / n )); ST_JIT_MS=0
    (( jn > 0 )) && ST_JIT_MS=$(( jit / jn ))
    return 0
}

# one transfer. rc 0 ok (ST_RES = Mbps x100), 1 failed (ST_WHY), 2 aborted by the user
st_phase() { # down|up stage url row
    local kind=$1 stage=$2 url=$3 row=$4 wf="$TMPD/st_w" cpid dir=rx
    local t0 last_t last_b b dt inst el crc line code bytes total start xfer
    rm -f "$wf" "$TMPD/st_err"
    st_curl_args "$stage"
    if [[ $kind == down ]]; then
        "$CURL_BIN" "${ST_ARGS[@]}" --max-time "$SPEED_SECONDS" \
            -w '%{http_code} %{size_download} %{time_total} %{time_starttransfer}' "$url" > "$wf" 2> "$TMPD/st_err" &
    else
        dir=tx
        "$CURL_BIN" "${ST_ARGS[@]}" --max-time "$SPEED_SECONDS" -X POST --data-binary "@$TMPD/st_up.bin" \
            -H 'Content-Type: application/octet-stream' \
            -w '%{http_code} %{size_upload} %{time_total} %{time_pretransfer}' "$url" > "$wf" 2> "$TMPD/st_err" &
    fi
    cpid=$!
    now_ms; t0=$NOW_MS; last_t=$t0
    st_net_bytes "$dir"; last_b=$ST_NB
    ST_SPARK=(); ST_LIVEK=0; ST_PROG=0; ST_LIVE_OK=$(( last_b >= 0 ))
    while kill -0 "$cpid" 2>/dev/null; do
        if (( ST_UI )); then
            if read_key 0.1; then
                case $KEY in q|Q|ESC) kill "$cpid" 2>/dev/null; wait "$cpid" 2>/dev/null; return 2 ;; esac
            fi
        else
            read -rt 0.1 _ <> <(:) || :
        fi
        now_ms; el=$(( NOW_MS - t0 ))
        ST_PROG=$(( el * 100 / (SPEED_SECONDS * 1000) )); (( ST_PROG > 100 )) && ST_PROG=100
        st_net_bytes "$dir"; b=$ST_NB; dt=$(( NOW_MS - last_t ))
        if (( dt >= 150 )); then
            if (( last_b >= 0 && b >= last_b )); then
                inst=$(( (b - last_b) * 8 / dt ))          # kbit/s
                if (( ST_LIVEK == 0 )); then ST_LIVEK=$inst; else ST_LIVEK=$(( (ST_LIVEK * 6 + inst * 4) / 10 )); fi
                ST_SPARK+=("$ST_LIVEK")
                (( ${#ST_SPARK[@]} > 120 )) && ST_SPARK=("${ST_SPARK[@]: -120}")
            fi
            last_t=$NOW_MS; last_b=$b
        fi
        (( ST_UI )) && st_draw
    done
    wait "$cpid"; crc=$?
    ST_PROG=100
    line=""; [[ -f $wf ]] && read -r line < "$wf"
    read -r code bytes total start <<< "$line"
    code=${code:-000}; bytes=${bytes:-0}
    if ! [[ $bytes =~ ^[0-9]+$ ]]; then bytes=0; fi
    if [[ $kind == down ]]; then
        if (( bytes < 65536 )); then ST_WHY="no data (HTTP $code, curl exit $crc)"; return 1; fi
        if [[ $code != 2* ]]; then ST_WHY="HTTP $code"; return 1; fi
    else
        if (( bytes < 262144 )); then ST_WHY="server did not accept the upload (HTTP $code, ${bytes} bytes sent)"; return 1; fi
        ST_APPROX[row]=0; [[ $code != 2* ]] && ST_APPROX[row]=1
    fi
    st_ms "$total"; total=$ST_MSV; st_ms "$start"; start=$ST_MSV
    xfer=$(( total - start )); (( xfer < 300 )) && xfer=$total
    (( xfer > 0 )) || { ST_WHY="no timing data"; return 1; }
    ST_RES=$(( bytes * 8 / (xfer * 10) ))                 # Mbps x 100
    return 0
}

# ── Speed test screen ─────────────────────────────────────────────────────────
st_petals() { # inner width -> ST_PET (a row of drifting petals)
    local pw=$1 i x s=""
    local -a cells=()
    for (( i = 0; i < pw; i++ )); do cells[i]=' '; done
    for (( i = 0; i <= pw / 7; i++ )); do
        x=$(( (i * 7 + ST_FRAME) % pw ))
        if (( i % 3 == 0 )); then cells[x]="${PINK}${G_BLOSSOM}${RESET}"
        elif (( i % 3 == 1 )); then cells[x]="${ROSE}${G_DOT}${RESET}"
        else cells[x]="${PINK}.${RESET}"; fi
    done
    for (( i = 0; i < pw; i++ )); do s+=${cells[i]}; done
    ST_PET=$s
}

st_spark() { # width -> ST_SP  (sparkline of the live speed of the running phase)
    local w=$1 i v max=1 lv n=${#ST_SPARK[@]} s="" start
    local -a lev
    if (( UI_ASCII )); then lev=('.' '_' '-' '=' '+' '*' '#' '@'); else lev=('▁' '▂' '▃' '▄' '▅' '▆' '▇' '█'); fi
    start=$(( n > w ? n - w : 0 ))
    for (( i = start; i < n; i++ )); do (( ST_SPARK[i] > max )) && max=${ST_SPARK[i]}; done
    for (( i = start; i < n; i++ )); do
        lv=$(( ST_SPARK[i] * 7 / max )); s+=${lev[lv]}
    done
    ST_SP="${ROSE}${s}${RESET}"
}

st_bar_row() { # label row bw
    local label=$1 row=$2 bw=$3 st=${ST_PH[$2]} f i bar="" col val
    case $st in
        run)  f=$(( ST_PROG * bw / 100 )); (( f < 1 )) && f=1; (( f > bw )) && f=$bw
              for (( i = 0; i < bw; i++ )); do
                  if (( i < f - 1 )); then bar+="${PINK}${BAR_FULL}"
                  elif (( i == f - 1 )); then bar+="${ROSE}${G_BLOSSOM}"
                  else bar+="${GRAY}${BAR_EMPTY}"; fi
              done
              if (( ST_LIVE_OK )); then printf -v val '%d.%02d Mbps' $(( ST_LIVEK / 1000 )) $(( (ST_LIVEK % 1000) / 10 ))
              else val="measuring..."; fi
              val="${ROSE}${val}${RESET}" ;;
        done) for (( i = 0; i < bw; i++ )); do bar+="${GREEN}${BAR_FULL}"; done
              val="${GREEN}${ST_VAL[$row]}${RESET}"; (( ST_APPROX[row] )) && val+=" ${GRAY}(approx.)${RESET}" ;;
        fail) for (( i = 0; i < bw; i++ )); do bar+="${RED}${BAR_EMPTY}"; done
              val="${RED}failed${RESET}" ;;
        skip) for (( i = 0; i < bw; i++ )); do bar+="${GRAY}${BAR_EMPTY}"; done
              val="${GRAY}skipped${RESET}" ;;
        *)    for (( i = 0; i < bw; i++ )); do bar+="${GRAY}${BAR_EMPTY}"; done
              val="${GRAY}waiting${RESET}" ;;
    esac
    ST_ROW="${CYAN}${label}${RESET} ${bar}${RESET}  ${val}"
}

st_draw() {
    local w s r bw pw foot
    # Keep the speed-test panel compact even on fullscreen terminals so draw_screen
    # treats it like Provider details and centers it instead of expanding it to full width.
    w=$COLS; (( w > 90 )) && w=90; (( w < 40 )) && w=40
    bw=$(( w - 4 - 9 - 1 - 2 - 30 )); (( bw > 56 )) && bw=56; (( bw < 8 )) && bw=8
    pw=$(( w - 4 ))
    ST_FRAME=$(( ST_FRAME + 1 ))
    st_petals "$pw"
    SCREEN=("$ST_PET")
    for s in 0 1; do
        r=$(( s * 2 ))
        SCREEN+=("")
        SCREEN+=("${BOLD}${PINK}${ST_TITLE[s]}${RESET}  ${GRAY}${ST_SUB[s]}${RESET}")
        SCREEN+=("${CYAN}Server   ${RESET} ${ST_SRV[r]:--}")
        SCREEN+=("${CYAN}Latency  ${RESET} ${ST_LATTXT[s]}")
        st_bar_row "Download" "$r" "$bw"; SCREEN+=("$ST_ROW")
        st_bar_row "Upload  " "$(( r + 1 ))" "$bw"; SCREEN+=("$ST_ROW")
        if [[ $ST_CUR == "$r" || $ST_CUR == "$(( r + 1 ))" ]]; then
            st_spark "$bw"; SCREEN+=("${CYAN}Live     ${RESET} ${ST_SP}")
        else
            SCREEN+=("${CYAN}Live     ${RESET} ${GRAY}-${RESET}")
        fi
    done
    if [[ $ST_CUR == done ]]; then
        SCREEN+=("")
        SCREEN+=("${BOLD}${PINK}RESULT${RESET}")
        for s in 0 1; do
            r=$(( s * 2 ))
            SCREEN+=("$(printf '%s%-7s%s Download %s   Upload %s   Latency %s' "$CYAN" "${ST_TITLE[s]}" "$RESET" "${ST_VAL[r]}" "${ST_VAL[r+1]}" "${ST_LATMS[s]} ms")")
        done
        foot="r: run again   ,/. change theme   any other key: back"
    else
        foot="q / Esc: cancel   ,/. change theme"
    fi
    [[ -n $ST_WHY && $ST_CUR != done ]] && SCREEN+=("" "${YELLOW}${ST_WHY}${RESET}")
    draw_screen "Speed test" "$foot"
}

st_run_all() {
    local s k row url rc ok
    ST_PH=(wait wait wait wait); ST_VAL=("-" "-" "-" "-"); ST_APPROX=(0 0 0 0)
    ST_SRV=("" "" "" ""); ST_LATTXT=("-" "-"); ST_LATMS=(0 0); ST_ABORT=0; ST_WHY=""; ST_CUR=-1
    st_load_conf
    head -c "$SPEED_UP_BYTES" /dev/zero > "$TMPD/st_up.bin" 2>/dev/null
    for s in 0 1; do
        for k in 0 1; do
            row=$(( s * 2 + k )); ST_CUR=$row; ST_PH[row]=run; ST_WHY=""
            st_list "$s" "$k"; ok=0
            for url in "${ST_L[@]}"; do
                ST_SRV[row]="$(st_host "$url")"
                if [[ $k == 0 ]]; then
                    ST_LATTXT[s]="measuring..."; ST_SPARK=(); ST_PROG=0; (( ST_UI )) && st_draw
                    if ! st_latency "$s" "$url"; then ST_WHY="${ST_SRV[row]}: no connection, trying the next server"; continue; fi
                    ST_LATMS[s]=$ST_LAT_MS
                    ST_LATTXT[s]="${ST_LAT_MS} ms   (jitter ${ST_JIT_MS} ms)"
                fi
                st_phase "$([[ $k == 0 ]] && echo down || echo up)" "$s" "$url" "$row"; rc=$?
                if (( rc == 2 )); then ST_ABORT=1; break 3; fi
                if (( rc == 0 )); then ok=1; break; fi
                ST_WHY="${ST_SRV[row]}: ${ST_WHY}; trying the next server"
            done
            if (( ok )); then ST_PH[row]=done; ST_MBPS[row]=$ST_RES; st_fmt "$ST_RES"; ST_VAL[row]=$ST_TXT; ST_WHY=""
            else ST_PH[row]=fail; ST_VAL[row]="failed"; ST_SRV[row]="${ST_SRV[row]:-none}"; fi
            ST_SPARK=()
        done
    done
    for row in 0 1 2 3; do [[ ${ST_PH[row]} == wait || ${ST_PH[row]} == run ]] && ST_PH[row]=skip; done
    ST_CUR=done
    rm -f "$TMPD/st_up.bin" "$TMPD/st_w" "$TMPD/st_err"
}

speedtest_screen() {
    local rc
    if [[ -z $CURL_BIN ]]; then
        STATUS_MSG="${YELLOW}speed test needs curl (see g: diagnostics)${RESET}"; MSG_UNTIL=$((SECONDS + 5)); return 0
    fi
    kill_children; CYCLE_RUNNING=0              # keep the probes from disturbing the measurement
    ST_UI=1
    while true; do
        st_run_all
        st_draw
        ST_UI=1
        while true; do
            read_key 0.5; rc=$?
            if (( rc == 0 )); then
                if [[ $KEY == THEME_CHANGED ]]; then st_draw; continue; fi
                break
            fi
            (( rc == 2 )) && break 2
            (( RESIZED )) && { RESIZED=0; st_draw; }
        done
        [[ $KEY == r || $KEY == R ]] || break
    done
    NEXT_AT=0; NEED=1
}

run_speedtest_cli() { # --speedtest (no animation)
    local s k row
    if [[ -z $CURL_BIN ]]; then echo "speed test needs curl" >&2; return 1; fi
    ST_UI=0
    st_run_all
    for s in 0 1; do
        for k in 0 1; do
            row=$(( s * 2 + k ))
            printf '%-7s %-9s %-24s %s%s\n' "${ST_TITLE[s]}" "$([[ $k == 0 ]] && echo Download || echo Upload)" \
                "${ST_SRV[row]:--}" "${ST_VAL[row]}" "$( (( ST_APPROX[row] )) && echo ' (approx.)')"
        done
        printf '%-7s %-9s %s\n' "${ST_TITLE[s]}" Latency "${ST_LATTXT[s]}"
    done
}

# ── Glossary (key k) ─────────────────────────────────────────────────────────
# "#Heading" or "Term|Explanation". Keep '|' out of the explanations.
GLOSS=(
"#READING THE SCREEN"
"Internet|Overall connection state. CONNECTED: a GLOBAL target answers. LOCAL ONLY: only INSIDE targets answer. DISCONNECTED: nothing answers or there is no default route. UNKNOWN: not enough results yet."
"Network|How this computer is connected: Wi-Fi, Ethernet, mobile modem and so on."
"SSID|The name of the Wi-Fi network you are on."
"Interface|The name Linux gives to the network card, for example wlan0, wlp3s0 or enp2s0."
"Local IP|The address of this computer inside your home or office network, usually 192.168.x.x or 10.x.x.x. It is private and is NOT the address websites see."
"Gateway|Usually your router. A reply time shows how long it took to answer ping. No ICMP reply can simply mean ping is blocked."
"Proxy|A middle server your traffic can go through. reachable means NetScope could open a connection to it. UNREACHABLE means it could not."
"Endpoint|The address of the proxy as host:port, for example 127.0.0.1:2080. A port on 127.0.0.1 means the proxy runs on this same computer."
"Tunnel|A virtual network card (a VPN or TUN device) that can carry your traffic. ACTIVE (default route): most traffic goes through it. UP (not default route): it exists but is not the main path. NONE: no tunnel found."
"Tunnel IF|The name of that virtual card, for example tun0, wg0 or sing-tun."
"DNS|Turns a name like google.com into an IP address. If it fails, websites may not open even when the connection works."
"Refresh|How often a new measurement round starts, and whether probes go direct or via the proxy."
"Monitor|ACTIVE: measuring. PAUSED: stopped by p. STARTING: waiting for results. Cycle N counts finished rounds."
"Refresh (r)|Starts a fresh measurement round."
"Pause/resume (p)|Temporarily stops or restarts automatic measurements."
"Settings (s)|Change appearance, monitoring, proxy, DNS and scan options."
"Diagnostics (g)|Shows system and network details that help troubleshoot problems."
"Test mirrors (j)|Checks whether Linux package mirrors respond."
"Speed test (t)|Measures download and upload speed against test servers."
"#THE PANELS (GLOBAL / INSIDE)"
"GLOBAL|Targets on the international internet."
"INSIDE|Targets on Iran's national (domestic) network. If INSIDE works and GLOBAL does not, you have national internet only."
"PROVIDERS|Companies that carry or host traffic: mobile operators, backbones, clouds, DNS services. Listed from most important and largest to smaller ones."
"SITES|Well-known websites. They tell you whether real services open, not only whether a network is alive."
"Status|CONNECTED: at least 60% of targets answer. DEGRADED: fewer answer. DISCONNECTED: none answer. UNKNOWN: still collecting results."
"Quality|A grade from EXCELLENT to AWFUL based on how many targets answer and their average ping."
"Reachable|X/Y: X targets answered in the latest round, out of Y targets that have finished warming up."
"Reachability|The percentage of recent checks that succeeded."
"Mean ping|The average ping time. A few slow replies can raise it."
"Median|The middle ping value; less affected by unusually high or low results."
"Loss|The percentage of ICMP pings that got no reply. Only ICMP is counted, so a server that ignores ping does not add to it."
"UP|A target that answered at least 80 percent of recent rounds and is not too slow."
"DEGRADED|A target that fails sometimes or answers slower than the slow-ping limit (setting degraded_rtt)."
"DOWN|A target that is not answering."
"WARMING UP|Fewer than min_samples rounds have run so far, so no verdict yet."
"PENDING|No result at all yet for this target."
"RTT|Round-trip time of the latest ping, in milliseconds."
"Bar and percent|The bar fills with the reachability percentage. The bar colour follows the state."
"#TECHNICAL TERMS"
"Ping|Sending a tiny message to a server and timing how long the answer takes. Shown in milliseconds (ms). Lower is better: under 40 ms feels instant, over 300 ms feels slow."
"Latency|The delay of the connection, usually measured as ping. It matters for calls, games and loading pages. It is a different thing from speed."
"Jitter|How much latency changes from one measurement to the next. High jitter makes calls and games stutter even when the average ping looks fine."
"Packet loss|The share of sent messages that get no reply. Even a small amount can affect calls and downloads."
"Reachable / reachability|Reachable means a target answers at all. It says nothing about how fast it is."
"ICMP|The protocol behind ping. Some servers and firewalls ignore it, which is why NetScope also uses HTTPS and DNS checks."
"HTTPS check|Tries to open a site securely. Any HTTP response, even 403 or 404, proves the server replied."
"DNS check|Asks that server to resolve a name. Used for DNS servers such as 8.8.8.8 or 1.1.1.1."
"via (i h d)|Which checks worked on the last round: i = ICMP, h = HTTPS, d = DNS."
"Host|The address a target is reached at: a domain name or an IP."
"Probe|One check of one target. A cycle checks every target once."
"Window|How many recent cycles are used for results."
"Provider / ISP / operator|A company that sells you internet or carries traffic, for example Irancell, Hamrah Aval (MCI), Rightel, Asiatech, Shatel or the Telecommunication Company of Iran (TCI, Mokhaberat)."
"Backbone / transit / tier-1|The big long-distance networks that connect countries and ISPs to each other, such as Lumen (Level3), NTT and Cogent. Reaching them shows your path out of the country is alive."
"Cloud provider|Companies that rent servers, for example AWS, Azure, Alibaba Cloud, DigitalOcean or ArvanCloud. Many websites live there."
"CDN|A content delivery network keeps copies of sites close to users to make them fast. Cloudflare, Akamai and ArvanCloud are CDNs."
"DNS resolver|A server that turns names into IP addresses, such as 8.8.8.8 (Google) or 1.1.1.1 (Cloudflare)."
"Anycast|One address served from many places at once, so you reach the nearest copy. Public DNS servers use it."
"National internet|Iran's domestic network of Iranian sites and services. It can keep working when international links are cut or filtered."
"Proxy (HTTP or SOCKS)|A relay for your traffic. NetScope reads its probe proxy from NETSCOPE_PROXY, Settings or ALL_PROXY / HTTPS_PROXY environment variables. It reports GNOME/KDE desktop proxy settings separately, but does not automatically route probes through the desktop setting."
"System proxy vs TUN|System proxy mode tells applications to use a local proxy port. TUN mode creates a virtual network card that captures everything, so no per-app setting is needed. NetScope shows TUN as Tunnel."
"GLOBAL via proxy|When on, GLOBAL checks and speed tests use the proxy. When off, they connect directly."
"#LINUX MIRRORS"
"Mirror|A server that holds a copy of a distribution's software packages. apt (Debian, Ubuntu), dnf (Fedora) and pacman (Arch) download from mirrors."
"Flatpak / Flathub|Flathub (dl.flathub.org) is the main store for Flatpak apps. If it is DOWN, flatpak install cannot download."
"Snap Store|The service snap talks to (api.snapcraft.io) to find and download snaps."
"Why test them|A mirror that answers fast means package installs and updates will work. UP only proves it is reachable, so run the speed test for real throughput."
"Iranian mirrors|Mirrors hosted inside Iran. They keep working on the national network and are often the quickest way to install packages."
"#SPEED TEST (key t)"
"Download|How fast data comes to you. Used for browsing, video and file downloads."
"Upload|How fast data leaves you. Used for sending files, video calls and backups."
"Mbps vs MB/s|Mbps is megabits per second, the unit ISPs use. MB/s is megabytes per second, the unit download managers use. 8 Mbps equals 1 MB/s."
"INSIDE test|Runs against Iranian servers, so it shows the speed of the national network."
"GLOBAL test|Runs against international servers, so it shows the speed to the outside world. With GLOBAL via proxy on, it measures your proxy path."
"Server|The host that was used. If the first server fails, the next one in the list is tried."
"approx.|The upload server was not built for speed tests. The number is a fair estimate, not exact."
"Accuracy|Results change with time of day, Wi-Fi quality, other devices and the server. Repeat the test before trusting one number. The test uses real data, up to about 8 seconds of full speed per phase."
"Custom servers|Run sakura-netscope --write-config to create speedtest.conf and put your own download and upload URLs there."
"#PRIVACY MODE (key x)"
"Privacy mode|Hides network details and shows sakura artwork so screenshots reveal less. Press x again to show details."
)

gloss_wrap() { # width text indent -> appends to SCREEN
    local width=$1 text=$2 ind=$3 line="" word
    set -f
    for word in $text; do
        if [[ -n $line ]] && (( ${#line} + ${#word} + 1 > width )); then
            SCREEN+=("${ind}${line}"); line=$word
        else line="${line:+$line }$word"; fi
    done
    [[ -n $line ]] && SCREEN+=("${ind}${line}")
    set +f
}

gloss_build() { # inner width
    local width=$1 e t d sep="" j sepw
    SCREEN=()
    sepw=$(( width < 34 ? width : 34 )); (( sepw < 12 )) && sepw=12
    for (( j=0; j<sepw; j++ )); do sep+="$B_H"; done
    for e in "${GLOSS[@]}"; do
        if [[ $e == \#* ]]; then
            if (( ${#SCREEN[@]} )); then SCREEN+=("" ""); fi
            SCREEN+=("${BOLD}${PINK}${e#\#}${RESET}")
            SCREEN+=("${GRAY}${sep}${RESET}" "")
        else
            t=${e%%|*}; d=${e#*|}
            SCREEN+=("${BOLD}${CYAN}${t}${RESET}")
            gloss_wrap $(( width - 2 )) "$d" "  "
            SCREEN+=("" "${GRAY}${sep}${RESET}" "")
        fi
    done
}

glossary_screen() {
    local off=0 vis w total key rc
    local -a ALL
    get_size
    while true; do
        w=$COLS; (( w < 40 )) && w=40
        gloss_build $(( w - 4 ))
        ALL=("${SCREEN[@]}"); total=${#ALL[@]}
        vis=$(( ROWS - 4 )); (( vis < 5 )) && vis=5
        (( off > total - vis )) && off=$(( total - vis )); (( off < 0 )) && off=0
        SCREEN=("${ALL[@]:off:vis}")
        draw_screen "Glossary  ($(( off + 1 ))-$(( off + ${#SCREEN[@]} )) of ${total})" "Up/Down PgUp/PgDn Home/End: scroll   ,/. theme   q / Esc / k: back"
        read_key 0.5; rc=$?
        (( rc == 2 )) && return 0
        (( rc == 1 )) && continue
        case $KEY in
            THEME_CHANGED) : ;; # loop rebuilds every glossary line using the new palette
            q|Q|k|K|ESC|ENTER) return 0 ;;
            UP) off=$(( off - 1 )) ;;
            DOWN) off=$(( off + 1 )) ;;
            PGUP|b) off=$(( off - vis + 1 )) ;;
            PGDN|' ') off=$(( off + vis - 1 )) ;;
            HOME) off=0 ;;
            END) off=$total ;;
        esac
    done
}

request_refresh() {
    # `r` cancels a slow in-flight round and starts a fresh one without waiting on probes.
    if (( CYCLE_RUNNING )); then
        kill_children
        CYCLE_RUNNING=0; CYCLE_TIMED_OUT=0
    fi
    REFRESH_REQ=1
    FORCE_REDRAW=1
    FOREST_W=-1
    start_system_proxy_detection || true
}

on_key() {
    case $KEY in
        q|Q) QUIT=1 ;;
        r|R) request_refresh ;;
        p|P) PAUSED=$(( 1 - PAUSED )); (( ! PAUSED )) && NEXT_AT=0 ;;
        x|X) PRIVACY=$(( 1 - PRIVACY ))
             if (( PRIVACY )); then STATUS_MSG="${GREEN}privacy mode ON${RESET}"; else STATUS_MSG="${CYAN}privacy mode off${RESET}"; fi
             MSG_UNTIL=$((SECONDS + 3)) ;;
        TAB|LEFT|RIGHT) FOCUS=$(( 1 - FOCUS )) ;;
        UP) move_sel -1 ;;
        DOWN) move_sel 1 ;;
        t|T) speedtest_screen ;;
        k|K) glossary_screen ;;
        j|J) system_mirrors_screen ;;
        ENTER|d|D) details_screen ;;
        s|S) settings_screen ;;
        g|G) diag_screen ;;
        '+'|'=') adjust_interval 1 ;;
        '-'|'_') adjust_interval -1 ;;
    esac
}

interactive() {
    local rc NEED=1
    tty_enter
    get_size
    NEXT_AT=0
    while (( ! QUIT )); do
        if load_system_proxy_result; then NEED=1; fi
        PARTIAL_CHANGED=0
        ingest_partial_results
        if (( PARTIAL_CHANGED )); then NEED=1; PARTIAL_CHANGED=0; fi
        if cycle_finished; then
            if (( CYCLE_TIMED_OUT )); then kill_children; else reap_children; fi
            ingest_cycle; CYCLE_RUNNING=0; CYCLE_TIMED_OUT=0
            NEXT_AT=$(( SECONDS + INTERVAL )); NEED=1
        fi
        if (( ! CYCLE_RUNNING )) && { (( REFRESH_REQ )) || { (( ! PAUSED )) && (( SECONDS >= NEXT_AT )); }; }; then
            REFRESH_REQ=0; start_cycle; NEED=1
        fi
        if (( RESIZED )); then
            RESIZED=0; get_size
            FOREST_W=-1; FORCE_REDRAW=0
            NEED=1
        elif (( FORCE_REDRAW )); then
            FORCE_REDRAW=0; get_size; FOREST_W=-1
            NEED=1
        fi
        if (( NEED )); then
            NEED=0
            compose_frame; paint
        fi
        read_key 0.25; rc=$?
        if (( rc == 0 )); then
            on_key; NEED=1
        elif (( rc == 2 )); then
            QUIT=1
        fi
        [[ -n $STATUS_MSG ]] && (( SECONDS >= MSG_UNTIL )) && { STATUS_MSG=""; NEED=1; }
    done
}

run_once() { # N cycles then print one frame
    local n=$1 k
    for (( k = 0; k < n; k++ )); do
        start_cycle
        while ! cycle_finished; do read -rt 0.1 _ <> <(:) || :; done
        if (( CYCLE_TIMED_OUT )); then kill_children; else reap_children; fi
        ingest_cycle; CYCLE_RUNNING=0; CYCLE_TIMED_OUT=0
    done
    SEL=(0 0); FOCUS=-1; NOSEL=1
    get_size
    compose_frame
    local l
    for l in "${OUT[@]}"; do printf '%s%s%s\n' "$RESET" "$l" "$RESET"; done
    # In one-shot colour output, do not leave the user's shell with Lightly Rose rendition active.
    (( USE_COLOR )) && printf '\e[0m'
}

usage() { awk 'NR > 1 { if (/^# =====/ && ++c == 2) exit; sub(/^# ?/, ""); print }' "$SELF"; }

cleanup() {
    kill_children
    if [[ -n $SYS_PROXY_PID ]] && kill -0 "$SYS_PROXY_PID" 2>/dev/null; then
        terminate_process_tree "$SYS_PROXY_PID"
        wait "$SYS_PROXY_PID" 2>/dev/null || true
    fi
    [[ -n $TMPD ]] && rm -rf -- "$TMPD"
    tty_leave
}

main() {
    local mode=interactive cycles="" do_install=1 arg requested_mode="" requested_theme="" env_theme="" force_mode_screen=0
    [[ -n ${NETSCOPE_NO_INSTALL:-} ]] && do_install=0
    while (( $# )); do
        arg=$1
        case $arg in
            --once) mode=once; do_install=0 ;;
            --diag) mode=diag; do_install=0 ;;
            --uninstall|--remove) mode=uninstall ;;
            --install-mode) force_mode_screen=1 ;;
            --demo) requested_mode=demo ;;
            --local) requested_mode=local ;;
            --system) requested_mode=system ;;
            --write-config) mode=writeconf ;;
            --cycles) shift; cycles=${1:-}; [[ $cycles =~ ^[0-9]+$ ]] || { echo "--cycles needs a number" >&2; exit 2; } ;;
            --cols) shift; FORCE_COLS=${1:-}; [[ $FORCE_COLS =~ ^[0-9]+$ ]] || { echo "--cols needs a number" >&2; exit 2; } ;;
            --rows) shift; FORCE_ROWS=${1:-}; [[ $FORCE_ROWS =~ ^[0-9]+$ ]] || { echo "--rows needs a number" >&2; exit 2; } ;;
            --ascii) UI_ASCII=1 ;;
            --color) USE_COLOR=2 ;;
            --no-install) do_install=0 ;;
            --theme) shift; requested_theme=${1:-}; theme_index "$requested_theme" >/dev/null || { printf 'Unknown theme: %s\nValid themes: %s\n' "$requested_theme" "${THEME_SLUGS[*]}" >&2; exit 2; } ;;
            --list-themes) printf '%s\n' "${THEME_SLUGS[@]}"; exit 0 ;;
            --privacy) PRIVACY=1 ;;
            --speedtest) mode=speedtest; do_install=0 ;;
            --version) printf '%s %s\n' "$APP" "$VERSION"; exit 0 ;;
            -h|--help) usage; exit 0 ;;
            *) printf 'Unknown option: %s (try --help)\n' "$arg" >&2; exit 2 ;;
        esac
        shift
    done

    if (( USE_COLOR == 1 )); then
        { [[ -n ${NO_COLOR:-} ]] || [[ ${TERM:-} == dumb ]] || [[ ! -t 1 ]]; } && USE_COLOR=0
    fi
    migrate_legacy_config
    load_settings
    (( SETTINGS_MIGRATED )) && save_settings || true
    # Legacy slugs are migrated by load_settings. Environment and CLI overrides
    # follow the blueprint precedence without overwriting the saved preference.
    if [[ -n ${NETSCOPE_THEME:-} ]]; then
        env_theme=$NETSCOPE_THEME
        case $env_theme in sakura) env_theme=hanakage ;; aero-water) env_theme=aqualume ;; red-white) env_theme=kohaku ;; esac
        theme_index "$env_theme" >/dev/null && THEME=$env_theme
    fi
    [[ -n $requested_theme ]] && THEME=$requested_theme
    load_install_mode
    if [[ -n $requested_mode ]]; then INSTALL_MODE=$requested_mode; set_install_paths; save_install_mode "$INSTALL_MODE" || { echo "Could not save installation mode" >&2; exit 1; }
    else set_install_paths; fi
    init_colors
    init_glyphs
    detect_tools
    resolve_proxy

    case $mode in
        writeconf) write_config_template; exit $? ;;
        uninstall)
            do_uninstall
            if [[ -t 0 && -t 1 ]]; then printf '\n%sPress Enter to close...%s' "$GRAY" "$RESET"; read -r _ || true; printf '\n'; fi
            exit 0 ;;
        diag)
            get_size; load_providers; build_diag
            local l; for l in "${SCREEN[@]}"; do printf '%s%s%s\n' "$RESET" "$l" "$RESET"; done
            (( USE_COLOR )) && printf '\e[0m'
            exit 0 ;;
    esac

    if [[ $mode == interactive ]] && { [[ ! -t 0 ]] || [[ ! -t 1 ]]; }; then
        printf 'Sakura NetScope needs an interactive terminal. Use --once for a single report.\n' >&2
        exit 1
    fi
    if [[ $mode == interactive && -t 0 && -t 1 ]]; then
        # Install the resize handler BEFORE the first-run/--install-mode chooser.
        # Previously it was installed only after the installer had returned, so
        # SIGWINCH during Requirements/installation selection was silently lost.
        trap 'RESIZED=1' WINCH
    fi
    if [[ $mode == interactive && -t 0 && -t 1 ]]; then
        if (( force_mode_screen )) || [[ -z $INSTALL_MODE ]]; then
            tty_enter
            choose_install_mode
            choice_rc=$?
            if (( choice_rc == 2 )); then tty_leave; exit 0
            elif (( choice_rc != 0 )); then tty_leave; exit 1
            fi
            init_colors
        else
            set_install_paths
        fi
        if [[ $INSTALL_MODE == demo ]]; then do_install=0; INSTALL_STATE=demo; else do_install=1; fi
    fi
    if ! requirements_probe_ok; then
        printf 'Required dependency missing: install at least one usable probe backend (working ping, curl, wget, dig, host or nslookup).\n' >&2
        printf 'Sakura NetScope was not installed or updated. See --diag for detected tools.\n' >&2
        exit 1
    fi

    load_providers
    TMPD="$(mktemp -d "${TMPDIR:-/tmp}/$APP.XXXXXX")" || { echo "cannot create a temp directory" >&2; exit 1; }
    CDIR="$TMPD/cycle"
    SYS_PROXY_FILE="$TMPD/system-proxy"
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP

    if [[ $mode == interactive ]]; then
        start_system_proxy_detection || true
    else
        detect_system_proxy
    fi

    if (( do_install )); then
        ensure_installed || true
        case $INSTALL_STATE in
            new)     STATUS_MSG="${GREEN}${G_OK}${RESET} installed to ${INSTALL_PATH}"; MSG_UNTIL=$((SECONDS + 8)) ;;
            updated) STATUS_MSG="${GREEN}${G_OK}${RESET} installed copy updated to v${VERSION}"; MSG_UNTIL=$((SECONDS + 6)) ;;
            demo)    STATUS_MSG="${CYAN}Demo mode: nothing installed${RESET}"; MSG_UNTIL=$((SECONDS + 8)) ;;
            older)   STATUS_MSG="${YELLOW}${INSTALL_NOTE}${RESET}"; MSG_UNTIL=$((SECONDS + 8)) ;;
            failed)  STATUS_MSG="${YELLOW}self-install failed: ${INSTALL_NOTE}${RESET}"; MSG_UNTIL=$((SECONDS + 10)) ;;
        esac
    fi

    if [[ $mode == speedtest ]]; then
        run_speedtest_cli; exit $?
    fi

    if [[ $mode == once ]]; then
        run_once "${cycles:-$MIN_SAMPLES}"
    else
        interactive
        :
    fi
}

main "$@"
