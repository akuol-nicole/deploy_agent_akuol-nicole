#!!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
PREFIX="attendance_tracker_"

CREATED_DIR=""

info()  { echo "[INFO]  $*"; }
ok()    { echo "[OK]    $*"; }
warn()  { echo "[WARN]  $*"; }
error() { echo "[ERROR] $*" >&2; }

sed_in_place() {
    if sed --version >/dev/null 2>&1; then
        sed -i "$@"
    else
        sed -i '' "$@"
    fi
}

ask() {
    local _ask_target="$1" _ask_prompt="$2" _ask_input
    if ! read -r -p "$_ask_prompt" _ask_input; then
        echo
        if [[ -n "$CREATED_DIR" ]]; then
            on_interrupt "end of input"
        fi
        info "No more input. Exiting."
        exit 0
    fi
    printf -v "$_ask_target" '%s' "$_ask_input"
}

ask_number() {
    local _num_target="$1" _num_prompt="$2" _num_min="$3" _num_max="$4" _num_default="$5" _num
    while true; do
        ask _num "$_num_prompt"
        if [[ -z "$_num" && -n "$_num_default" ]]; then
            _num="$_num_default"
        fi

        if [[ -z "$_num" ]]; then
            warn "A value is required."
        elif [[ ! "$_num" =~ ^[0-9]+$ ]]; then
            warn "'$_num' is not a whole number. Please enter digits only."
        elif (( ${#_num} > 6 )); then
            warn "That number is too large."
        else
            _num=$((10#$_num))
            if (( _num < _num_min || _num > _num_max )); then
                warn "Please enter a number from $_num_min to $_num_max."
            else
                printf -v "$_num_target" '%s' "$_num"
                return 0
            fi
        fi
    done
}

is_yes() { [[ "$1" =~ ^[Yy]([Ee][Ss])?$ ]]; }

on_interrupt() {
    local reason="$1"
    trap '' INT TSTP
    echo
    warn "Deployment interrupted by $reason."

    if [[ -n "$CREATED_DIR" && -d "$CREATED_DIR" ]]; then
        local parent base archive
        parent="$(dirname "$CREATED_DIR")"
        base="$(basename "$CREATED_DIR")"
        archive="${base}_archive.zip"

        cd "$parent" || exit 1
        rm -f "$archive"
        info "Zipping the incomplete project into $archive ..."
        if zip -rq "$archive" "$base"; then
            ok "Archive created: $parent/$archive"
            rm -rf "$base"
            ok "Removed the incomplete folder: $base/"
        else
            error "zip failed. The incomplete folder was kept at $CREATED_DIR"
        fi
    else
        info "No project folder had been created yet, so there is nothing to archive."
    fi

    info "Session closed."
    exit 130
}

start_deploy_traps() {
    trap 'on_interrupt "Ctrl+C (SIGINT)"' INT
    trap 'on_interrupt "Ctrl+Z (SIGTSTP)"' TSTP
}

stop_deploy_traps() {
    trap - INT TSTP
}

fail_deploy() {
    error "$1"
    if [[ -n "$CREATED_DIR" && -d "$CREATED_DIR" ]]; then
        rm -rf "$CREATED_DIR"
        info "Removed the incomplete folder: $(basename "$CREATED_DIR")/"
    fi
    CREATED_DIR=""
    stop_deploy_traps
}

preflight_checks() {
    info "Running pre-flight checks..."
    local failed=0 f

    if command -v python3 >/dev/null 2>&1 && python3 --version >/dev/null 2>&1; then
        ok "python3 found: $(python3 --version 2>&1)"
    else
        error "python3 is not installed. Please install Python 3 and try again."
        failed=1
    fi

    if command -v zip >/dev/null 2>&1; then
        ok "zip found"
    else
        error "zip is not installed. Please install it (e.g. sudo apt install zip) and try again."
        failed=1
    fi

    for f in attendance_checker.py assets.csv config.json; do
        if [[ ! -f "$TEMPLATES_DIR/$f" ]]; then
            error "Missing template file: templates/$f"
            failed=1
        fi
    done

    if [[ ! -w "$SCRIPT_DIR" ]]; then
        error "No write permission in $SCRIPT_DIR"
        failed=1
    fi

    return $failed
}

ask_project_name() {
    local _pn_target="$1" _pn
    while true; do
        ask _pn "Enter a suffix for the project folder (attendance_tracker_<suffix>): "
        if [[ -z "$_pn" ]]; then
            warn "The suffix cannot be empty."
        elif [[ ! "$_pn" =~ ^[A-Za-z0-9_-]+$ ]]; then
            warn "Use only letters, numbers, - or _ (no spaces)."
        else
            printf -v "$_pn_target" '%s' "$_pn"
            info "The project folder will be: ${PREFIX}${_pn}/"
            return 0
        fi
    done
}

roster_from_template() {
    local roster="$1" available count
    available=$(tail -n +2 "$TEMPLATES_DIR/assets.csv" | grep -c .)
    if (( available == 0 )); then
        error "templates/assets.csv has no student rows."
        return 1
    fi

    ask_number count "How many students should be copied (1-$available)? " 1 "$available"
    head -n $((count + 1)) "$TEMPLATES_DIR/assets.csv" > "$roster" || return 1

    ok "Copied the header and $count student(s) from templates/assets.csv"
    info "total_sessions stays at 5 (4 prior sessions in the roster + today)."
}

roster_fresh() {
    local roster="$1" config="$2" available count email name
    available=$(tail -n +2 "$TEMPLATES_DIR/assets.csv" | grep -c .)
    if (( available == 0 )); then
        error "templates/assets.csv has no student rows."
        return 1
    fi

    ask_number count "How many students should be generated (1-$available)? " 1 "$available"

    echo "Email,Names,Attendance Count,Absence Count" > "$roster" || return 1
    while IFS=, read -r email name _; do
        echo "$email,$name,0,0" >> "$roster" || return 1
    done < <(tail -n +2 "$TEMPLATES_DIR/assets.csv" | head -n "$count")

    sed_in_place 's/"total_sessions": *[0-9][0-9]*/"total_sessions": 1/' "$config" || return 1

    ok "Generated $count student(s) with Attendance Count and Absence Count set to 0"
    info "total_sessions set to 1 (no prior sessions + today)."
}

build_roster() {
    local helpers="$1" choice
    echo
    echo "How should Helpers/assets.csv be built?"
    echo "  A) Copy students from templates/assets.csv"
    echo "  B) Generate a fresh roster (counts start at 0)"
    while true; do
        ask choice "Choose A or B: "
        case "$choice" in
            [Aa]) roster_from_template "$helpers/assets.csv"; return $? ;;
            [Bb]) roster_fresh "$helpers/assets.csv" "$helpers/config.json"; return $? ;;
            *)    warn "Please type A or B." ;;
        esac
    done
}

set_permissions() {
    local target="$1"
    chmod +x "$target/attendance_checker.py" || return 1
    chmod 600 "$target/Helpers/config.json"  || return 1

    echo
    ok "Permissions set:"
    echo "        attendance_checker.py  -> executable (chmod +x)"
    echo "        Helpers/config.json    -> owner read/write only (chmod 600)"
    ( cd "$target" && ls -l attendance_checker.py Helpers/config.json | sed 's/^/        /' )
}

update_thresholds() {
    local config="$1" answer warning failure
    echo
    ask answer "Do you want to update the attendance alert thresholds? [y/N]: "
    if ! is_yes "$answer"; then
        info "Keeping the default thresholds (warning 75, failure 50)."
        return 0
    fi

    ask_number warning "Warning threshold % (1-100, press Enter for 75): " 1 100 75
    while true; do
        ask_number failure "Failure threshold % (0-100, press Enter for 50): " 0 100 50
        if (( failure < warning )); then
            break
        fi
        warn "The failure threshold must be lower than the warning threshold ($warning)."
    done

    sed_in_place \
        -e "s/\(\"warning\": *\)[0-9][0-9]*/\1$warning/" \
        -e "s/\(\"failure\": *\)[0-9][0-9]*/\1$failure/" \
        "$config" || return 1

    if grep -Eq "\"warning\": *${warning}([^0-9]|$)" "$config" \
        && grep -Eq "\"failure\": *${failure}([^0-9]|$)" "$config"; then
        ok "Thresholds updated in Helpers/config.json:"
        grep -E '"(warning|failure)"' "$config" | sed 's/^/    /'
    else
        error "Could not confirm the threshold update in config.json."
        return 1
    fi
}

deploy_project() {
    local name target answer
    echo
    echo "=== Feature 1: Deploy the application ==="

    if ! preflight_checks; then
        error "Pre-flight checks failed. Deployment stopped."
        return 1
    fi

    start_deploy_traps

    echo
    ask_project_name name
    target="$SCRIPT_DIR/${PREFIX}${name}"

    if [[ -e "$target" ]]; then
        warn "$(basename "$target") already exists."
        ask answer "Overwrite it? This deletes the old folder. [y/N]: "
        if is_yes "$answer"; then
            if ! rm -rf "$target"; then
                error "Could not remove the old folder (check permissions)."
                stop_deploy_traps
                return 1
            fi
            info "Old folder removed."
        else
            error "Deployment aborted. The existing folder was left untouched."
            stop_deploy_traps
            return 1
        fi
    fi

    if ! mkdir "$target" 2>/dev/null; then
        error "Could not create $(basename "$target") (permission denied?)."
        stop_deploy_traps
        return 1
    fi
    CREATED_DIR="$target"

    mkdir -p "$target/Helpers" "$target/reports" \
        || { fail_deploy "Could not create Helpers/ and reports/."; return 1; }
    ok "Created $(basename "$target")/ with Helpers/ and reports/"

    cp "$TEMPLATES_DIR/attendance_checker.py" "$target/attendance_checker.py" \
        && cp "$TEMPLATES_DIR/config.json" "$target/Helpers/config.json" \
        || { fail_deploy "Could not copy the template files."; return 1; }
    ok "Copied attendance_checker.py and Helpers/config.json from templates/"

    build_roster "$target/Helpers" \
        || { fail_deploy "Could not build Helpers/assets.csv."; return 1; }

    set_permissions "$target" \
        || { fail_deploy "Could not set file permissions."; return 1; }

    update_thresholds "$target/Helpers/config.json" \
        || { fail_deploy "Could not update the thresholds."; return 1; }

    stop_deploy_traps
    CREATED_DIR=""
    echo
    ok "Deployment complete: $(basename "$target")/"

    info "Verifying the deployment by starting the application..."
    run_app "$target"
}

run_app() {
    local dir="$1" f status
    echo
    echo "=== Feature 2: Run the application ==="

    for f in attendance_checker.py Helpers/assets.csv Helpers/config.json; do
        if [[ ! -f "$dir/$f" ]]; then
            error "$(basename "$dir") is missing $f. Deploy the project first (option 1)."
            return 1
        fi
    done

    if ! command -v python3 >/dev/null 2>&1; then
        error "python3 is not installed."
        return 1
    fi

    info "Starting attendance_checker.py in $(basename "$dir")/ ..."
    cd "$dir" || { error "Could not enter $dir"; return 1; }
    python3 attendance_checker.py
    status=$?
    cd "$SCRIPT_DIR" || return 1

    echo
    case $status in
        0)   ok "Marking session finished. Logs are in $(basename "$dir")/reports/. Use option 3 to archive them." ;;
        130) warn "Marking was stopped with Ctrl+C. Students marked before that were saved." ;;
        *)   error "The application exited with code $status." ;;
    esac
    return $status
}

