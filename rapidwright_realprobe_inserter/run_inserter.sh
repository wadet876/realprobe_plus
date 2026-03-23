#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BUILD_DIR="$SCRIPT_DIR/build/classes"
SRC_FILE="$SCRIPT_DIR/RealProbeInserter.java"
DEFAULT_RAPIDWRIGHT_PATH=$(cd -- "$SCRIPT_DIR/../.." && pwd)/RapidWright
DEFAULT_FINALIZE_VIVADO="${FINALIZE_VIVADO:-1}"

usage() {
    echo "Usage: $0 <config.properties> [--key value ...]" >&2
    echo "" >&2
    echo "Default behavior:" >&2
    echo "  1. Generate a readable EDIF for the original DCP when needed." >&2
    echo "  2. Run the RapidWright inserter to create an intermediate DCP." >&2
    echo "  3. Finalize the result with Vivado into the requested output DCP." >&2
    echo "" >&2
    echo "Environment overrides:" >&2
    echo "  JAVA_HOME         Optional JDK root. If unset, the script will try 'java'/'javac' on PATH." >&2
    echo "  RAPIDWRIGHT_PATH  RapidWright checkout root. Defaults to sibling repo at ../../RapidWright when present." >&2
    echo "  RAPIDWRIGHT_JAR   Optional explicit RapidWright jar to use instead of RAPIDWRIGHT_PATH." >&2
    echo "  VIVADO_BIN        Optional explicit Vivado binary. Defaults to 'vivado' on PATH or \$HOME/tools/Xilinx/Vivado/2023.1/bin/vivado." >&2
    echo "  FINALIZE_VIVADO   Set to 0 to skip the Vivado finalization stage and keep the RapidWright DCP as the requested output." >&2
}

