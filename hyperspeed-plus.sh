#!/usr/bin/env bash
set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
ENDC='\033[0m'

SCRIPT_NAME='HyperSpeed Plus'
SCRIPT_VERSION='7.0.0'
BASE_DIR="${HOME}/.hyperspeed-plus"
LOG_DIR="${BASE_DIR}/logs"
WORK_DIR="${BASE_DIR}/tmp"
REPORT_DIR="${BASE_DIR}/reports"
RUN_DIR="${BASE_DIR}/run"
WORKER_SCRIPT="${RUN_DIR}/worker.sh"
BINARY="${WORK_DIR}/bimc"
THREAD_FLAG=''
PID_FILE="${RUN_DIR}/hyperspeed.pid"
TASK_FILE="${RUN_DIR}/task.env"
DAEMON_STDOUT="${RUN_DIR}/daemon.out"
LAST_LOG_FILE="${RUN_DIR}/last_log_path"
LAST_CSV_FILE="${RUN_DIR}/last_csv_path"

mkdir -p "$LOG_DIR" "$WORK_DIR" "$REPORT_DIR" "$RUN_DIR"

NODES=(
'bimc|电信|上海|电信|aHR0cDovL3NwZWVkdGVzdDEub25saW5lLnNoLmNuOjgwODAvZG93bmxvYWQK|aHR0cDovL3NwZWVkdGVzdDEub25saW5lLnNoLmNuOjgwODAvdXBsb2FkCg=='
'bimc|电信|江苏镇江5G|电信|aHR0cDovLzVnemhlbmppYW5nLnNwZWVkdGVzdC5qc2luZm8ubmV0OjgwODAvZG93bmxvYWQ=|aHR0cDovLzVnemhlbmppYW5nLnNwZWVkdGVzdC5qc2luZm8ubmV0OjgwODAvdXBsb2Fk'
'bimc|电信|江苏南京5G|电信|aHR0cDovLzVnbmFuamluZy5zcGVlZHRlc3QuanNpbmZvLm5ldDo4MDgwL2Rvd25sb2FkCg==|aHR0cDovLzVnbmFuamluZy5zcGVlZHRlc3QuanNpbmZvLm5ldDo4MDgwL3VwbG9hZAo='
'bimc|联通|江苏无锡|联通|aHR0cHM6Ly9zcGVlZHRlc3QyLm5pdXRrLmNvbTo4MDgwL2Rvd25sb2Fk|aHR0cHM6Ly9zcGVlZHRlc3QyLm5pdXRrLmNvbTo4MDgwL3VwbG9hZA=='
'bimc|联通|湖南长沙5G|联通|aHR0cDovL3NwZWVkdGVzdDAxLmhuMTY1LmNvbTo4MDgwL2Rvd25sb2Fk|aHR0cDovL3NwZWVkdGVzdDAxLmhuMTY1LmNvbTo4MDgwL3VwbG9hZA=='
'bimc|联通|福建福州|联通|aHR0cDovL3VwbG9hZDEudGVzdHNwZWVkLmNkbjE2LmNvbTo4MDgwL2Rvd25sb2Fk|aHR0cDovL3VwbG9hZDEudGVzdHNwZWVkLmNkbjE2LmNvbTo4MDgwL3VwbG9hZA=='
'bimc|移动|浙江杭州5G|移动|aHR0cDovL3NwZWVkdGVzdC4xMzlwbGF5LmNvbTo4MDgwL2Rvd25sb2Fk|aHR0cDovL3NwZWVkdGVzdC4xMzlwbGF5LmNvbTo4MDgwL3VwbG9hZA=='
'bimc|移动|陕西西安5G|移动|aHR0cDovL3NwZWVkdGVzdC5vbmUtcHVuY2gud2luOjgwODAvZG93bmxvYWQ=|aHR0cDovL3NwZWVkdGVzdC5vbmUtcHVuY2gud2luOjgwODAvdXBsb2Fk'
'bimc|移动|北京|移动|aHR0cDovLzIxMS4xMzYuMzAuMTE0OjkwMDAvc3BlZWQvMjAwMDAwMC5kYXRhCg==|aHR0cDovLzIxMS4xMzYuMzAuMTE0OjkwMDAvc3BlZWQvMjAwMDAwLmRhdGEK'
'bimc|港澳台日韩|香港环电宽频|香港|aHR0cDovL29va2xhLWhpZGMuaGdjb25haXIuaGdjLmNvbS5oazo4MDgwL2Rvd25sb2FkCg==|aHR0cDovL29va2xhLWhpZGMuaGdjb25haXIuaGdjLmNvbS5oazo4MDgwL3VwbG9hZAo='
'bimc|港澳台日韩|澳门电讯|澳门|aHR0cDovL3NwZWVkdGVzdDUubWFjYXUuY3RtLm5ldDo4MDgwL2Rvd25sb2FkCg==|aHR0cDovL3NwZWVkdGVzdDUubWFjYXUuY3RtLm5ldDo4MDgwL3VwbG9hZAo='
'bimc|港澳台日韩|台北中华电信|台湾|aHR0cDovL3RwMS5jaHRtLmhpbmV0Lm5ldDo4MDgwL2Rvd25sb2FkCg==|aHR0cDovL3RwMS5jaHRtLmhpbmV0Lm5ldDo4MDgwL3VwbG9hZAo='
'bimc|港澳台日韩|东京乐天移动|日本|aHR0cDovL29va2xhLm1ic3BlZWQubmV0OjgwODAvZG93bmxvYWQK|aHR0cDovL29va2xhLm1ic3BlZWQubmV0OjgwODAvdXBsb2FkCg=='
)

command_exists() { command -v "$1" >/dev/null 2>&1; }

array_contains() {
    local seek="$1"; shift; local item
    for item in "$@"; do [[ "$item" == "$seek" ]] && return 0; done
    return 1
}

