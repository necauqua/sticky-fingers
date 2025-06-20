proton := "Proton - Experimental"
noita-dir := "noita"
compat-dir := noita-dir + "/steam-compat-data"

export STEAM_COMPAT_CLIENT_INSTALL_PATH := x"~/.local/share/Steam"
export STEAM_COMPAT_DATA_PATH := justfile_dir() + "/" + compat-dir

[private]
@default:
    just -ul

save-dir := compat-dir + "/pfx/drive_c/users/steamuser/AppData/LocalLow/Nolla_Games_Noita"

# Start the Noita instance
run:
    #!/usr/bin/env bash
    set -euo pipefail

    # some bs to have logs printed to the terminal and have CTRL+C work
    marker="kill_me_$(date +%s)"
    truncate -s0 "{{noita-dir}}/logger.txt"
    tail -f "{{noita-dir}}/logger.txt" 2>/dev/null &
    tail_pid=$!
    cleanup() {
        kill $tail_pid 2>/dev/null
        pkill -f -- "-marker=$marker"
        exit
    }
    trap cleanup SIGINT SIGTERM EXIT

    # -marker is not something Noita recognises, we use it to find the process with pkill -f
    just run-proton noita.exe -no_logo_splashes -gamemode -marker=$marker

# Delete the world data
@reset:
    rm -rf {{save-dir}}/save00/{world,player.xml,world_state.xml,session_numbers.salakieli}

# Completely delete the instance, including stats, unlocks, installed mods etc.
@full-reset:
    rm -rf "{{noita-dir}}"

# Set arbitrary persistent flags
@set-flags +flags:
    mkdir -p "{{save-dir}}/save00/persistent/flags"
    for flag in {{flags}}; do touch "{{save-dir}}/save00/persistent/flags/$flag"; done

# Alias for `set-flags intro_has_played`
@no-intro:
    just set-flags intro_has_played

# Upload a mod to the Steam Workshop
@workshop-upload mod-id change-notes:
    just run-proton noita_dev.exe \
        -workshop_upload "{{mod-id}}" \
        -workshop_upload_change_notes "{{change-notes}}"

# Try to find the Steam library path containing Noita
[private]
find-steam-common:
    #!/usr/bin/env bash
    set -euo pipefail

    vdf="$HOME/.steam/steam/steamapps/libraryfolders.vdf"

    [[ ! -f "$vdf" ]] && vdf="$HOME/.local/share/Steam/steamapps/libraryfolders.vdf"

    found=$(awk -v app="881100" '
    /"path"/ {
        gsub(/["\t ]/, "", $2)
        path = $2 "/steamapps"
        if (system("test -d \"" path "\"") == 0) {
            current_path = path
        }
    }
    current_path && $0 ~ "\"" app "\"" {
        print current_path "/common"
        exit
    }' "$vdf")

    if [[ -z "$found" ]]; then
        echo "Noita Steam location not found" >&2
        exit 1
    fi

    echo "$found"

# Idempotently set up the Noita working directory by making a link farm
[private]
setup-noita-dir steam-common:
    #!/usr/bin/env bash
    set -euo pipefail

    # idempotently make sure things are in place:
    mkdir -p "{{save-dir}}/"{save_shared,save00/persistent/flags} "{{noita-dir}}/mods"
    ln -sf "../{{save-dir}}/save00" "{{noita-dir}}/save00" # a shortcut
    ln -f config.xml "{{save-dir}}/save_shared/config.xml"

    # forcelink all mods present in current repo
    find . -maxdepth 2 -name mod.xml -execdir \
        sh -c 'ln -sf "../../$(basename "$(pwd)")" "../{{noita-dir}}/mods/"' \;

    # just link .exe, .dll and data into a new cwd ¯\_(ツ)_/¯
    ln -sf "{{steam-common}}/Noita/{*.dll,*.exe,data}" "{{noita-dir}}"

    # see workshop mods and set steam now playing
    if [[ -v WITH_STEAM ]]; then
        ln -sf "{{steam-common}}/Noita/steam_appid.txt" "{{noita-dir}}"
    else
        rm -f "{{noita-dir}}/steam_appid.txt"
    fi

    # stop release notes popup (config must have the same hash string)
    echo -n static > "{{noita-dir}}/_version_hash.txt"

[private]
run-proton exe *args:
    #!/usr/bin/env bash
    set -euo pipefail

    steam_common=$(just find-steam-common)
    just setup-noita-dir "$steam_common"

    wrapper=env # meh
    if [[ -f /etc/NIXOS ]]; then
        wrapper="steam-run"
    fi

    cd "{{noita-dir}}"
    env \
      PROTON_LOG=1 \
      PROTON_LOG_DIR="{{noita-dir}}/proton-logs" \
      $wrapper \
        "$steam_common/{{proton}}/proton" \
        waitforexitandrun \
        "{{exe}}" \
        {{args}}
