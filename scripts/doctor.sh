#!/usr/bin/env bash
# homebase doctor — report drift between what's declared and what's running.
#
# Facts only, no fixes. It is the instrument for the monthly devenv review
# (forge skill /devenv-review), and is usable on its own:
#
#   homebase doctor            # human-readable
#   homebase doctor --json     # machine-readable, for agents and Emacs
#   homebase doctor --offline  # skip `git fetch` (no network)
#
# Every check reports one of:
#   OK    nothing to do
#   WARN  drift worth acting on
#   FAIL  drift that will break the next deploy (e.g. chezmoi source diverged)
#   SKIP  check not applicable here (e.g. no distrobox on macOS)
#   ACK   a WARN/FAIL suppressed by ~/.homebase/doctor-ack until its expiry
#
# Exit status: 0 = all OK/SKIP/ACK, 1 = at least one WARN, 2 = at least one FAIL.
#
# Ack file format (one per line, # comments allowed):
#   <check-id> <YYYY-MM-DD expiry> <reason...>
# e.g.
#   flake.age 2026-11-30 holding Emacs at 31.1 until Doom supports 31.2
#
# Why this exists: forge vault/devenv/incidents/
# 2026-09-22-homebase-silent-drift-shadowed-agent-shell.org

set -uo pipefail

JSON=false
OFFLINE=false
for arg in "$@"; do
    case "$arg" in
        --json) JSON=true ;;
        --offline) OFFLINE=true ;;
        -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown argument: $arg" >&2; exit 64 ;;
    esac
done

HOMEBASE_REPO="${HOMEBASE_REPO:-$HOME/dev/me/homebase}"
CHEZMOI_SOURCE="$(chezmoi source-path 2>/dev/null || echo "$HOME/.local/share/chezmoi")"
ACK_FILE="${HOMEBASE_DOCTOR_ACK:-$HOME/.homebase/doctor-ack}"
LOCK_WARN_DAYS="${HOMEBASE_LOCK_WARN_DAYS:-60}"
HOMEBASE_TOML="${HOMEBASE_TOML:-$CHEZMOI_SOURCE/homebase.toml}"
APPIMAGE_DIR="${HOMEBASE_APPIMAGE_DIR:-$HOME/AppImages}"
# Files whose change means the image should be rebuilt.
IMAGE_INPUTS=(images/Containerfile flake.nix flake.lock homebase.toml)

TODAY="$(date +%F)"
NOW="$(date +%s)"

ids=(); statuses=(); summaries=(); fixes=()