download_file() {
    local url="$1" target="$2"
    if command_exists curl; then curl -fsSL "$url" -o "$target"
    elif command_exists wget; then wget --no-check-certificate -qO "$target" "$url"
    else return 1; fi
}

check_dependencies() {
    local missing=()
    for cmd in base64 awk sed date sort head tail tr find basename dirname tar ps kill chmod cp cat; do
        command_exists "$cmd" || missing+=("$cmd")
    done
    if ! command_exists curl && ! command_exists wget; then missing+=(curl/wget); fi
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}缺少依赖: ${missing[*]}${ENDC}"; exit 1
    fi
}

prepare_bimc() {
    if [ ! -x "$BINARY" ]; then
        local arch; arch=$(uname -m)
        echo -e "${CYAN}正在获取 bimc 组件...${ENDC}"
        download_file "https://bench.im/bimc-${arch}" "$BINARY" \
            || { echo -e "${RED}bimc 下载失败${ENDC}"; exit 1; }
        chmod +x "$BINARY"
    fi
}

print_banner() {
    clear
    echo "————————————— ${SCRIPT_NAME} v${SCRIPT_VERSION} —————————————"
    echo "  长时压力测速 | 后台守护 | 随机间隔 | 曲线分析 | 报告上传"
    echo "  节点: 电信x3  联通x3  移动x3  港澳台日韩x4"
    echo "———————————————————————————————————————————————"
}

pause_screen() { read -r -p "按回车继续..." _; }
is_number() { [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]; }
decode_b64() { printf '%s' "$1" | base64 -d 2>/dev/null | tr -d '\r\n'; }

random_wait_seconds() {
    local max="$1"
    (( max <= 1 )) && echo 1 && return
    command_exists shuf && shuf -i 1-"$max" -n 1 || echo $(( RANDOM % max + 1 ))
}

get_thread_option() {
    read -r -p "启用八线程测速? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] && THREAD_FLAG='-m' || THREAD_FLAG=''
}

get_duration_option() {
    while true; do
        read -r -p "压力测速时长(小时，0=只跑一轮，默认0): " DURATION_HOURS
        DURATION_HOURS="${DURATION_HOURS:-0}"
        is_number "$DURATION_HOURS" && break
        echo -e "${RED}请输入数字${ENDC}"
    done
    if awk "BEGIN{exit !($DURATION_HOURS>0)}"; then
        while true; do
            read -r -p "每轮随机间隔上限(分钟，默认10): " INTERVAL_MINUTES
            INTERVAL_MINUTES="${INTERVAL_MINUTES:-10}"
            is_number "$INTERVAL_MINUTES" && break
            echo -e "${RED}请输入数字${ENDC}"
        done
    else
        INTERVAL_MINUTES=0
    fi
    DURATION_SECONDS=$(awk "BEGIN{printf \"%d\", $DURATION_HOURS*3600}")
    INTERVAL_SECONDS=$(awk "BEGIN{printf \"%d\", $INTERVAL_MINUTES*60}")
}

show_nodes() {
    echo
    echo "════════════════ 可选测速节点 ════════════════"
    printf '  %-4s %-12s %-18s %s\n' "编号" "运营商" "位置" "状态"
    echo "  ──────────────────────────────────────────"
    local i entry group location
    for i in "${!NODES[@]}"; do
        entry="${NODES[$i]}"
        IFS='|' read -r _ group location _ _ _ <<< "$entry"
        local tag=""
        [[ "$location" == "上海" || "$location" == *"镇江"* || "$location" == *"南京"* ]] && tag="✅已验证"
        [[ "$location" == *"香港"* || "$location" == *"台北"* || "$location" == *"东京"* ]] && tag="✅已验证"
        printf '  %-4s %-12s %-18s %s\n' "$((i+1))." "[$group]" "$location" "$tag"
    done
    echo
    echo "  1-3=电信  4-6=联通  7-9=移动  10-13=港澳台"
    echo "════════════════════════════════════════════"
}

