CURR_PATH=$1
PROJECT_NAME=$2
SOLUTION_NAME=$3
FULL_PATH="$CURR_PATH/$PROJECT_NAME/$SOLUTION_NAME"

append_unique_lines() {
    local target_file=$1
    local content=$2
    [ -z "$content" ] && return

    while IFS= read -r signal; do
        signal=$(printf '%s' "$signal" | tr -d '\r')
        [ -z "$signal" ] && continue
        if ! grep -Fxq "$signal" "$target_file"; then
            printf '%s\n' "$signal" >> "$target_file"
        fi
    done <<EOF
$content
EOF
}

total_count=0
index=0

: > "$FULL_PATH/rprobe/apstart_signals.txt"
: > "$FULL_PATH/rprobe/apdone_signals.txt"
: > "$FULL_PATH/rprobe/module_apstart.txt"
: > "$FULL_PATH/rprobe/module_apdone.txt"

top_module=$(tr -d '\r' < top.txt)

while IFS= read -r module_name_raw; do
    module_name=$(printf '%s' "$module_name_raw" | tr -d '\r')
    [ -z "$module_name" ] && continue

    index=$((index + 1))

    if [ "$module_name" = "$top_module" ]; then
        module_file="$FULL_PATH/impl/ip/hdl/verilog/${module_name}.v"
        dump_output="$FULL_PATH/impl/ip/hdl/verilog/${module_name}_output.txt"
        dump_wire="$FULL_PATH/impl/ip/hdl/verilog/${module_name}_wire.txt"
        dump_port="$FULL_PATH/impl/ip/hdl/verilog/${module_name}_port.txt"
        dump_fcall="$FULL_PATH/impl/ip/hdl/verilog/${module_name}_fcall.txt"
        dump_signal="$FULL_PATH/impl/ip/hdl/verilog/top_signal.txt"
        dump_under="$FULL_PATH/impl/ip/hdl/verilog/${module_name}_under.txt"
        delete_top="$FULL_PATH/impl/ip/hdl/verilog/${module_name}_top.txt"
    else
        module_file="$FULL_PATH/impl/ip/hdl/verilog/${top_module}_${module_name}.v"
        dump_output="$FULL_PATH/impl/ip/hdl/verilog/${top_module}_${module_name}_output.txt"
        dump_wire="$FULL_PATH/impl/ip/hdl/verilog/${top_module}_${module_name}_wire.txt"
        dump_port="$FULL_PATH/impl/ip/hdl/verilog/${top_module}_${module_name}_port.txt"
        dump_fcall="$FULL_PATH/impl/ip/hdl/verilog/${top_module}_${module_name}_fcall.txt"
        dump_signal="$FULL_PATH/impl/ip/hdl/verilog/${top_module}_${module_name}_signal.txt"
        dump_under="$FULL_PATH/impl/ip/hdl/verilog/${top_module}_${module_name}_under.txt"
        delete_top="$FULL_PATH/impl/ip/hdl/verilog/${top_module}_${module_name}_top.txt"
    fi

    : > "$dump_output"
    : > "$dump_wire"
    : > "$dump_port"
    : > "$dump_fcall"
    : > "$dump_signal"
    : > "$dump_under"

    if [ ! -f "$module_file" ]; then
        echo "Verilog file for module $module_name not found. File path: $module_file"
        continue
    fi

    grep_output=$(grep -o -nE "(wire|output(\s+)?wire|output) *?.*?ap_start;" "$module_file" | sed -n 's/.*\b\(\w*ap_start\w*\)\b.*/\1/p' | grep -v "ap_start_int" | grep -v "(wire).*\bap_start\b")
    if [ "$module_name" != "$top_module" ]; then
        grep_output=$(printf '%s\n' "$grep_output" | grep -vx "ap_start" || true)
    fi
    count=$(printf '%s\n' "$grep_output" | sed '/^$/d' | wc -l)
    total_count=$((total_count + count))
    printf '%s. %s(%s)\n%s\n' "$index" "$(basename "$module_file")" "$count" "$grep_output" >> "$FULL_PATH/rprobe/module_apstart.txt"

    if [ "$count" -gt 0 ]; then
        printf '%s\n' "$grep_output" | sed 's/$/;/' | sed 's/^/output /' >> "$dump_output"
        printf '%s\n' "$grep_output" | sed 's/$/;/' | sed 's/^/wire /' >> "$dump_wire"
        printf '%s\n' "$grep_output" | sed 's/$/,/' | sed 's/^/        /' >> "$dump_port"
        printf '%s\n' "$grep_output" >> "$dump_signal"
        printf '%s\n' "$grep_output" >> "$dump_under"
        printf '%s\n' "$grep_output" | sed 's/.*/.&(&),/' >> "$dump_fcall"
    elif [ -f "$delete_top" ]; then
        rm "$delete_top"
    fi

    append_unique_lines "$FULL_PATH/rprobe/apstart_signals.txt" "$grep_output"

    grep_output=$(grep -o -nE "^\s*(wire|reg|output(\s+)?wire|output(\s+)?reg|output) *?.*?ap_done;" "$module_file" | sed -n 's/.*\b\(\w*ap_done\w*\)\b.*/\1/p' | grep -v "ap_done_int" | grep -v "(wire).*\bap_done\b")
    if [ "$module_name" != "$top_module" ]; then
        grep_output=$(printf '%s\n' "$grep_output" | grep -vx "ap_done" || true)
    fi
    count=$(printf '%s\n' "$grep_output" | sed '/^$/d' | wc -l)
    total_count=$((total_count + count))
    printf '%s. %s(%s)\n%s\n' "$index" "$(basename "$module_file")" "$count" "$grep_output" >> "$FULL_PATH/rprobe/module_apdone.txt"

    if [ "$count" -gt 0 ]; then
        printf '%s\n' "$grep_output" | sed 's/$/;/' | sed 's/^/output /' >> "$dump_output"
        printf '%s\n' "$grep_output" | sed 's/$/;/' | sed 's/^/wire /' >> "$dump_wire"
        printf '%s\n' "$grep_output" | sed 's/$/,/' | sed 's/^/        /' >> "$dump_port"
        printf '%s\n' "$grep_output" >> "$dump_signal"
        printf '%s\n' "$grep_output" >> "$dump_under"
        printf '%s\n' "$grep_output" | sed 's/.*/.&(&),/' >> "$dump_fcall"
    elif [ -f "$delete_top" ]; then
        rm "$delete_top"
    fi

    append_unique_lines "$FULL_PATH/rprobe/apdone_signals.txt" "$grep_output"
done < "$FULL_PATH/rprobe/module_name.txt"

printf '\nTotal: %s\n' "$total_count" >> "$FULL_PATH/rprobe/module_apstart.txt"