_ack_reason() {
    # Print the reason if check id $1 has a live ack; print "expired:<date>" if stale.
    [[ -f "$ACK_FILE" ]] || return 1
    local id exp reason
    while read -r id exp reason; do
        [[ -z "$id" || "$id" == \#* ]] && continue
        [[ "$id" == "$1" ]] || continue
        if [[ "$exp" > "$TODAY" || "$exp" == "$TODAY" ]]; then
            echo "$reason (until $exp)"; return 0
        fi
        echo "expired:$exp"; return 0
    done < "$ACK_FILE"
    return 1
}

report() {
    # report <id> <status> <summary> [fix]
    local id="$1" status="$2" summary="$3" fix="${4:-}" ack
    if [[ "$status" == WARN || "$status" == FAIL ]] && ack=$(_ack_reason "$id"); then
        if [[ "$ack" == expired:* ]]; then
            summary="$summary [ack expired ${ack#expired:}]"
        else
            status=ACK; summary="$summary — acked: $ack"
        fi
    fi
    ids+=("$id"); statuses+=("$status"); summaries+=("$summary"); fixes+=("$fix")
}

_host() {
    # Run a host command (podman) from inside a distrobox or on the host itself.
    if [[ -f /run/.containerenv ]]; then distrobox-host-exec "$@"; else "$@"; fi
}

_fetch() {
    $OFFLINE && return 0
    timeout 20 git -C "$1" fetch -q origin 2>/dev/null
}

# ── a. repos ──────────────────────────────────────────────────────────────────

check_repo() {
    # check_repo <id> <path> <role>
    local id="$1" path="$2" role="$3"
    if [[ ! -d "$path/.git" ]]; then
        report "$id" SKIP "$role not found at $path"; return
    fi
    local fetch_note=""
    _fetch "$path" || fetch_note=" (fetch failed; remote state may be stale)"
    local dirty ahead behind
    dirty=$(git -C "$path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    ahead=$(git -C "$path" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
    behind=$(git -C "$path" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)

    local problems=() status=OK fix=""
    (( dirty > 0 ))  && problems+=("$dirty uncommitted")
    (( ahead > 0 ))  && problems+=("$ahead unpushed")
    (( behind > 0 )) && problems+=("$behind behind origin")

    if (( ${#problems[@]} == 0 )); then
        report "$id" OK "$role clean and level with origin$fetch_note"; return
    fi
    local joined; joined=$(IFS=,; echo "${problems[*]}" | sed 's/,/, /g')
    if [[ "$role" == "chezmoi source" ]]; then
        # Edits belong in the working clone; anything local here blocks `chezmoi update`.
        if (( dirty > 0 || ahead > 0 )); then
            status=FAIL; fix="edit in $HOMEBASE_REPO, not here; reset or push this clone"
        else
            status=WARN; fix="chezmoi update"
        fi
    else
        status=WARN
        (( dirty > 0 || ahead > 0 )) && fix="commit and push — chezmoi deploys only what is on origin"
        (( behind > 0 && dirty == 0 && ahead == 0 )) && fix="git -C $path pull --ff-only"
    fi
    report "$id" "$status" "$role: $joined$fetch_note" "$fix"
}

# ── b. dotfiles ───────────────────────────────────────────────────────────────

check_chezmoi() {
    if ! command -v chezmoi &>/dev/null; then
        report chezmoi.drift SKIP "chezmoi not installed"; return
    fi
    local out n
    # Scripts excluded so this never triggers a 1Password prompt.
    out=$(chezmoi status --exclude=scripts 2>/dev/null)
    n=$(printf '%s' "$out" | grep -c . || true)
    if (( n == 0 )); then
        report chezmoi.drift OK "dotfiles match chezmoi source"
    else
        local files; files=$(printf '%s\n' "$out" | awk '{print $2}' | head -5 | paste -sd' ' -)
        report chezmoi.drift WARN "$n file(s) differ from source: $files" \
            "chezmoi diff; then chezmoi add (keep live) or chezmoi apply --force <file> (keep source)"
    fi
}

# ── c. images ─────────────────────────────────────────────────────────────────

check_images() {
    if [[ "$(uname -s)" == Darwin ]]; then
        report image SKIP "macOS: no distrobox images"; return
    fi
    if ! _host sh -c 'command -v podman' &>/dev/null; then
        report image SKIP "podman not available"; return
    fi
    if [[ ! -d "$CHEZMOI_SOURCE/.git" ]]; then
        report image SKIP "no chezmoi source to compare against"; return
    fi
    local ref; ref=$(git -C "$CHEZMOI_SOURCE" rev-parse -q --verify origin/main >/dev/null && echo origin/main || echo HEAD)
    local line name imgid created epoch newer box_arg
    local rows; rows=$(_host podman ps -a --filter label=manager=distrobox \
                        --format '{{.Names}}|{{.ImageID}}|{{.Image}}' 2>/dev/null)
    if [[ -z "$rows" ]]; then
        report image SKIP "no distrobox containers"; return
    fi
    while IFS='|' read -r name imgid _; do
        [[ -z "$name" ]] && continue
        created=$(_host podman image inspect --format '{{.Created}}' "$imgid" 2>/dev/null | head -1)
        epoch=$(date -d "$(echo "$created" | cut -d. -f1 | sed 's/ +0000//') UTC" +%s 2>/dev/null || echo 0)
        if (( epoch == 0 )); then
            report "image.$name" WARN "box '$name': cannot read image creation date" ; continue
        fi
        # Image-input commits newer than the image this box runs.
        newer=$(git -C "$CHEZMOI_SOURCE" log "$ref" --format=%ct -- "${IMAGE_INPUTS[@]}" \
                | awk -v e="$epoch" '$1 > e' | wc -l | tr -d ' ')
        local built; built=$(date -d "@$epoch" +%F)
        box_arg=""; [[ "$name" != home ]] && box_arg=" $name"
        if (( newer == 0 )); then
            report "image.$name" OK "box '$name': image $built is current with source"
        else
            report "image.$name" WARN "box '$name': image $built predates $newer image-input commit(s)" \
                "wait for CI green, then on host: homebase box rebuild$box_arg"
        fi
    done <<< "$rows"
}

# ── d. lock age ───────────────────────────────────────────────────────────────

check_lock() {
    local lock="$CHEZMOI_SOURCE/flake.lock"
    if [[ ! -f "$lock" ]]; then
        report flake.age SKIP "no flake.lock in chezmoi source"; return
    fi
    local ts
    ts=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["nodes"]["nixpkgs"]["locked"]["lastModified"])' "$lock" 2>/dev/null)
    if [[ -z "$ts" ]]; then
        report flake.age WARN "cannot read nixpkgs lastModified from flake.lock"; return
    fi
    local days=$(( (NOW - ts) / 86400 )) date; date=$(date -d "@$ts" +%F 2>/dev/null || echo "?")
    if (( days > LOCK_WARN_DAYS )); then
        report flake.age WARN "nixpkgs locked at $date ($days days old, threshold $LOCK_WARN_DAYS)" \
            "in $HOMEBASE_REPO: nix flake update nixpkgs; build envs; review closure diff; commit"
    else
        report flake.age OK "nixpkgs locked at $date ($days days old)"
    fi
}

# ── e. launchers ──────────────────────────────────────────────────────────────

_exec_path() {
    # First program in a .desktop Exec= value, skipping `env` and VAR=value words.
    local word
    # shellcheck disable=SC2086
    set -- $1
    for word in "$@"; do
        word="${word%\"}"; word="${word#\"}"
        [[ "$word" == env || "$word" == *=* ]] && continue
        echo "$word"; return
    done
}

check_launchers() {
    # Autostart and menu entries whose program lives under $HOME must point at an
    # executable that exists, and never at ~/Downloads (2026-11-09: Vibe Typer).
    local dirs=() d f line prog
    for d in "$HOME/.config/autostart" "$HOME/.local/share/applications"; do
        [[ -d "$d" ]] && dirs+=("$d")
    done
    if (( ${#dirs[@]} == 0 )); then
        report desktop.exec SKIP "no autostart or applications directory"; return
    fi
    local missing=() downloads=() n=0
    local home_real; home_real=$(cd "$HOME" && pwd -P)
    for d in "${dirs[@]}"; do
        for f in "$d"/*.desktop; do
            [[ -f "$f" ]] || continue
            while IFS= read -r line; do
                prog=$(_exec_path "${line#Exec=}")
                [[ "$prog" == /* ]] || continue
                [[ "$prog" == "$HOME"/* || "$prog" == "$home_real"/* \
                   || "$prog" == /home/* || "$prog" == /var/home/* ]] || continue
                n=$((n + 1))
                [[ -x "$prog" ]] || missing+=("${f##*/} → $prog")
                [[ "$prog" == */Downloads/* ]] && downloads+=("${f##*/} → $prog")
            done < <(grep -E '^Exec=' "$f")
        done
    done
    if (( ${#missing[@]} > 0 )); then
        report desktop.exec WARN "${#missing[@]} launcher(s) point at a missing program: ${missing[*]:0:3}" \
            "reinstall the program (homebase setup-appimages) or fix/remove the .desktop file"
    elif (( ${#downloads[@]} > 0 )); then
        report desktop.exec WARN "${#downloads[@]} launcher(s) run from ~/Downloads: ${downloads[*]:0:3}" \
            "move it to ~/AppImages, update the Exec= line, declare it in homebase.toml [appimages]"
    else
        report desktop.exec OK "$n launcher(s) under \$HOME point at existing programs"
    fi
}

# ── f. appimages ──────────────────────────────────────────────────────────────

check_appimages() {
    if [[ "$(uname -s)" != Linux ]]; then
        report appimages SKIP "not Linux"; return
    fi
    local parser="$CHEZMOI_SOURCE/scripts/parse-toml-array.sh" entries
    if [[ ! -x "$parser" ]] || ! entries=$("$parser" appimages apps "$HOMEBASE_TOML" 2>/dev/null); then
        report appimages SKIP "no [appimages] apps in $HOMEBASE_TOML"; return
    fi
    local file declared=() problems=() n=0 f
    while IFS='|' read -r file _; do
        [[ -z "$file" ]] && continue
        n=$((n + 1)); declared+=("$file")
        [[ -x "$APPIMAGE_DIR/$file" ]] || problems+=("$file missing")
    done <<< "$entries"
    for f in "$APPIMAGE_DIR"/*; do
        [[ -f "$f" ]] || continue
        [[ "${f,,}" == *.appimage ]] || continue
        [[ " ${declared[*]} " == *" ${f##*/} "* ]] || problems+=("${f##*/} undeclared")
    done
    if (( ${#problems[@]} == 0 )); then
        report appimages OK "$n declared AppImage(s) present in $APPIMAGE_DIR"
    else
        local joined; joined=$(IFS=,; echo "${problems[*]}" | sed 's/,/, /g')
        report appimages WARN "$APPIMAGE_DIR: $joined" \
            "missing: homebase setup-appimages; undeclared: add to homebase.toml [appimages] or delete"
    fi
}

check_repo homebase.repo "$HOMEBASE_REPO" "working clone"
check_repo homebase.source "$CHEZMOI_SOURCE" "chezmoi source"
check_chezmoi
check_images
check_lock
check_launchers
check_appimages

# ── output ────────────────────────────────────────────────────────────────────

worst=0
for s in "${statuses[@]}"; do
    [[ "$s" == WARN ]] && (( worst < 1 )) && worst=1
    [[ "$s" == FAIL ]] && worst=2
done

_esc() { local s="$1"; s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\n'/\\n}; s=${s//$'\t'/ }; printf '%s' "$s"; }

if $JSON; then
    printf '{"generated":"%s","host":"%s","in_box":%s,"checks":[' \
        "$(date -Iseconds)" "$(_esc "$(hostname)")" "$([[ -f /run/.containerenv ]] && echo true || echo false)"
    for i in "${!ids[@]}"; do
        (( i > 0 )) && printf ','
        printf '{"id":"%s","status":"%s","summary":"%s","fix":"%s"}' \
            "$(_esc "${ids[$i]}")" "${statuses[$i]}" "$(_esc "${summaries[$i]}")" "$(_esc "${fixes[$i]}")"
    done
    printf '],"exit":%d}\n' "$worst"
else
    for i in "${!ids[@]}"; do
        printf '%-4s  %-16s %s\n' "${statuses[$i]}" "${ids[$i]}" "${summaries[$i]}"
        [[ -n "${fixes[$i]}" && "${statuses[$i]}" =~ ^(WARN|FAIL)$ ]] && printf '%24s→ %s\n' "" "${fixes[$i]}"
    done
fi
exit "$worst"