select_nodes() {
    local input
    SELECTED_IDS=()
    show_nodes
    while true; do
        read -r -p "请选择测试节点 [all/1,2,3...]: " input
        input="${input// /}"
        if [[ -z "$input" || "$input" == "all" ]]; then
            for token in "${!NODES[@]}"; do SELECTED_IDS+=("$((token+1))"); done
            break
        fi
        IFS=',' read -r -a TOKENS <<< "$input"
        local valid=1
        for token in "${TOKENS[@]}"; do
            [[ "$token" =~ ^[0-9]+$ ]] || { valid=0; break; }
            local tn=$((10#$token))
            (( tn < 1 || tn > ${#NODES[@]} )) && { valid=0; break; }
        done
        if (( valid == 0 )); then echo -e "${RED}输入无效${ENDC}"; continue; fi
        for token in "${TOKENS[@]}"; do
            local tn=$((10#$token))
            array_contains "$tn" "${SELECTED_IDS[@]}" || SELECTED_IDS+=("$tn")
        done
        [ ${#SELECTED_IDS[@]} -gt 0 ] && break
        echo -e "${RED}未选择任何节点${ENDC}"
    done
    echo
    echo -e "${PURPLE}━━━━━━ 已选节点 ━━━━━━${ENDC}"
    local id entry group location
    for id in "${SELECTED_IDS[@]}"; do
        entry="${NODES[$((id-1))]}"
        IFS='|' read -r _ group location _ _ _ <<< "$entry"
        echo -e "  ${GREEN}✓${ENDC} [${group}] ${location}"
    done
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━${ENDC}"
}

new_log_files() {
    local ts; ts=$(date '+%Y%m%d-%H%M%S')
    LOG_FILE="${LOG_DIR}/hyperspeed-${ts}.log"
    CSV_FILE="${LOG_DIR}/hyperspeed-${ts}.csv"
    printf 'time,round,group,location,isp,node_name,upload_mbps,upload_status,download_mbps,download_status,latency_ms,jitter_ms,packet_loss\n' \
        > "$CSV_FILE"
    echo "$LOG_FILE" > "$LAST_LOG_FILE"
    echo "$CSV_FILE" > "$LAST_CSV_FILE"
}

log_line() {
    printf '%b\n' "$1"
    printf '%b\n' "$2" >> "$LOG_FILE"
}

save_task_env() {
    : > "$TASK_FILE"
    printf 'THREAD_FLAG=%q\n'      "$THREAD_FLAG"      >> "$TASK_FILE"
    printf 'DURATION_SECONDS=%q\n' "$DURATION_SECONDS" >> "$TASK_FILE"
    printf 'INTERVAL_SECONDS=%q\n' "$INTERVAL_SECONDS" >> "$TASK_FILE"
    printf 'DURATION_HOURS=%q\n'   "$DURATION_HOURS"   >> "$TASK_FILE"
    printf 'INTERVAL_MINUTES=%q\n' "$INTERVAL_MINUTES" >> "$TASK_FILE"
    printf 'SELECTED_IDS=(' >> "$TASK_FILE"
    local id; for id in "${SELECTED_IDS[@]}"; do printf '%q ' "$id" >> "$TASK_FILE"; done
    printf ')\n' >> "$TASK_FILE"
    printf 'NODES=(\n' >> "$TASK_FILE"
    local node; for node in "${NODES[@]}"; do printf '%q\n' "$node" >> "$TASK_FILE"; done
    printf ')\n' >> "$TASK_FILE"
}

is_running() {
    [ -f "$PID_FILE" ] || return 1
    local pid; pid=$(cat "$PID_FILE" 2>/dev/null)
    [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null
}

run_single_test() {
    local id="$1" round="$2"
    local entry group location isp dl_b64 ul_b64
    local dl ul output upload up_status download down_status latency jitter
    local now screen plain color

    entry="${NODES[$((id-1))]}"
    IFS='|' read -r _ group location isp dl_b64 ul_b64 <<< "$entry"
    now=$(date '+%F %T')
    dl=$(decode_b64 "$dl_b64")
    ul=$(decode_b64 "$ul_b64")

    local cmd=("$BINARY" "$dl" "$ul")
    [ -n "$THREAD_FLAG" ] && cmd+=("$THREAD_FLAG")
    output=$("${cmd[@]}" 2>/dev/null)

    IFS=',' read -r upload up_status download down_status latency jitter <<< "$output"
    upload="${upload:-0}"; up_status="${up_status:-失败}"
    download="${download:-0}"; down_status="${down_status:-失败}"
    latency="${latency:-0}"; jitter="${jitter:-0}"

    color="$GREEN"
    [[ "$up_status" != "正常" || "$down_status" != "正常" ]] && color="$RED"

    screen="${YELLOW}[第${round}轮]${ENDC} ${PURPLE}${group}${ENDC}|${GREEN}${location}${ENDC}"
    screen+="  ${CYAN}↑${ENDC} ${upload}  ${color}${up_status}${ENDC}"
    screen+="  ${CYAN}↓${ENDC} ${download}  ${color}${down_status}${ENDC}"
    screen+="  ${CYAN}↕${ENDC} ${latency}  ${CYAN}ϟ${ENDC} ${jitter}"

    plain="[第${round}轮] ${group}|${location}"
    plain+="  ↑ ${upload}  ${up_status}"
    plain+="  ↓ ${download}  ${down_status}"
    plain+="  ↕ ${latency}  ϟ ${jitter}"

    log_line "$screen" "$plain"
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,NULL\n' \
        "$now" "$round" "$group" "$location" "$isp" "$location" \
        "$upload" "$up_status" "$download" "$down_status" \
        "$latency" "$jitter" >> "$CSV_FILE"
}

run_test_plan() {
    new_log_files
    local end_epoch=0 now round=1 sleep_seconds
    (( DURATION_SECONDS > 0 )) && end_epoch=$(( $(date +%s) + DURATION_SECONDS ))
    log_line "${CYAN}开始测试  日志: ${LOG_FILE}${ENDC}" "开始测试  日志: ${LOG_FILE}"
    while true; do
        log_line "${PURPLE}———— 第 ${round} 轮 ————${ENDC}" "———— 第 ${round} 轮 ————"
        for id in "${SELECTED_IDS[@]}"; do
            run_single_test "$id" "$round"
            sleep 2
        done
        (( DURATION_SECONDS == 0 )) && break
        now=$(date +%s)
        (( now >= end_epoch )) && break
        sleep_seconds=$(random_wait_seconds "$INTERVAL_SECONDS")
        (( now + sleep_seconds > end_epoch )) && sleep_seconds=$(( end_epoch - now ))
        (( sleep_seconds <= 0 )) && break
        log_line "${CYAN}等待 ${sleep_seconds} 秒...${ENDC}" "等待 ${sleep_seconds} 秒"
        sleep "$sleep_seconds"
        round=$(( round + 1 ))
    done
    log_line "${GREEN}测试完成${ENDC}" "测试完成"
    rm -f "$PID_FILE"
}

write_worker_script() {
    mkdir -p "$RUN_DIR"
    cat > "$WORKER_SCRIPT" << 'WORKEREOF'
#!/usr/bin/env bash
set -o pipefail
BASE_DIR="${HOME}/.hyperspeed-plus"
LOG_DIR="${BASE_DIR}/logs"
WORK_DIR="${BASE_DIR}/tmp"
REPORT_DIR="${BASE_DIR}/reports"
RUN_DIR="${BASE_DIR}/run"
BINARY="${WORK_DIR}/bimc"
PID_FILE="${RUN_DIR}/hyperspeed.pid"
TASK_FILE="${RUN_DIR}/task.env"
LAST_LOG_FILE="${RUN_DIR}/last_log_path"
LAST_CSV_FILE="${RUN_DIR}/last_csv_path"
mkdir -p "$LOG_DIR" "$WORK_DIR" "$REPORT_DIR" "$RUN_DIR"
[ -f "$TASK_FILE" ] || { echo "task.env not found"; exit 1; }
source "$TASK_FILE"
decode_b64() { printf '%s' "$1" | base64 -d 2>/dev/null | tr -d '\r\n'; }
random_wait_seconds() {
    local max="$1"; (( max<=1 )) && echo 1 && return
    command -v shuf >/dev/null 2>&1 && shuf -i 1-"$max" -n 1 || echo $(( RANDOM%max+1 ))
}
prepare_bimc() {
    [ -x "$BINARY" ] && return
    local arch; arch=$(uname -m)
    command -v curl >/dev/null 2>&1 \
        && curl -fsSL "https://bench.im/bimc-${arch}" -o "$BINARY" \
        || wget --no-check-certificate -qO "$BINARY" "https://bench.im/bimc-${arch}"
    chmod +x "$BINARY"
}
new_log_files() {
    local ts; ts=$(date '+%Y%m%d-%H%M%S')
    LOG_FILE="${LOG_DIR}/hyperspeed-${ts}.log"
    CSV_FILE="${LOG_DIR}/hyperspeed-${ts}.csv"
    printf 'time,round,group,location,isp,node_name,upload_mbps,upload_status,download_mbps,download_status,latency_ms,jitter_ms,packet_loss\n' \
        > "$CSV_FILE"
    echo "$LOG_FILE" > "$LAST_LOG_FILE"
    echo "$CSV_FILE" > "$LAST_CSV_FILE"
}
log_line() { printf '%b\n' "$1"; printf '%b\n' "$2" >> "$LOG_FILE"; }
run_single_test() {
    local id="$1" round="$2"
    local entry group location isp dl_b64 ul_b64 dl ul output
    local upload up_status download down_status latency jitter now plain
    entry="${NODES[$((id-1))]}"
    IFS='|' read -r _ group location isp dl_b64 ul_b64 <<< "$entry"
    now=$(date '+%F %T')
    dl=$(decode_b64 "$dl_b64"); ul=$(decode_b64 "$ul_b64")
    local cmd=("$BINARY" "$dl" "$ul")
    [ -n "$THREAD_FLAG" ] && cmd+=("$THREAD_FLAG")
    output=$("${cmd[@]}" 2>/dev/null)
    IFS=',' read -r upload up_status download down_status latency jitter <<< "$output"
    upload="${upload:-0}"; up_status="${up_status:-失败}"
    download="${download:-0}"; down_status="${down_status:-失败}"
    latency="${latency:-0}"; jitter="${jitter:-0}"
    plain="[第${round}轮] ${group}|${location}  ↑ ${upload}  ${up_status}  ↓ ${download}  ${down_status}  ↕ ${latency}  ϟ ${jitter}"
    log_line "$plain" "$plain"
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,NULL\n' \
        "$now" "$round" "$group" "$location" "$isp" "$location" \
        "$upload" "$up_status" "$download" "$down_status" \
        "$latency" "$jitter" >> "$CSV_FILE"
}
run_test_plan() {
    trap 'rm -f "$PID_FILE"' EXIT
    new_log_files
    local end_epoch=0 now round=1 sleep_seconds
    (( DURATION_SECONDS>0 )) && end_epoch=$(( $(date +%s)+DURATION_SECONDS ))
    log_line "开始测试  日志: ${LOG_FILE}" "开始测试  日志: ${LOG_FILE}"
    while true; do
        log_line "———— 第 ${round} 轮 ————" "———— 第 ${round} 轮 ————"
        for id in "${SELECTED_IDS[@]}"; do run_single_test "$id" "$round"; sleep 2; done
        (( DURATION_SECONDS==0 )) && break
        now=$(date +%s); (( now>=end_epoch )) && break
        sleep_seconds=$(random_wait_seconds "$INTERVAL_SECONDS")
        (( now+sleep_seconds>end_epoch )) && sleep_seconds=$(( end_epoch-now ))
        (( sleep_seconds<=0 )) && break
        log_line "等待 ${sleep_seconds} 秒" "等待 ${sleep_seconds} 秒"
        sleep "$sleep_seconds"; round=$((round+1))
    done
    log_line "测试完成" "测试完成"
}
prepare_bimc
run_test_plan
WORKEREOF
    chmod +x "$WORKER_SCRIPT"
}

start_foreground_task() {
    prepare_bimc
    echo; echo -e "${CYAN}步骤 1/3  线程设置${ENDC}";  get_thread_option
    echo; echo -e "${CYAN}步骤 2/3  时长设置${ENDC}";  get_duration_option
    echo; echo -e "${CYAN}步骤 3/3  选择节点${ENDC}";  select_nodes
    echo; echo -e "${GREEN}▶ 开始测速...${ENDC}"; sleep 1
    run_test_plan
}

start_background_task() {
    is_running && {
        echo -e "${YELLOW}已有后台任务运行中，PID: $(cat "$PID_FILE")${ENDC}"
        return
    }
    prepare_bimc
    echo; echo -e "${CYAN}步骤 1/3  线程设置${ENDC}";  get_thread_option
    echo; echo -e "${CYAN}步骤 2/3  时长设置${ENDC}";  get_duration_option
    echo; echo -e "${CYAN}步骤 3/3  选择节点${ENDC}";  select_nodes
    echo; echo -e "${GREEN}▶ 正在启动后台任务...${ENDC}"
    save_task_env
    write_worker_script
    : > "$DAEMON_STDOUT"
    nohup bash "$WORKER_SCRIPT" >> "$DAEMON_STDOUT" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    disown "$pid" 2>/dev/null || true
    sleep 4
    if kill -0 "$pid" 2>/dev/null; then
        echo
        echo -e "${GREEN}╔══════════════════════════════════════════╗${ENDC}"
        echo -e "${GREEN}║  ✅  后台测速任务已成功启动              ║${ENDC}"
        echo -e "${GREEN}║  PID: ${pid}$(printf '%*s' $((38-${#pid})) '')║${ENDC}"
        echo -e "${GREEN}║  现在可以安全断开 SSH，测速不会中断      ║${ENDC}"
        echo -e "${GREEN}╠══════════════════════════════════════════╣${ENDC}"
        echo -e "${GREEN}║  查看进度：主菜单选 3                    ║${ENDC}"
        echo -e "${GREEN}║  停止任务：主菜单选 4                    ║${ENDC}"
        echo -e "${GREEN}╚══════════════════════════════════════════╝${ENDC}"
    else
        echo -e "${RED}后台任务启动失败${ENDC}"; rm -f "$PID_FILE"
        [ -f "$DAEMON_STDOUT" ] && cat "$DAEMON_STDOUT"
    fi
}

show_status() {
    if is_running; then
        local pid; pid=$(cat "$PID_FILE")
        echo -e "${GREEN}后台测速正在运行  PID: ${pid}${ENDC}"
        ps -p "$pid" -o pid,etime,cmd 2>/dev/null; echo
        [ -f "$LAST_LOG_FILE" ] && echo "当前日志: $(cat "$LAST_LOG_FILE" 2>/dev/null)"
        [ -f "$LAST_CSV_FILE" ] && echo "当前CSV:  $(cat "$LAST_CSV_FILE" 2>/dev/null)"
        echo "后台输出: $DAEMON_STDOUT"; echo
        [ -f "$DAEMON_STDOUT" ] && tail -n 20 "$DAEMON_STDOUT"
    else
        echo -e "${YELLOW}当前没有后台测速任务${ENDC}"
        [ -f "$DAEMON_STDOUT" ] && { echo; tail -n 20 "$DAEMON_STDOUT"; }
    fi
}

stop_background_task() {
    if ! is_running; then
        echo -e "${YELLOW}当前没有后台测速任务${ENDC}"; rm -f "$PID_FILE"; return
    fi
    local pid; pid=$(cat "$PID_FILE")
    kill "$pid" 2>/dev/null; sleep 1
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
    echo -e "${GREEN}后台测速任务已停止${ENDC}"
}

list_logs() {
    mapfile -t LOG_FILES < <(find "$LOG_DIR" -maxdepth 1 -type f -name '*.log' | sort -r)
    [ ${#LOG_FILES[@]} -eq 0 ] && { echo -e "${YELLOW}暂无日志${ENDC}"; return 1; }
    echo; local i
    for i in "${!LOG_FILES[@]}"; do
        printf '  %02d. %s\n' "$((i+1))" "$(basename "${LOG_FILES[$i]}")"
    done
    echo; return 0
}

list_csvs() {
    mapfile -t CSV_FILES < <(find "$LOG_DIR" -maxdepth 1 -type f -name '*.csv' | sort -r)
    [ ${#CSV_FILES[@]} -eq 0 ] && { echo -e "${YELLOW}暂无CSV${ENDC}"; return 1; }
    echo; local i
    for i in "${!CSV_FILES[@]}"; do
        printf '  %02d. %s\n' "$((i+1))" "$(basename "${CSV_FILES[$i]}")"
    done
    echo; return 0
}

list_reports() {
    mapfile -t REPORT_FILES < <(find "$REPORT_DIR" -maxdepth 1 -type f \
        \( -name '*.html' -o -name '*.txt' -o -name '*.svg' \
           -o -name '*.tar.gz' -o -name '*.csv' \) | sort -r)
    [ ${#REPORT_FILES[@]} -eq 0 ] && { echo -e "${YELLOW}暂无报告${ENDC}"; return 1; }
    echo; local i
    for i in "${!REPORT_FILES[@]}"; do
        printf '  %02d. %s\n' "$((i+1))" "$(basename "${REPORT_FILES[$i]}")"
    done
    echo; return 0
}

view_latest_log() {
    mapfile -t LOG_FILES < <(find "$LOG_DIR" -maxdepth 1 -type f -name '*.log' | sort -r)
    [ ${#LOG_FILES[@]} -eq 0 ] && { echo -e "${YELLOW}暂无日志${ENDC}"; return; }
    sed -n '1,300p' "${LOG_FILES[0]}"
}

view_log_by_menu() {
    list_logs || return
    local choice; read -r -p "选择日志编号: " choice
    [[ ! "$choice" =~ ^[0-9]+$ ]] \
        || (( choice<1 || choice>${#LOG_FILES[@]} )) \
        && { echo -e "${RED}编号无效${ENDC}"; return; }
    sed -n '1,300p' "${LOG_FILES[$((choice-1))]}"
}

build_round_curve_data() {
    local csv_file="$1" out_file="$2"
    awk -F',' '
    function trim(s){gsub(/^[ \t\r\n]+|[ \t\r\n]+$/,"",s);return s}
    NR==1{next}
    { r=trim($2); t=trim($1);
      up=trim($7)+0; us=trim($8); dn=trim($9)+0; ds=trim($10);
      la=trim($11)+0; ji=trim($12)+0;
      if(!(r in rt)) rt[r]=substr(t,12,8);
      if(us=="正常"&&ds=="正常"){
        cnt[r]++; us2[r]+=up; ds2[r]+=dn; ls[r]+=la; js[r]+=ji;
      }
    }
    END{
      print "round,time,avg_upload,avg_download,avg_latency,avg_jitter,count";
      for(r in cnt)
        printf "%d,%s,%.4f,%.4f,%.4f,%.4f,%d\n",
          r,rt[r],us2[r]/cnt[r],ds2[r]/cnt[r],ls[r]/cnt[r],js[r]/cnt[r],cnt[r];
    }' "$csv_file" | sort -t',' -k1,1n > "$out_file"
}

generate_summary_report() {
    local csv_file="$1" out_file="$2"
    awk -F',' '
    function trim(s){gsub(/^[ \t\r\n]+|[ \t\r\n]+$/,"",s);return s}
    BEGIN{total=0;success=0;fail=0;}
    NR==1{next}
    { t=trim($1); r=trim($2); g=trim($3); nd=trim($6);
      up=trim($7)+0; us=trim($8); dn=trim($9)+0; ds=trim($10); la=trim($11)+0;
      total++; rs[r]=1;
      if(st=="") st=t; et=t; gt[g]++;
      if(us=="失败"||ds=="失败"||us=="取消"||ds=="取消") fail++;
      if(us=="正常"&&ds=="正常"){
        success++; go[g]++;
        usum+=up; dsum+=dn; lsum+=la;
        usq+=up*up; dsq+=dn*dn; lsq+=la*la;
        if(bd==""||dn>bdv){bd=g"|"nd; bdv=dn;}
        if(bu==""||up>buv){bu=g"|"nd; buv=up;}
        if(bl==""||la<blv){bl=g"|"nd; blv=la;}
        gus[g]+=up; gds[g]+=dn; gls[g]+=la; gdo[g]++;
      }
    }
    END{
      rn=0; for(r in rs) rn++;
      print "═══════════ HyperSpeed Plus 分析报告 ═══════════";
      print "区间: "st" → "et;
      printf "样本: %d  轮次: %d\n", total, rn;
      printf "双向可用率: %.2f%% (%d/%d)  失败/取消: %d\n",
        total>0?success/total*100:0, success, total, fail;
      if(success>0){
        ua=usum/success; da=dsum/success; la2=lsum/success;
        us2=sqrt((usq/success)-(ua^2)); if(us2<0) us2=0;
        ds2=sqrt((dsq/success)-(da^2)); if(ds2<0) ds2=0;
        ls2=sqrt((lsq/success)-(la2^2)); if(ls2<0) ls2=0;
        print ""; print "━━━━━ 可用样本统计 ━━━━━";
        printf "  平均上传: %7.2f Mbps  (波动 ±%.2f)\n", ua, us2;
        printf "  平均下载: %7.2f Mbps  (波动 ±%.2f)\n", da, ds2;
        printf "  平均延迟: %7.2f ms    (波动 ±%.2f)\n", la2, ls2;
        printf "  峰值上传: %.2f  ← %s\n", buv, bu;
        printf "  峰值下载: %.2f  ← %s\n", bdv, bd;
        printf "  最低延迟: %.2f  ← %s\n", blv, bl;
        if(da>=80&&la2<=160)      print "  综合评估: ★★★ 质量较好";
        else if(da>=40&&la2<=200) print "  综合评估: ★★  线路可用";
        else                      print "  综合评估: ★   线路存在短板";
      }
      print ""; print "━━━━━ 分组统计 ━━━━━";
      for(g in gt){
        r2=(go[g]+0)/gt[g]*100;
        printf "  %-14s %.2f%% (%d/%d)", g, r2, go[g]+0, gt[g];
        if((gdo[g]+0)>0)
          printf "  ↑%.2f ↓%.2f ↕%.2f", gus[g]/gdo[g], gds[g]/gdo[g], gls[g]/gdo[g];
        printf "\n";
      }
      print "═══════════════════════════════════════════════";
    }' "$csv_file" > "$out_file"
}

generate_speed_svg() {
    local data_file="$1" out_svg="$2"
    awk -F',' '
    BEGIN{w=1280;h=480;L=80;R=40;T=40;B=70;pW=w-L-R;pH=h-T-B;n=0;maxV=0;}
    NR==1{next}
    { n++; lb[n]=$2; up[n]=$3+0; dn[n]=$4+0;
      if(up[n]>maxV) maxV=up[n]; if(dn[n]>maxV) maxV=dn[n]; }
    END{
      if(maxV<=0) maxV=1;
      print "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\""w"\" height=\""h"\">";
      print "<rect width=\"100%\" height=\"100%\" fill=\"#0b1220\"/>";
      print "<text x=\"40\" y=\"28\" fill=\"#e5e7eb\" font-size=\"20\">速度曲线 (Mbps)</text>";
      print "<line x1=\""L"\" y1=\""T"\" x2=\""L"\" y2=\""T+pH"\" stroke=\"#94a3b8\" stroke-width=\"1\"/>";
      print "<line x1=\""L"\" y1=\""T+pH"\" x2=\""L+pW"\" y2=\""T+pH"\" stroke=\"#94a3b8\" stroke-width=\"1\"/>";
      for(i=0;i<=4;i++){
        y=T+pH-(pH*i/4); v=maxV*i/4;
        print "<line x1=\""L"\" y1=\""y"\" x2=\""L+pW"\" y2=\""y"\" stroke=\"#1f2937\" stroke-width=\"1\"/>";
        printf "<text x=\"4\" y=\"%.0f\" fill=\"#94a3b8\" font-size=\"11\">%.0f</text>\n",y+4,v;
      }
      if(n==0){print "<text x=\"100\" y=\"240\" fill=\"#fbbf24\" font-size=\"18\">暂无数据</text></svg>";exit;}
      step=(n==1)?0:pW/(n-1); uP=""; dP="";
      for(i=1;i<=n;i++){
        x=L+(i-1)*step; yu=T+pH-(up[i]/maxV*pH); yd=T+pH-(dn[i]/maxV*pH);
        uP=uP sprintf("%.1f,%.1f ",x,yu); dP=dP sprintf("%.1f,%.1f ",x,yd);
        print "<circle cx=\""x"\" cy=\""yu"\" r=\"3\" fill=\"#38bdf8\"/>";
        print "<circle cx=\""x"\" cy=\""yd"\" r=\"3\" fill=\"#22c55e\"/>";
        printf "<text x=\"%.1f\" y=\"%d\" fill=\"#94a3b8\" font-size=\"10\" text-anchor=\"middle\">R%s</text>\n",x,T+pH+18,lb[i];
      }
      print "<polyline fill=\"none\" stroke=\"#38bdf8\" stroke-width=\"2.5\" points=\""uP"\"/>";
      print "<polyline fill=\"none\" stroke=\"#22c55e\" stroke-width=\"2.5\" points=\""dP"\"/>";
      print "<rect x=\"1060\" y=\"14\" width=\"12\" height=\"12\" fill=\"#38bdf8\"/>";
      print "<text x=\"1078\" y=\"25\" fill=\"#e5e7eb\" font-size=\"13\">上传</text>";
      print "<rect x=\"1130\" y=\"14\" width=\"12\" height=\"12\" fill=\"#22c55e\"/>";
      print "<text x=\"1148\" y=\"25\" fill=\"#e5e7eb\" font-size=\"13\">下载</text>";
      print "</svg>";
    }' "$data_file" > "$out_svg"
}

generate_latency_svg() {
    local data_file="$1" out_svg="$2"
    awk -F',' '
    BEGIN{w=1280;h=480;L=80;R=40;T=40;B=70;pW=w-L-R;pH=h-T-B;n=0;maxV=0;}
    NR==1{next}
    { n++; lb[n]=$2; la[n]=$5+0; ji[n]=$6+0;
      if(la[n]>maxV) maxV=la[n]; if(ji[n]>maxV) maxV=ji[n]; }
    END{
      if(maxV<=0) maxV=1;
      print "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\""w"\" height=\""h"\">";
      print "<rect width=\"100%\" height=\"100%\" fill=\"#0f172a\"/>";
      print "<text x=\"40\" y=\"28\" fill=\"#e5e7eb\" font-size=\"20\">延迟曲线 (ms)</text>";
      print "<line x1=\""L"\" y1=\""T"\" x2=\""L"\" y2=\""T+pH"\" stroke=\"#94a3b8\" stroke-width=\"1\"/>";
      print "<line x1=\""L"\" y1=\""T+pH"\" x2=\""L+pW"\" y2=\""T+pH"\" stroke=\"#94a3b8\" stroke-width=\"1\"/>";
      for(i=0;i<=4;i++){
        y=T+pH-(pH*i/4); v=maxV*i/4;
        print "<line x1=\""L"\" y1=\""y"\" x2=\""L+pW"\" y2=\""y"\" stroke=\"#1f2937\" stroke-width=\"1\"/>";
        printf "<text x=\"4\" y=\"%.0f\" fill=\"#94a3b8\" font-size=\"11\">%.0f</text>\n",y+4,v;
      }
      if(n==0){print "<text x=\"100\" y=\"240\" fill=\"#fbbf24\" font-size=\"18\">暂无数据</text></svg>";exit;}
      step=(n==1)?0:pW/(n-1); lP=""; jP="";
      for(i=1;i<=n;i++){
        x=L+(i-1)*step; yl=T+pH-(la[i]/maxV*pH); yj=T+pH-(ji[i]/maxV*pH);
        lP=lP sprintf("%.1f,%.1f ",x,yl); jP=jP sprintf("%.1f,%.1f ",x,yj);
        print "<circle cx=\""x"\" cy=\""yl"\" r=\"3\" fill=\"#f59e0b\"/>";
        print "<circle cx=\""x"\" cy=\""yj"\" r=\"3\" fill=\"#a855f7\"/>";
        printf "<text x=\"%.1f\" y=\"%d\" fill=\"#94a3b8\" font-size=\"10\" text-anchor=\"middle\">R%s</text>\n",x,T+pH+18,lb[i];
      }
      print "<polyline fill=\"none\" stroke=\"#f59e0b\" stroke-width=\"2.5\" points=\""lP"\"/>";
      print "<polyline fill=\"none\" stroke=\"#a855f7\" stroke-width=\"2.5\" points=\""jP"\"/>";
      print "<rect x=\"1060\" y=\"14\" width=\"12\" height=\"12\" fill=\"#f59e0b\"/>";
      print "<text x=\"1078\" y=\"25\" fill=\"#e5e7eb\" font-size=\"13\">延迟</text>";
      print "<rect x=\"1130\" y=\"14\" width=\"12\" height=\"12\" fill=\"#a855f7\"/>";
      print "<text x=\"1148\" y=\"25\" fill=\"#e5e7eb\" font-size=\"13\">抖动</text>";
      print "</svg>";
    }' "$data_file" > "$out_svg"
}

generate_html_report() {
    local summary_file="$1" speed_svg="$2" latency_svg="$3" out_html="$4"
    local sn sp ln
    sn=$(basename "$summary_file")
    sp=$(basename "$speed_svg")
    ln=$(basename "$latency_svg")
    cat > "$out_html" << HTMLEOF
<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="UTF-8"><title>HyperSpeed Plus 报告</title>
<style>body{background:#020617;color:#e5e7eb;font-family:Arial,sans-serif;margin:0;padding:24px}
.wrap{max-width:1320px;margin:0 auto}
.card{background:#111827;border:1px solid #1f2937;border-radius:16px;padding:20px;margin-bottom:20px}
pre{white-space:pre-wrap;line-height:1.7;font-size:14px}
img{width:100%;border-radius:12px;border:1px solid #1f2937}
a{color:#7dd3fc}h1,h2{margin-top:0}</style></head>
<body><div class="wrap">
<div class="card"><h1>HyperSpeed Plus 分析报告</h1>
<p><a href="${sn}">${sn}</a> | <a href="${sp}">${sp}</a> | <a href="${ln}">${ln}</a></p></div>
<div class="card"><h2>分析摘要</h2>
<pre>$(sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g' "$summary_file")</pre></div>
<div class="card"><h2>速度曲线</h2><img src="${sp}" alt="速度曲线"></div>
<div class="card"><h2>延迟曲线</h2><img src="${ln}" alt="延迟曲线"></div>
</div></body></html>
HTMLEOF
}

analyze_csv_file() {
    local csv_file="$1"
    [ -f "$csv_file" ] || { echo -e "${RED}CSV不存在${ENDC}"; return 1; }
    local bn; bn=$(basename "$csv_file" .csv)
    local rd="${REPORT_DIR}/${bn}-rounds.csv"
    local st="${REPORT_DIR}/${bn}-summary.txt"
    local ss="${REPORT_DIR}/${bn}-speed.svg"
    local ls="${REPORT_DIR}/${bn}-latency.svg"
    local rh="${REPORT_DIR}/${bn}-report.html"
    build_round_curve_data  "$csv_file" "$rd"
    generate_summary_report "$csv_file" "$st"
    generate_speed_svg      "$rd" "$ss"
    generate_latency_svg    "$rd" "$ls"
    generate_html_report    "$st" "$ss" "$ls" "$rh"
    sed -n '1,220p' "$st"; echo
    echo -e "${GREEN}速度曲线:${ENDC} $ss"
    echo -e "${GREEN}延迟曲线:${ENDC} $ls"
    echo -e "${GREEN}HTML报告:${ENDC} $rh"
}

analyze_latest_csv() {
    mapfile -t CSV_FILES < <(find "$LOG_DIR" -maxdepth 1 -type f -name '*.csv' | sort -r)
    [ ${#CSV_FILES[@]} -eq 0 ] && { echo -e "${YELLOW}暂无CSV${ENDC}"; return; }
    analyze_csv_file "${CSV_FILES[0]}"
}

analyze_csv_by_menu() {
    list_csvs || return
    local choice; read -r -p "选择CSV编号: " choice
    [[ ! "$choice" =~ ^[0-9]+$ ]] \
        || (( choice<1 || choice>${#CSV_FILES[@]} )) \
        && { echo -e "${RED}编号无效${ENDC}"; return; }
    analyze_csv_file "${CSV_FILES[$((choice-1))]}"
}

pack_latest_report() {
    mapfile -t HTMLS < <(find "$REPORT_DIR" -maxdepth 1 -type f -name '*-report.html' | sort -r)
    [ ${#HTMLS[@]} -eq 0 ] && { echo -e "${YELLOW}暂无报告，请先执行分析${ENDC}"; return 1; }
    local html base tarfile
    html="${HTMLS[0]}"
    base=$(basename "$html" -report.html)
    tarfile="${REPORT_DIR}/${base}-pack.tar.gz"
    tar -C "$REPORT_DIR" -czf "$tarfile" \
        "${base}-report.html" "${base}-summary.txt" \
        "${base}-speed.svg"   "${base}-latency.svg" \
        "${base}-rounds.csv"  2>/dev/null
    echo "$tarfile"
}

upload_latest_report() {
    local tarfile method result
    tarfile=$(pack_latest_report) || return
    echo "准备上传: $tarfile"
    echo "1. Catbox  2. transfer.sh  3. tmpfiles.org"
    read -r -p "选择上传方式(默认1): " method; method="${method:-1}"
    case "$method" in
        1) result=$(curl -fsSL \
               -F "reqtype=fileupload" \
               -F "fileToUpload=@${tarfile}" \
               https://catbox.moe/user/api.php) ;;
        2) result=$(curl -fsSL --upload-file "$tarfile" \
               "https://transfer.sh/$(basename "$tarfile")") ;;
        3) result=$(curl -fsSL -F "file=@${tarfile}" \
               https://tmpfiles.org/api/v1/upload) ;;
        *) echo -e "${RED}无效选项${ENDC}"; return ;;
    esac
    echo -e "${GREEN}上传完成:${ENDC} $result"
}

main_menu() {
    while true; do
        print_banner
        echo "  1.  前台开始测速"
        echo "  2.  后台守护开始测速"
        echo "  3.  查看后台任务状态"
        echo "  4.  停止后台任务"
        echo "  5.  日志列表"
        echo "  6.  查看最新日志"
        echo "  7.  查看指定日志"
        echo "  8.  分析最新CSV并生成曲线"
        echo "  9.  选择CSV做分析并生成曲线"
        echo "  10. 报告文件列表"
        echo "  11. 上传最新报告并生成下载链接"
        echo "  0.  退出"
        echo
        read -r -p "请选择: " menu
        case "$menu" in
            1)  start_foreground_task;  pause_screen ;;
            2)  start_background_task;  pause_screen ;;
            3)  show_status;            pause_screen ;;
            4)  stop_background_task;   pause_screen ;;
            5)  list_logs;              pause_screen ;;
            6)  view_latest_log;        pause_screen ;;
            7)  view_log_by_menu;       pause_screen ;;
            8)  analyze_latest_csv;     pause_screen ;;
            9)  analyze_csv_by_menu;    pause_screen ;;
            10) list_reports;           pause_screen ;;
            11) upload_latest_report;   pause_screen ;;
            0)  exit 0 ;;
            *)  echo -e "${RED}无效选项${ENDC}"; sleep 1 ;;
        esac
    done
}

check_dependencies
main_menu
