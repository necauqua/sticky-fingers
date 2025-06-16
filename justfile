proton := "Proton - Experimental"

noita-dir := "noita"
compat-dir := "noita/steam-compat-data"

export STEAM_COMPAT_CLIENT_INSTALL_PATH := x"~/.local/share/Steam"
export STEAM_COMPAT_DATA_PATH := justfile_dir() + "/" + compat-dir

[private]
@default:
    just -ul

save-dir := compat-dir + "/pfx/drive_c/users/steamuser/AppData/LocalLow/Nolla_Games_Noita"

[private]
find-steam-lib:
    #!/usr/bin/env bash
    set -euo pipefail

    vdf="$HOME/.steam/steam/steamapps/libraryfolders.vdf"

    [[ ! -f "$vdf" ]] && vdf="$HOME/.local/share/Steam/steamapps/libraryfolders.vdf"

    awk -v app="881100" '
    /"path"/ {
        gsub(/["\t ]/, "", $2)
        path = $2 "/steamapps"
        if (system("test -d \"" path "\"") == 0) {
            current_path = path
        }
    }
    current_path && $0 ~ "\"" app "\"" {
        print current_path
        exit
    }' "$vdf"

# Start the Noita instance
run:
    #!/usr/bin/env bash
    set -euo pipefail

    steam_common="$(just find-steam-lib)/common"

    # idempotently make sure things are in place:
    mkdir -p "{{save-dir}}/"{save_shared,save00/persistent/flags}
    ln -f config.xml "{{save-dir}}/save_shared/config.xml"
    # just link .exe, .dll and data into a new cwd ¯\_(ツ)_/¯
    ln -sf "$steam_common/Noita/"{*.dll,noita.exe,data} noita
    # stop release notes popup (config must have the same hash string)
    echo -n static > {{noita-dir}}/_version_hash.txt

    # some bs to have logs printed to the terminal and have CTRL+C work
    echo '' > noita/logger.txt
    tail -f "noita/logger.txt" 2>/dev/null &
    tail_pid=$!
    cleanup() {
        pkill -f -- "-marker=$marker"
        kill $tail_pid 2>/dev/null
        exit
    }
    trap cleanup SIGINT SIGTERM EXIT

    marker="kill_me_$(date +%s)"
    cd noita
    steam-run \
        "$steam_common/{{proton}}/proton" \
        waitforexitandrun \
        noita.exe \
        -- \
        -no_logo_splashes \
        -gamemode \
        -marker=$marker
    # ^ -marker is not something Noita recognises, we use it to find the process with pkill -f

    # just clean the exit code eh
    true

# Delete the world data
@reset:
    rm -rf {{save-dir}}/save00/{world,player.xml,world_state.xml,session_numbers.salakieli}

# Completely delete the instance, including stats, unlocks, installed mods etc.
@full-reset:
    rm -rf noita

# Set arbitrary persistent flags
@set-flags +flags:
    mkdir -p "{{save-dir}}/save00/persistent/flags"
    for flag in {{flags}}; do touch "{{save-dir}}/save00/persistent/flags/$flag"; done

# Alias for `set-flags intro_has_played`
@no-intro:
    just set-flags intro_has_played