if [[ $# -eq 0 || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

CONFIG_FILE=$1
shift

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config file was not found: $CONFIG_FILE" >&2
    exit 1
fi

if [[ -z "${JAVA_HOME:-}" ]] && ! command -v java >/dev/null 2>&1; then
    LOCAL_JDK_ROOT=$(find "$HOME/tools" -path '*/jdk17-local/usr/lib/jvm/*' -type d 2>/dev/null | head -n 1 || true)
    if [[ -n "$LOCAL_JDK_ROOT" ]]; then
        export JAVA_HOME="$LOCAL_JDK_ROOT"
    fi
fi

if [[ -n "${JAVA_HOME:-}" ]]; then
    export PATH="$JAVA_HOME/bin:$PATH"
fi

if ! command -v java >/dev/null 2>&1 || ! command -v javac >/dev/null 2>&1; then
    echo "Java was not found. Set JAVA_HOME or put java/javac on PATH." >&2
    exit 1
fi

if [[ -z "${RAPIDWRIGHT_PATH:-}" && -d "$DEFAULT_RAPIDWRIGHT_PATH/bin" ]]; then
    export RAPIDWRIGHT_PATH="$DEFAULT_RAPIDWRIGHT_PATH"
fi

if [[ -n "${RAPIDWRIGHT_JAR:-}" ]]; then
    RAPIDWRIGHT_CP="$RAPIDWRIGHT_JAR"
elif [[ -n "${RAPIDWRIGHT_PATH:-}" ]]; then
    RAPIDWRIGHT_CP="$RAPIDWRIGHT_PATH/bin:$RAPIDWRIGHT_PATH/jars/*"
else
    echo "Set RAPIDWRIGHT_PATH or RAPIDWRIGHT_JAR before running the inserter." >&2
    exit 1
fi

declare -A PROPS

load_properties() {
    local file=$1
    while IFS='=' read -r raw_key raw_value; do
        local key=${raw_key%%[[:space:]]*}
        [[ -z "$key" || "${key:0:1}" == "#" ]] && continue
        local value=${raw_value:-}
        value=${value%%#*}
        value=${value%"${value##*[![:space:]]}"}
        value=${value#"${value%%[![:space:]]*}"}
        PROPS["$key"]=$value
    done < "$file"
}

flag_to_key() {
    local flag=$1
    echo "${flag#--}" | tr '-' '_'
}

apply_overrides() {
    local args=("$@")
    local i=0
    while (( i < ${#args[@]} )); do
        local arg=${args[$i]}
        if [[ "$arg" != --* ]]; then
            ((i += 1))
            continue
        fi
        if [[ "$arg" == "--help" ]]; then
            usage
            exit 0
        fi
        if (( i + 1 >= ${#args[@]} )); then
            echo "Missing value for $arg" >&2
            exit 1
        fi
        PROPS["$(flag_to_key "$arg")"]=${args[$((i + 1))]}
        ((i += 2))
    done
}

detect_vivado_bin() {
    if [[ -n "${VIVADO_BIN:-}" ]]; then
        echo "$VIVADO_BIN"
        return
    fi
    if command -v vivado >/dev/null 2>&1; then
        command -v vivado
        return
    fi
    if [[ -x "$HOME/tools/Xilinx/Vivado/2023.1/bin/vivado" ]]; then
        echo "$HOME/tools/Xilinx/Vivado/2023.1/bin/vivado"
        return
    fi
    echo ""
}

setup_vivado_env() {
    export LOCPATH="${LOCPATH:-$HOME/.local/usr/lib/locale}"
    export LANG="${LANG:-C.UTF-8}"
    export LC_ALL="${LC_ALL:-C.UTF-8}"
    export LANGUAGE="${LANGUAGE:-en_US:en}"
    if [[ -n "${VIVADO_BIN_PATH:-}" ]]; then
        local vivado_root
        vivado_root=$(cd -- "$(dirname -- "$VIVADO_BIN_PATH")/.." && pwd)
        export LD_LIBRARY_PATH="$vivado_root/lib/lnx64.o/SuSE:$vivado_root/lib/lnx64.o:${LD_LIBRARY_PATH:-}"
    fi
}

run_vivado_tcl() {
    local tcl_file=$1
    setup_vivado_env
    "$VIVADO_BIN_PATH" -mode batch -nolog -nojournal -notrace -source "$tcl_file"
}

readable_edif_has_sidecars() {
    local readable_edif=$1
    local readable_dir
    readable_dir=$(dirname -- "$readable_edif")
    [[ -d "$readable_dir" ]] || return 1
    find "$readable_dir" -maxdepth 1 -type f -name '*.edn' | grep -q .
}

generate_readable_edif() {
    local original_dcp=$1
    local readable_edif=$2
    mkdir -p "$(dirname -- "$readable_edif")"
    local tcl_file
    tcl_file=$(mktemp)
    cat > "$tcl_file" <<EOF
open_checkpoint $original_dcp
write_edif -force $readable_edif
exit
EOF
    run_vivado_tcl "$tcl_file"
    rm -f "$tcl_file"
}

finalize_with_vivado() {
    local intermediate_dcp=$1
    local final_dcp=$2
    local load_tcl=${intermediate_dcp%.dcp}_load.tcl
    mkdir -p "$(dirname -- "$final_dcp")"
    local tcl_file
    tcl_file=$(mktemp)
    if [[ -f "$load_tcl" ]]; then
        cat > "$tcl_file" <<EOF
source $load_tcl
write_checkpoint -force $final_dcp
exit
EOF
    else
        cat > "$tcl_file" <<EOF
open_checkpoint $intermediate_dcp
write_checkpoint -force $final_dcp
exit
EOF
    fi
    run_vivado_tcl "$tcl_file"
    rm -f "$tcl_file"
}

load_properties "$CONFIG_FILE"
apply_overrides "$@"

ORIGINAL_DCP=${PROPS[original_dcp]:-}
ORIGINAL_READABLE_EDIF=${PROPS[original_readable_edif]:-}
FINAL_OUTPUT_DCP=${PROPS[output_dcp]:-}

if [[ -z "$ORIGINAL_DCP" || -z "$FINAL_OUTPUT_DCP" ]]; then
    echo "Both original_dcp and output_dcp must be set." >&2
    exit 1
fi

VIVADO_BIN_PATH=""
if [[ "$DEFAULT_FINALIZE_VIVADO" != "0" || -z "$ORIGINAL_READABLE_EDIF" ]]; then
    VIVADO_BIN_PATH=$(detect_vivado_bin)
    if [[ -z "$VIVADO_BIN_PATH" ]]; then
        echo "Vivado was not found. Set VIVADO_BIN or put vivado on PATH." >&2
        exit 1
    fi
fi

if [[ -z "$ORIGINAL_READABLE_EDIF" ]]; then
    READABLE_DIR="$(dirname -- "$FINAL_OUTPUT_DCP")/.readable_edif"
    ORIGINAL_READABLE_EDIF="$READABLE_DIR/$(basename -- "${ORIGINAL_DCP%.*}").edf"
    echo "Generating readable EDIF for original design at $ORIGINAL_READABLE_EDIF" >&2
    generate_readable_edif "$ORIGINAL_DCP" "$ORIGINAL_READABLE_EDIF"
elif ! readable_edif_has_sidecars "$ORIGINAL_READABLE_EDIF"; then
    READABLE_DIR="$(dirname -- "$FINAL_OUTPUT_DCP")/.readable_edif"
    GENERATED_READABLE_EDIF="$READABLE_DIR/$(basename -- "${ORIGINAL_DCP%.*}").edf"
    echo "Readable EDIF $ORIGINAL_READABLE_EDIF has no .edn sidecars; regenerating a complete export at $GENERATED_READABLE_EDIF" >&2
    generate_readable_edif "$ORIGINAL_DCP" "$GENERATED_READABLE_EDIF"
    ORIGINAL_READABLE_EDIF="$GENERATED_READABLE_EDIF"
fi

INTERMEDIATE_OUTPUT_DCP=$FINAL_OUTPUT_DCP
if [[ "$DEFAULT_FINALIZE_VIVADO" != "0" ]]; then
    INTERMEDIATE_OUTPUT_DCP="${FINAL_OUTPUT_DCP%.dcp}_rapidwright.dcp"
fi

mkdir -p "$BUILD_DIR"

javac -cp "$RAPIDWRIGHT_CP" -d "$BUILD_DIR" "$SRC_FILE"
java -cp "$BUILD_DIR:$RAPIDWRIGHT_CP" \
    com.xilinx.rapidwright.examples.RealProbeInserter \
    --config "$CONFIG_FILE" \
    "$@" \
    --original-readable-edif "$ORIGINAL_READABLE_EDIF" \
    --output-dcp "$INTERMEDIATE_OUTPUT_DCP"

if [[ "$DEFAULT_FINALIZE_VIVADO" != "0" ]]; then
    echo "Finalizing Vivado-native checkpoint at $FINAL_OUTPUT_DCP" >&2
    finalize_with_vivado "$INTERMEDIATE_OUTPUT_DCP" "$FINAL_OUTPUT_DCP"
    echo "Final Vivado-native checkpoint: $FINAL_OUTPUT_DCP" >&2
fi