archive_logs() {
    local dir="$1" ts log src dest_dir dest archived=0
    echo
    echo "=== Feature 3: Archive the log files ==="

    ts="$(date +%Y%m%d_%H%M%S)"

    for log in attendance absent; do
        src="$dir/reports/${log}.log"
        if [[ -f "$src" ]]; then
            dest_dir="$dir/archives/$log"
            dest="$dest_dir/${log}_${ts}.log"
            if mkdir -p "$dest_dir" && mv "$src" "$dest"; then
                ok "Archived ${log}.log -> ${dest#"$SCRIPT_DIR"/}"
                archived=$((archived + 1))
            else
                error "Could not archive ${log}.log"
            fi
        else
            warn "reports/${log}.log was not found, so it was skipped."
            if [[ "$log" == "absent" ]]; then
                info "This is normal if nobody was marked absent."
            fi
        fi
    done

    if (( archived == 0 )); then
        warn "No logs were archived. Run the application first (option 2)."
    else
        ok "$archived log(s) archived."
    fi
}

choose_project() {
    local _cp_target="$1" _cp_input _cp_dir _cp_p _cp_projects
    shopt -s nullglob
    _cp_projects=( "$SCRIPT_DIR/${PREFIX}"*/ )
    shopt -u nullglob

    if (( ${#_cp_projects[@]} == 0 )); then
        error "No deployed projects found. Use option 1 to deploy one first."
        return 1
    fi

    echo
    echo "Deployed projects (suffixes):"
    for _cp_p in "${_cp_projects[@]}"; do
        _cp_p="${_cp_p%/}"
        echo "  - ${_cp_p##*/"$PREFIX"}"
    done

    ask _cp_input "Enter the project suffix: "
    _cp_input="${_cp_input#"$PREFIX"}"
    _cp_dir="$SCRIPT_DIR/${PREFIX}${_cp_input}"

    if [[ -z "$_cp_input" || ! -d "$_cp_dir" ]]; then
        error "Project '$_cp_input' was not found."
        return 1
    fi
    printf -v "$_cp_target" '%s' "$_cp_dir"
}

show_menu() {
    echo
    echo "=========================================="
    echo "   Attendance Tracker Deploy Agent"
    echo "=========================================="
    echo "  1) Deploy the application"
    echo "  2) Run the application"
    echo "  3) Archive the log files"
    echo "  4) Exit"
}

main() {
    local choice project
    cd "$SCRIPT_DIR" || exit 1
    while true; do
        show_menu
        ask choice "Choose an option [1-4]: "
        case "$choice" in
            1) deploy_project ;;
            2) choose_project project && run_app "$project" ;;
            3) choose_project project && archive_logs "$project" ;;
            4) echo "Goodbye."; exit 0 ;;
            *) warn "Invalid option. Please choose 1, 2, 3 or 4." ;;
        esac
    done
}

main "$@"
 