#!/usr/bin/env bash
set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
ENDC='\033[0m'

SCRIPT_NAME='HyperSpeed Plus'
SCRIPT_VERSION='6.5.0'
BASE_DIR="${HOME}/.hyperspeed-plus"
LOG_DIR="${BASE_DIR}/logs"
WORK_DIR="${BASE_DIR}/tmp"
REPORT_DIR="${BASE_DIR}/reports"
RUN_DIR="${BASE_DIR}/run"
BIN_DIR="${BASE_DIR}/bin"
WORKER_SCRIPT="${RUN_DIR}/worker.sh"
BINARY="${WORK_DIR}/bimc"
THREAD_FLAG=''

PID_FILE="${RUN_DIR}/hyperspeed.pid"
TASK_FILE="${RUN_DIR}/task.env"
DAEMON_STDOUT="${RUN_DIR}/daemon.out"
LAST_LOG_FILE="${RUN_DIR}/last_log_path"
LAST_CSV_FILE="${RUN_DIR}/last_csv_path"

ECS_CLI_DIR="/root/speedtest-cli"
SERVER_BASE_URL="https://raw.githubusercontent.com/spiritLHLS/speedtest.net-CN-ID/main"
BrowserUA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.74 Safari/537.36"
Speedtest_Go_version="1.6.12"
cdn_success_url=""
cdn_urls=("https://cdn0.spiritlhl.top/" "http://cdn1.spiritlhl.net/" "http://cdn2.spiritlhl.net/" "http://cdn3.spiritlhl.net/" "http://cdn4.spiritlhl.net/")

mkdir -p "$LOG_DIR" "$WORK_DIR" "$REPORT_DIR" "$RUN_DIR" "$BIN_DIR"

NODES=(
'bimc|电信|上海|电信||aHR0cDovL3NwZWVkdGVzdDEub25saW5lLnNoLmNuOjgwODAvZG93bmxvYWQK|aHR0cDovL3NwZWVkdGVzdDEub25saW5lLnNoLmNuOjgwODAvdXBsb2FkCg=='
'bimc|电信|江苏镇江5G|电信||aHR0cDovLzVnemhlbmppYW5nLnNwZWVkdGVzdC5qc2luZm8ubmV0OjgwODAvZG93bmxvYWQ=|aHR0cDovLzVnemhlbmppYW5nLnNwZWVkdGVzdC5qc2luZm8ubmV0OjgwODAvdXBsb2Fk'
'bimc|电信|江苏南京5G|电信||aHR0cDovLzVnbmFuamluZy5zcGVlZHRlc3QuanNpbmZvLm5ldDo4MDgwL2Rvd25sb2FkCg==|aHR0cDovLzVnbmFuamluZy5zcGVlZHRlc3QuanNpbmZvLm5ldDo4MDgwL3VwbG9hZAo='
'bimc|港澳台日韩|环电宽频|香港||aHR0cDovL29va2xhLWhpZGMuaGdjb25haXIuaGdjLmNvbS5oazo4MDgwL2Rvd25sb2FkCg==|aHR0cDovL29va2xhLWhpZGMuaGdjb25haXIuaGdjLmNvbS5oazo4MDgwL3VwbG9hZAo='
'bimc|港澳台日韩|中华电信|台北||aHR0cDovL3RwMS5jaHRtLmhpbmV0Lm5ldDo4MDgwL2Rvd25sb2FkCg==|aHR0cDovL3RwMS5jaHRtLmhpbmV0Lm5ldDo4MDgwL3VwbG9hZAo='
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
    if [ ${#missing[@]} -gt 0 ]; then echo -e "${RED}缺少依赖: ${missing[*]}${ENDC}"; exit 1; fi
}

prepare_bimc() {
    if [ ! -x "$BINARY" ]; then
        local arch; arch=$(uname -m)
        echo -e "${CYAN}正在获取 bimc 组件...${ENDC}"
        download_file "https://bench.im/bimc-${arch}" "$BINARY" || { echo -e "${RED}bimc 下载失败${ENDC}"; exit 1; }
        chmod +x "$BINARY"
    fi
}

print_banner() {
    clear
    echo "—————————————————————— ${SCRIPT_NAME} ${SCRIPT_VERSION} ——————————————————————"
    echo "  长时压力测速 | 后台守护 | 随机间隔 | 曲线分析 | 报告上传"
    echo "  日志目录: ${LOG_DIR}"
    echo "  报告目录: ${REPORT_DIR}"
    echo "——————————————————————————————————————————————————————————————————————————————"
}

pause_screen() { read -r -p "按回车继续..." _; }
is_number() { [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]; }
decode_b64() { printf '%s' "$1" | base64 -d 2>/dev/null | tr -d '\r\n'; }

random_wait_seconds() {
    local max="$1"
    if (( max <= 1 )); then echo 1; return; fi
    if command_exists shuf; then shuf -i 1-"$max" -n 1
    else echo $(( RANDOM % max + 1 )); fi
}

# ── CDN / ookla 工具 ──────────────────────────────────────────────────────────

ecs_check_cdn() {
    local o_url="$1"
    local shuffled
    if command_exists shuf; then
        shuffled=($(shuf -e "${cdn_urls[@]}"))
    else
        shuffled=("${cdn_urls[@]}")
    fi
    for cdn_url in "${shuffled[@]}"; do
        if curl -sL -k "${cdn_url}${o_url}" --max-time 6 2>/dev/null | grep -q "success"; then
            cdn_success_url="$cdn_url"; return
        fi
        sleep 0.5
    done
    cdn_success_url=""
}

ecs_check_cdn_file() {
    [ -n "$cdn_success_url" ] && return
    ecs_check_cdn "https://raw.githubusercontent.com/spiritLHLS/ecs/main/back/test"
    if [ -n "$cdn_success_url" ]; then
        echo -e "${CYAN}CDN 可用${ENDC}"
    else
        echo -e "${YELLOW}CDN 不可用，直连 GitHub${ENDC}"
    fi
}

ecs_install_speedtest() {
    [ -f "${ECS_CLI_DIR}/speedtest" ] || [ -f "${ECS_CLI_DIR}/speedtest-go" ] && return 0
    local sysarch; sysarch=$(uname -m)
    local sys_bit
    case "${sysarch}" in
        x86_64|x86|amd64|x64) sys_bit="x86_64" ;;
        i386|i686)             sys_bit="i386" ;;
        aarch64|armv7l|armv8|armv8l) sys_bit="aarch64" ;;
        s390x)   sys_bit="s390x"   ;;
        riscv64) sys_bit="riscv64" ;;
        ppc64le) sys_bit="ppc64le" ;;
        ppc64)   sys_bit="ppc64"   ;;
        *)       sys_bit="x86_64"  ;;
    esac
    mkdir -p "${ECS_CLI_DIR}"
    cd /root || return 1
    echo -e "${CYAN}下载 speedtest 工具 (${sys_bit})...${ENDC}"
    local installed=0
    # 优先安装 speedtest-go（无需许可证，后台更稳定）
    local go_bit="$sys_bit"; [ "$go_bit" = "aarch64" ] && go_bit="arm64"
    local url_go="https://github.com/showwin/speedtest-go/releases/download/v${Speedtest_Go_version}/speedtest-go_${Speedtest_Go_version}_Linux_${go_bit}.tar.gz"
    curl --fail -sL -m 30 -o /root/speedtest.tar.gz "${url_go}" 2>/dev/null
    if [ -f "/root/speedtest.tar.gz" ] && tar -tzf /root/speedtest.tar.gz >/dev/null 2>&1; then
        tar -zxf /root/speedtest.tar.gz -C "${ECS_CLI_DIR}" 2>/dev/null
        rm -f /root/speedtest.tar.gz
        [ -f "${ECS_CLI_DIR}/speedtest-go" ] && chmod 777 "${ECS_CLI_DIR}/speedtest-go" && installed=1
    fi
    if (( installed == 0 )); then
        # fallback: ookla 官方 CLI
        local url1="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${sys_bit}.tgz"
        local url2="https://dl.lamp.sh/files/ookla-speedtest-1.2.0-linux-${sys_bit}.tgz"
        curl --fail -sL -m 20 -o /root/speedtest.tgz "${url1}" 2>/dev/null || \
            curl --fail -sL -m 20 -o /root/speedtest.tgz "${url2}" 2>/dev/null
        if [ -f "/root/speedtest.tgz" ]; then
            tar -zxf /root/speedtest.tgz -C "${ECS_CLI_DIR}" 2>/dev/null
            rm -f /root/speedtest.tgz
            if [ -f "${ECS_CLI_DIR}/speedtest" ]; then
                chmod 777 "${ECS_CLI_DIR}/speedtest"
                installed=1
                # 预先接受许可证，避免后台运行时交互提示
                echo -e "${CYAN}预接受 ookla 许可证...${ENDC}"
                "${ECS_CLI_DIR}/speedtest" --accept-license --accept-gdpr --progress=no \
                    </dev/null >/dev/null 2>&1 || true
            fi
        fi
    fi
    if (( installed == 0 )); then
        echo -e "${RED}speedtest 工具安装失败${ENDC}"; return 1
    fi
    echo -e "${GREEN}speedtest 工具安装完成${ENDC}"; return 0
}

# ── ookla 统一测速函数（前台+后台 worker 共用逻辑）──────────────────────────
# 返回: "upload|download|latency|pkt_loss"  失败时返回 "0|0|0|NULL"
_ookla_run_test() {
    local server_id="$1"
    local log_f="${ECS_CLI_DIR}/speedtest_run.log"
    local upload="" download="" latency="" pkt_loss=""

    # 优先使用 speedtest-go（更稳定，无许可证问题）
    if [ -f "${ECS_CLI_DIR}/speedtest-go" ]; then
        local args_go=(--ua="${BrowserUA}")
        [ -n "$server_id" ] && args_go+=(--server="$server_id")
        "${ECS_CLI_DIR}/speedtest-go" "${args_go[@]}" </dev/null >"$log_f" 2>&1
        upload=$(grep -oP 'Upload:\s+\K[\d.]+' "$log_f" | head -1)
        download=$(grep -oP 'Download:\s+\K[\d.]+' "$log_f" | head -1)
        latency=$(grep -oP 'Latency:\s+\K[\d.]+' "$log_f" | head -1)
        pkt_loss="NULL"
        # speedtest-go 指定 server 失败则重试不指定
        if [[ -z "$upload" || "$upload" == "0" ]] && [ -n "$server_id" ]; then
            "${ECS_CLI_DIR}/speedtest-go" --ua="${BrowserUA}" </dev/null >"$log_f" 2>&1
            upload=$(grep -oP 'Upload:\s+\K[\d.]+' "$log_f" | head -1)
            download=$(grep -oP 'Download:\s+\K[\d.]+' "$log_f" | head -1)
            latency=$(grep -oP 'Latency:\s+\K[\d.]+' "$log_f" | head -1)
        fi
    elif [ -f "${ECS_CLI_DIR}/speedtest" ]; then
        local args_ok=(--progress=no --accept-license --accept-gdpr --format=human-readable)
        [ -n "$server_id" ] && args_ok+=(-s "$server_id")
        # </dev/null 解决后台无 TTY 时卡住问题；不判断退出码，直接解析输出
        "${ECS_CLI_DIR}/speedtest" "${args_ok[@]}" </dev/null >"$log_f" 2>&1
        upload=$(grep -oP '(?:Upload|upload):\s+\K[\d.]+' "$log_f" | head -1)
        download=$(grep -oP '(?:Download|download):\s+\K[\d.]+' "$log_f" | head -1)
        latency=$(grep -oP '(?:Idle )?Latency:\s+\K[\d.]+' "$log_f" | head -1)
        pkt_loss=$(awk -F':\s*' '/Packet Loss/{v=$2; gsub(/[[:space:]%]/,"",v); print (v==""||v=="Notavailable.")?"NULL":v"%"}' "$log_f")
        # ookla 指定 server 失败则重试不指定
        if [[ -z "$upload" || "$upload" == "0" ]] && [ -n "$server_id" ]; then
            "${ECS_CLI_DIR}/speedtest" --progress=no --accept-license --accept-gdpr \
                --format=human-readable </dev/null >"$log_f" 2>&1
            upload=$(grep -oP '(?:Upload|upload):\s+\K[\d.]+' "$log_f" | head -1)
            download=$(grep -oP '(?:Download|download):\s+\K[\d.]+' "$log_f" | head -1)
            latency=$(grep -oP '(?:Idle )?Latency:\s+\K[\d.]+' "$log_f" | head -1)
        fi
    fi

    upload="${upload:-0}"; download="${download:-0}"
    latency="${latency:-0}"; pkt_loss="${pkt_loss:-NULL}"
    echo "${upload}|${download}|${latency}|${pkt_loss}"
}

ecs_get_data() {
    local url="$1"; local data=(); local response; local retries=0
    while (( retries < 3 )); do
        response=$(curl -sL --max-time 5 "$url" 2>/dev/null) && break
        retries=$((retries+1)); sleep 1
    done
    (( retries >= 3 )) && [ -n "$cdn_success_url" ] && \
        response=$(curl -sL --max-time 8 "${cdn_success_url}${url}" 2>/dev/null)
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local id; id=$(echo "$line" | awk -F',' '{print $1}')
        local city; city=$(echo "$line" | sed 's/ //g' | awk -F',' '{print $4}')
        [[ "$id,$city" == "id,city" ]] && continue
        [[ "$url" == *"Mobile"*  ]] && city="移动${city}"
        [[ "$url" == *"Telecom"* ]] && city="电信${city}"
        [[ "$url" == *"Unicom"*  ]] && city="联通${city}"
        data+=("$id,$city")
    done <<< "$response"
    echo "${data[@]}"
}

ecs_ping_test() {
    local ip="$1"
    local result; result=$(ping -c1 -W3 "$ip" 2>/dev/null | awk -F'/' 'END{print $5}')
    echo "$ip,$result"
}

ecs_get_nearest_data() {
    local url="$1"; local data=(); local response; local retries=0
    while (( retries < 2 )); do
        response=$(curl -sL --max-time 4 "$url" 2>/dev/null) && break
        retries=$((retries+1)); sleep 1
    done
    [ -z "$response" ] && [ -n "$cdn_success_url" ] && \
        response=$(curl -sL --max-time 8 "${cdn_success_url}${url}" 2>/dev/null)
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local id; id=$(echo "$line" | awk -F',' '{print $1}')
        local city; city=$(echo "$line" | sed 's/ //g' | awk -F',' '{print $4}')
        local ip; ip=$(echo "$line" | awk -F',' '{print $5}')
        [[ "$id,$city,$ip" == "id,city,ip" ]] && continue
        [[ "$url" == *"Mobile"*  ]] && city="移动${city}"
        [[ "$url" == *"Telecom"* ]] && city="电信${city}"
        [[ "$url" == *"Unicom"*  ]] && city="联通${city}"
        data+=("$id,$city,$ip")
    done <<< "$response"
    [ ${#data[@]} -eq 0 ] && return 1
    local pingname; pingname=$(basename "$url" | cut -d'.' -f1)
    local tmp_dir; tmp_dir=$(mktemp -d)
    for ((i=0;i<${#data[@]};i++)); do
        { local ip2; ip2=$(echo "${data[$i]}" | awk -F',' '{print $3}')
          ecs_ping_test "$ip2" > "$tmp_dir/$i"; } &
    done
    wait
    local tmp_file="/tmp/pingtest_hs_${pingname}"
    rm -f "$tmp_file"
    for idx in $(seq 0 $((${#data[@]}-1))); do cat "$tmp_dir/$idx" 2>/dev/null; done > "$tmp_file"
    rm -rf "$tmp_dir"
    local sorted; sorted=$(awk -F',' 'NF>=2 && $2!=""' "$tmp_file" | sort -t',' -k2 -n)
    rm -f "$tmp_file"
    local lines=(); IFS=$'\n' read -rd '' -a lines <<< "$sorted"
    local results=()
    for line in "${lines[@]}"; do
        local field; field=$(echo "$line" | cut -d',' -f1)
        [[ -n "$field" ]] && results+=("$field")
    done
    local sorted_data=()
    for result in "${results[@]}"; do
        for item in "${data[@]}"; do
            [[ "$(echo "$item" | cut -d',' -f3)" == "$result" ]] && \
                sorted_data+=("$(echo "$item"|cut -d',' -f1),$(echo "$item"|cut -d',' -f2)")
        done
    done
    echo "${sorted_data[0]:-}"
}

# ── 参数配置 ──────────────────────────────────────────────────────────────────

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

# ── 节点选择 ──────────────────────────────────────────────────────────────────

show_nodes() {
    echo
    echo "可选测试地区/节点 (bimc 高精度节点):"
    local i entry tool group location isp
    for i in "${!NODES[@]}"; do
        entry="${NODES[$i]}"
        IFS='|' read -r tool group location isp _ _ _ <<< "$entry"
        printf '  %02d. [%-5s] %-12s %-14s (%s)\n' "$((i+1))" "$tool" "$group" "$location" "$isp"
    done
    echo
    echo "  --- 动态加载最优单节点 (ookla, 延迟最低1个) ---"
    echo "  a.联通  b.电信  c.移动  d.香港  e.台湾  f.日本  g.新加坡"
    echo "  n.三网就近(联通+电信+移动 各1个)"
    echo
    echo "输入示例: 1,2,a,b  |  all=全选(bimc+ookla各1)  |  ecs=三网就近各1"
}

select_nodes() {
    local input
    SELECTED_IDS=()
    show_nodes

    _load_best_one() {
        local url="$1" gname="$2"
        echo -e "${CYAN}正在探测 ${gname} 最优节点...${ENDC}"
        local best
        best=$(ecs_get_nearest_data "$url")
        if [ -z "$best" ]; then
            echo -e "${YELLOW}${gname} ping 探测失败，改用列表第一个节点${ENDC}"
            local all_list=()
            all_list=($(ecs_get_data "$url"))
            best="${all_list[0]:-}"
        fi
        if [ -z "$best" ]; then
            echo -e "${YELLOW}${gname} 节点拉取失败，跳过${ENDC}"; return
        fi
        local sid; sid=$(echo "$best" | cut -d',' -f1)
        local loc; loc=$(echo "$best" | cut -d',' -f2)
        NODES+=("ookla|${gname}|${loc}|speedtest|${sid}||")
        SELECTED_IDS+=("${#NODES[@]}")
        echo -e "${GREEN}  ✓ ${gname}: ${loc} (ID:${sid})${ENDC}"
    }

    _dispatch_letter() {
        case "$1" in
            a) _load_best_one "${SERVER_BASE_URL}/CN_Unicom.csv"  "联通" ;;
            b) _load_best_one "${SERVER_BASE_URL}/CN_Telecom.csv" "电信" ;;
            c) _load_best_one "${SERVER_BASE_URL}/CN_Mobile.csv"  "移动" ;;
            d) _load_best_one "${SERVER_BASE_URL}/HK.csv"         "香港" ;;
            e) _load_best_one "${SERVER_BASE_URL}/TW.csv"         "台湾" ;;
            f) _load_best_one "${SERVER_BASE_URL}/JP.csv"         "日本" ;;
            g) _load_best_one "${SERVER_BASE_URL}/SG.csv"         "新加坡" ;;
            n) _load_best_one "${SERVER_BASE_URL}/CN_Unicom.csv"  "联通"
               _load_best_one "${SERVER_BASE_URL}/CN_Telecom.csv" "电信"
               _load_best_one "${SERVER_BASE_URL}/CN_Mobile.csv"  "移动" ;;
            *) echo -e "${RED}未知字母: $1${ENDC}" ;;
        esac
    }

    while true; do
        read -r -p "请选择测试节点: " input
        input="${input// /}"

        if [[ -z "$input" || "$input" == "all" ]]; then
            for token in "${!NODES[@]}"; do SELECTED_IDS+=("$((token+1))"); done
            ecs_check_cdn_file
            for _al in a b c d e f g; do _dispatch_letter "$_al"; done
            break
        fi

        if [[ "$input" == "ecs" ]]; then
            ecs_check_cdn_file
            _dispatch_letter "n"
            [ ${#SELECTED_IDS[@]} -gt 0 ] && break
            echo -e "${RED}节点加载失败，请重试${ENDC}"; continue
        fi

        IFS=',' read -r -a TOKENS <<< "$input"
        local valid=1
        for token in "${TOKENS[@]}"; do
            [[ -n "$token" ]] || { valid=0; break; }
            if [[ "$token" =~ ^[0-9]+$ ]]; then
                local tn=$((10#$token))
                (( tn < 1 || tn > ${#NODES[@]} )) && { valid=0; break; }
            elif [[ "$token" =~ ^[abcdefgn]$ ]]; then
                :
            else
                valid=0; break
            fi
        done
        if (( valid == 0 )); then
            echo -e "${RED}输入无效，请重新输入（数字=bimc 字母=ookla最优节点）${ENDC}"; continue
        fi

        local cdn_checked=0
        local letter_done=()
        for token in "${TOKENS[@]}"; do
            [[ "$token" =~ ^[abcdefgn]$ ]] || continue
            array_contains "$token" "${letter_done[@]}" && continue
            (( cdn_checked == 0 )) && { ecs_check_cdn_file; cdn_checked=1; }
            _dispatch_letter "$token"
            letter_done+=("$token")
        done
        for token in "${TOKENS[@]}"; do
            [[ "$token" =~ ^[0-9]+$ ]] || continue
            local tn=$((10#$token))
            array_contains "$tn" "${SELECTED_IDS[@]}" || SELECTED_IDS+=("$tn")
        done

        [ ${#SELECTED_IDS[@]} -gt 0 ] && break
        echo -e "${RED}未选择任何节点，请重新输入${ENDC}"
    done

    local has_ookla=0
    for id in "${SELECTED_IDS[@]}"; do
        [[ "${NODES[$((id-1))]}" == ookla* ]] && { has_ookla=1; break; }
    done
    (( has_ookla == 1 )) && ecs_install_speedtest

    echo
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━ 已选节点 ━━━━━━━━━━━━━━━━${ENDC}"
    local id entry tool group location
    for id in "${SELECTED_IDS[@]}"; do
        entry="${NODES[$((id-1))]}"; IFS='|' read -r tool group location _ _ _ _ <<< "$entry"
        echo -e "  ${GREEN}✓${ENDC} [${tool}] ${group} — ${location}"
    done
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${ENDC}"
}

# ── 日志 / 测速核心 ───────────────────────────────────────────────────────────

new_log_files() {
    local ts; ts=$(date '+%Y%m%d-%H%M%S')
    LOG_FILE="${LOG_DIR}/hyperspeed-${ts}.log"
    CSV_FILE="${LOG_DIR}/hyperspeed-${ts}.csv"
    printf 'time,round,group,location,isp,node_name,upload_mbps,upload_status,download_mbps,download_status,latency_ms,jitter_ms,packet_loss\n' > "$CSV_FILE"
    echo "$LOG_FILE" > "$LAST_LOG_FILE"
    echo "$CSV_FILE" > "$LAST_CSV_FILE"
}

log_line() {
    printf '%b\n' "$1"
    printf '%b\n' "$2" >> "$LOG_FILE"
}

save_task_env() {
    : > "$TASK_FILE"
    printf 'THREAD_FLAG=%q\n'        "$THREAD_FLAG"        >> "$TASK_FILE"
    printf 'DURATION_SECONDS=%q\n'   "$DURATION_SECONDS"   >> "$TASK_FILE"
    printf 'INTERVAL_SECONDS=%q\n'   "$INTERVAL_SECONDS"   >> "$TASK_FILE"
    printf 'DURATION_HOURS=%q\n'     "$DURATION_HOURS"     >> "$TASK_FILE"
    printf 'INTERVAL_MINUTES=%q\n'   "$INTERVAL_MINUTES"   >> "$TASK_FILE"
    printf 'SELECTED_IDS=(' >> "$TASK_FILE"
    local id; for id in "${SELECTED_IDS[@]}"; do printf '%q ' "$id" >> "$TASK_FILE"; done
    printf ')\n' >> "$TASK_FILE"
    printf 'NODES=(\n' >> "$TASK_FILE"
    local node; for node in "${NODES[@]}"; do printf '%q\n' "$node" >> "$TASK_FILE"; done
    printf ')\n' >> "$TASK_FILE"
}

is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid; pid=$(cat "$PID_FILE" 2>/dev/null)
        [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null && return 0
    fi
    return 1
}

run_single_test() {
    local id="$1" round="$2"
    local entry tool group location isp server_id dl_b64 ul_b64
    local upload up_status download down_status latency jitter pkt_loss now screen plain color

    entry="${NODES[$((id-1))]}"
    IFS='|' read -r tool group location isp server_id dl_b64 ul_b64 <<< "$entry"
    now=$(date '+%F %T')

    if [[ "$tool" == "ookla" ]]; then
        local result
        result=$(_ookla_run_test "$server_id")
        IFS='|' read -r upload download latency pkt_loss <<< "$result"
        jitter="0"
        if [[ "${upload}" != "0" && "${download}" != "0" ]]; then
            up_status="正常"; down_status="正常"; color="$GREEN"
        else
            up_status="失败"; down_status="失败"; color="$RED"
        fi
        screen="${YELLOW}[第${round}轮]${ENDC} ${PURPLE}${group}${ENDC}[ookla]|${GREEN}${location}${ENDC} ${CYAN}↑${upload}Mbps ↓${download}Mbps ↕${latency}ms${ENDC} ${color}丢包:${pkt_loss}${ENDC}"
        plain="[第${round}轮] ${group}[ookla]|${location} ↑${upload}Mbps ↓${download}Mbps ↕${latency}ms 丢包:${pkt_loss}"
    else
        local dl ul node_name output
        dl=$(decode_b64 "$dl_b64"); ul=$(decode_b64 "$ul_b64")
        node_name=$("$BINARY" -n "$location" 2>/dev/null)
        [ -n "$node_name" ] || node_name="$location"
        local cmd=("$BINARY" "$dl" "$ul")
        [ -n "$THREAD_FLAG" ] && cmd+=("$THREAD_FLAG")
        output=$("${cmd[@]}" 2>/dev/null)
        IFS=',' read -r upload up_status download down_status latency jitter <<< "$output"
        upload="${upload:-0}"; up_status="${up_status:-失败}"
        download="${download:-0}"; down_status="${down_status:-失败}"
        latency="${latency:-0}"; jitter="${jitter:-0}"; pkt_loss="NULL"
        location="$node_name"
        color="$GREEN"
        [[ "$up_status" != "正常" || "$down_status" != "正常" ]] && color="$RED"
        screen="${YELLOW}[第${round}轮]${ENDC} ${PURPLE}${group}${ENDC}|${GREEN}${location}${ENDC} ${CYAN}↑${upload}${ENDC} ${color}${up_status}${ENDC} ${CYAN}↓${download}${ENDC} ${color}${down_status}${ENDC} ${CYAN}↕${latency} ϟ${jitter}${ENDC}"
        plain="[第${round}轮] ${group}|${location} ↑${upload} ${up_status} ↓${download} ${down_status} ↕${latency} ϟ${jitter}"
    fi

    log_line "$screen" "$plain"
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$now" "$round" "$group" "$location" "$isp" "$location" \
        "$upload" "$up_status" "$download" "$down_status" \
        "$latency" "$jitter" "$pkt_loss" >> "$CSV_FILE"
}

run_test_plan() {
    new_log_files
    local end_epoch=0 now round=1 sleep_seconds
    (( DURATION_SECONDS > 0 )) && end_epoch=$(( $(date +%s) + DURATION_SECONDS ))
    log_line "${CYAN}开始测试 日志:${LOG_FILE}${ENDC}" "开始测试 日志:${LOG_FILE}"
    while true; do
        log_line "${PURPLE}———— 第 ${round} 轮 ————${ENDC}" "———— 第 ${round} 轮 ————"
        for id in "${SELECTED_IDS[@]}"; do run_single_test "$id" "$round"; sleep 2; done
        (( DURATION_SECONDS == 0 )) && break
        now=$(date +%s); (( now >= end_epoch )) && break
        sleep_seconds=$(random_wait_seconds "$INTERVAL_SECONDS")
        (( now + sleep_seconds > end_epoch )) && sleep_seconds=$(( end_epoch - now ))
        (( sleep_seconds <= 0 )) && break
        log_line "${CYAN}等待 ${sleep_seconds} 秒${ENDC}" "等待 ${sleep_seconds} 秒"
        sleep "$sleep_seconds"; round=$((round+1))
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
ECS_CLI_DIR="/root/speedtest-cli"
BrowserUA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.74 Safari/537.36"
mkdir -p "$LOG_DIR" "$WORK_DIR" "$REPORT_DIR" "$RUN_DIR"

[ -f "$TASK_FILE" ] || { echo "task.env not found"; exit 1; }
source "$TASK_FILE"

decode_b64() { printf '%s' "$1" | base64 -d 2>/dev/null | tr -d '\r\n'; }

random_wait_seconds() {
    local max="$1"
    (( max <= 1 )) && echo 1 && return
    command -v shuf >/dev/null 2>&1 && shuf -i 1-"$max" -n 1 || echo $(( RANDOM % max + 1 ))
}

prepare_bimc() {
    [ -x "$BINARY" ] && return
    local arch; arch=$(uname -m)
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "https://bench.im/bimc-${arch}" -o "$BINARY"
    else
        wget --no-check-certificate -qO "$BINARY" "https://bench.im/bimc-${arch}"
    fi
    chmod +x "$BINARY"
}

_ookla_run_test() {
    local server_id="$1"
    local log_f="${ECS_CLI_DIR}/speedtest_run.log"
    local upload="" download="" latency="" pkt_loss=""

    if [ -f "${ECS_CLI_DIR}/speedtest-go" ]; then
        local args_go=(--ua="${BrowserUA}")
        [ -n "$server_id" ] && args_go+=(--server="$server_id")
        "${ECS_CLI_DIR}/speedtest-go" "${args_go[@]}" </dev/null >"$log_f" 2>&1
        upload=$(grep -oP 'Upload:\s+\K[\d.]+' "$log_f" | head -1)
        download=$(grep -oP 'Download:\s+\K[\d.]+' "$log_f" | head -1)
        latency=$(grep -oP 'Latency:\s+\K[\d.]+' "$log_f" | head -1)
        pkt_loss="NULL"
        if [[ -z "$upload" || "$upload" == "0" ]] && [ -n "$server_id" ]; then
            "${ECS_CLI_DIR}/speedtest-go" --ua="${BrowserUA}" </dev/null >"$log_f" 2>&1
            upload=$(grep -oP 'Upload:\s+\K[\d.]+' "$log_f" | head -1)
            download=$(grep -oP 'Download:\s+\K[\d.]+' "$log_f" | head -1)
            latency=$(grep -oP 'Latency:\s+\K[\d.]+' "$log_f" | head -1)
        fi
    elif [ -f "${ECS_CLI_DIR}/speedtest" ]; then
        local args_ok=(--progress=no --accept-license --accept-gdpr --format=human-readable)
        [ -n "$server_id" ] && args_ok+=(-s "$server_id")
        "${ECS_CLI_DIR}/speedtest" "${args_ok[@]}" </dev/null >"$log_f" 2>&1
        upload=$(grep -oP '(?:Upload|upload):\s+\K[\d.]+' "$log_f" | head -1)
        download=$(grep -oP '(?:Download|download):\s+\K[\d.]+' "$log_f" | head -1)
        latency=$(grep -oP '(?:Idle )?Latency:\s+\K[\d.]+' "$log_f" | head -1)
        pkt_loss=$(awk -F':\s*' '/Packet Loss/{v=$2; gsub(/[[:space:]%]/,"",v); print (v==""||v=="Notavailable.")?"NULL":v"%"}' "$log_f")
        if [[ -z "$upload" || "$upload" == "0" ]] && [ -n "$server_id" ]; then
            "${ECS_CLI_DIR}/speedtest" --progress=no --accept-license --accept-gdpr \
                --format=human-readable </dev/null >"$log_f" 2>&1
            upload=$(grep -oP '(?:Upload|upload):\s+\K[\d.]+' "$log_f" | head -1)
            download=$(grep -oP '(?:Download|download):\s+\K[\d.]+' "$log_f" | head -1)
            latency=$(grep -oP '(?:Idle )?Latency:\s+\K[\d.]+' "$log_f" | head -1)
        fi
    fi

    upload="${upload:-0}"; download="${download:-0}"
    latency="${latency:-0}"; pkt_loss="${pkt_loss:-NULL}"
    echo "${upload}|${download}|${latency}|${pkt_loss}"
}

new_log_files() {
    local ts; ts=$(date '+%Y%m%d-%H%M%S')
    LOG_FILE="${LOG_DIR}/hyperspeed-${ts}.log"
    CSV_FILE="${LOG_DIR}/hyperspeed-${ts}.csv"
    printf 'time,round,group,location,isp,node_name,upload_mbps,upload_status,download_mbps,download_status,latency_ms,jitter_ms,packet_loss\n' > "$CSV_FILE"
    echo "$LOG_FILE" > "$LAST_LOG_FILE"
    echo "$CSV_FILE" > "$LAST_CSV_FILE"
}

log_line() { printf '%b\n' "$1"; printf '%b\n' "$2" >> "$LOG_FILE"; }

run_single_test() {
    local id="$1" round="$2"
    local entry tool group location isp server_id dl_b64 ul_b64
    local upload up_status download down_status latency jitter pkt_loss now plain

    entry="${NODES[$((id-1))]}"
    IFS='|' read -r tool group location isp server_id dl_b64 ul_b64 <<< "$entry"
    now=$(date '+%F %T')

    if [[ "$tool" == "ookla" ]]; then
        local result
        result=$(_ookla_run_test "$server_id")
        IFS='|' read -r upload download latency pkt_loss <<< "$result"
        jitter="0"
        if [[ "${upload}" != "0" && "${download}" != "0" ]]; then
            up_status="正常"; down_status="正常"
        else
            up_status="失败"; down_status="失败"
        fi
        plain="[第${round}轮] ${group}[ookla]|${location} ↑${upload}Mbps ↓${download}Mbps ↕${latency}ms 丢包:${pkt_loss}"
    else
        local dl ul node_name output
        dl=$(decode_b64 "$dl_b64"); ul=$(decode_b64 "$ul_b64")
        node_name=$("$BINARY" -n "$location" 2>/dev/null)
        [ -n "$node_name" ] || node_name="$location"
        local cmd=("$BINARY" "$dl" "$ul")
        [ -n "$THREAD_FLAG" ] && cmd+=("$THREAD_FLAG")
        output=$("${cmd[@]}" 2>/dev/null)
        IFS=',' read -r upload up_status download down_status latency jitter <<< "$output"
        upload="${upload:-0}"; up_status="${up_status:-失败}"
        download="${download:-0}"; down_status="${down_status:-失败}"
        latency="${latency:-0}"; jitter="${jitter:-0}"; pkt_loss="NULL"
        location="$node_name"
        plain="[第${round}轮] ${group}|${location} ↑${upload} ${up_status} ↓${download} ${down_status} ↕${latency} ϟ${jitter}"
    fi

    log_line "$plain" "$plain"
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$now" "$round" "$group" "$location" "$isp" "$location" \
        "$upload" "$up_status" "$download" "$down_status" \
        "$latency" "$jitter" "$pkt_loss" >> "$CSV_FILE"
}

run_test_plan() {
    trap 'rm -f "$PID_FILE"' EXIT
    new_log_files
    local end_epoch=0 now round=1 sleep_seconds
    (( DURATION_SECONDS > 0 )) && end_epoch=$(( $(date +%s) + DURATION_SECONDS ))
    log_line "开始测试 日志:${LOG_FILE}" "开始测试 日志:${LOG_FILE}"
    while true; do
        log_line "———— 第 ${round} 轮 ————" "———— 第 ${round} 轮 ————"
        for id in "${SELECTED_IDS[@]}"; do run_single_test "$id" "$round"; sleep 2; done
        (( DURATION_SECONDS == 0 )) && break
        now=$(date +%s); (( now >= end_epoch )) && break
        sleep_seconds=$(random_wait_seconds "$INTERVAL_SECONDS")
        (( now + sleep_seconds > end_epoch )) && sleep_seconds=$(( end_epoch - now ))
        (( sleep_seconds <= 0 )) && break
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

# ── 前台 / 后台启动 ───────────────────────────────────────────────────────────

start_foreground_task() {
    prepare_bimc
    echo; echo -e "${CYAN}步骤 1/3  线程设置${ENDC}"
    get_thread_option
    echo; echo -e "${CYAN}步骤 2/3  时长设置${ENDC}"
    get_duration_option
    echo; echo -e "${CYAN}步骤 3/3  选择测试节点（选完自动开始）${ENDC}"
    select_nodes
    echo; echo -e "${GREEN}▶ 所有设置完成，测速即将开始...${ENDC}"; sleep 1
    run_test_plan
}

start_background_task() {
    if is_running; then
        echo -e "${YELLOW}已有后台任务运行中，PID: $(cat "$PID_FILE")${ENDC}"; return
    fi
    prepare_bimc
    echo; echo -e "${CYAN}步骤 1/3  线程设置${ENDC}"
    get_thread_option
    echo; echo -e "${CYAN}步骤 2/3  时长设置${ENDC}"
    get_duration_option
    echo; echo -e "${CYAN}步骤 3/3  选择测试节点（选完自动启动后台）${ENDC}"
    select_nodes
    echo; echo -e "${GREEN}▶ 节点选择完成，正在启动后台任务...${ENDC}"
    save_task_env; write_worker_script
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
        echo -e "${RED}后台任务启动失败，错误信息:${ENDC}"
        rm -f "$PID_FILE"
        [ -f "$DAEMON_STDOUT" ] && cat "$DAEMON_STDOUT"
    fi
}

show_status() {
    if is_running; then
        local pid; pid=$(cat "$PID_FILE")
        echo -e "${GREEN}后台测速正在运行${ENDC}"
        ps -p "$pid" -o pid,etime,cmd 2>/dev/null; echo
        [ -f "$LAST_LOG_FILE" ] && echo "当前日志: $(cat "$LAST_LOG_FILE" 2>/dev/null)"
        [ -f "$LAST_CSV_FILE" ] && echo "当前CSV: $(cat "$LAST_CSV_FILE" 2>/dev/null)"
        echo "后台输出: $DAEMON_STDOUT"; echo
        [ -f "$DAEMON_STDOUT" ] && tail -n 20 "$DAEMON_STDOUT"
    else
        echo -e "${YELLOW}当前没有后台测速任务${ENDC}"
        [ -f "$DAEMON_STDOUT" ] && { echo; echo "最近后台输出:"; tail -n 20 "$DAEMON_STDOUT"; }
    fi
}

stop_background_task() {
    if ! is_running; then
        echo -e "${YELLOW}当前没有后台测速任务${ENDC}"; rm -f "$PID_FILE"; return
    fi
    local pid; pid=$(cat "$PID_FILE")
    kill "$pid" 2>/dev/null || true; sleep 1
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
    echo -e "${GREEN}后台测速任务已停止${ENDC}"
}

list_logs() {
    mapfile -t LOG_FILES < <(find "$LOG_DIR" -maxdepth 1 -type f -name '*.log' | sort -r)
    if [ ${#LOG_FILES[@]} -eq 0 ]; then echo -e "${YELLOW}暂无日志${ENDC}"; return 1; fi
    echo; local i
    for i in "${!LOG_FILES[@]}"; do printf '  %02d. %s\n' "$((i+1))" "$(basename "${LOG_FILES[$i]}")"; done
    echo; return 0
}

list_csvs() {
    mapfile -t CSV_FILES < <(find "$LOG_DIR" -maxdepth 1 -type f -name '*.csv' | sort -r)
    if [ ${#CSV_FILES[@]} -eq 0 ]; then echo -e "${YELLOW}暂无CSV${ENDC}"; return 1; fi
    echo; local i
    for i in "${!CSV_FILES[@]}"; do printf '  %02d. %s\n' "$((i+1))" "$(basename "${CSV_FILES[$i]}")"; done
    echo; return 0
}

list_reports() {
    mapfile -t REPORT_FILES < <(find "$REPORT_DIR" -maxdepth 1 -type f \( -name '*.html' -o -name '*.txt' -o -name '*.svg' -o -name '*.tar.gz' -o -name '*.csv' \) | sort -r)
    if [ ${#REPORT_FILES[@]} -eq 0 ]; then echo -e "${YELLOW}暂无报告${ENDC}"; return 1; fi
    echo; local i
    for i in "${!REPORT_FILES[@]}"; do printf '  %02d. %s\n' "$((i+1))" "$(basename "${REPORT_FILES[$i]}")"; done
    echo; return 0
}

view_latest_log() {
    mapfile -t LOG_FILES < <(find "$LOG_DIR" -maxdepth 1 -type f -name '*.log' | sort -r)
    [ ${#LOG_FILES[@]} -eq 0 ] && { echo -e "${YELLOW}暂无日志${ENDC}"; return; }
    sed -n '1,260p' "${LOG_FILES[0]}"
}

view_log_by_menu() {
    list_logs || return
    local choice; read -r -p "选择要查看的日志编号: " choice
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#LOG_FILES[@]} )); then
        echo -e "${RED}编号无效${ENDC}"; return
    fi
    sed -n '1,260p' "${LOG_FILES[$((choice-1))]}"
}

build_round_curve_data() {
    local csv_file="$1" out_file="$2"
    awk -F',' '
    function trim(s){gsub(/^[ \t\r\n]+|[ \t\r\n]+$/,"",s);return s}
    NR==1{next}
    {round=trim($2);time=trim($1);up=trim($7)+0;up_s=trim($8);down=trim($9)+0;down_s=trim($10);lat=trim($11)+0;jit=trim($12)+0;
     if(!(round in rt))rt[round]=substr(time,12,8);
     if(up_s=="正常"&&down_s=="正常"){cnt[round]++;us[round]+=up;ds[round]+=down;ls[round]+=lat;js[round]+=jit;}}
    END{print "round,time,avg_upload,avg_download,avg_latency,avg_jitter,count";
        for(r in cnt)printf "%d,%s,%.4f,%.4f,%.4f,%.4f,%d\n",r,rt[r],us[r]/cnt[r],ds[r]/cnt[r],ls[r]/cnt[r],js[r]/cnt[r],cnt[r];}
    ' "$csv_file" | sort -t',' -k1,1n > "$out_file"
}

generate_summary_report() {
    local csv_file="$1" out_file="$2"
    awk -F',' '
    function trim(s){gsub(/^[ \t\r\n]+|[ \t\r\n]+$/,"",s);return s}
    BEGIN{total=0;success=0;up_ok=0;down_ok=0;fail=0;}
    NR==1{next}
    {time=trim($1);round=trim($2);group=trim($3);node=trim($6);
     up=trim($7)+0;us=trim($8);down=trim($9)+0;ds=trim($10);lat=trim($11)+0;jit=trim($12)+0;
     total++;round_seen[round]=1;if(st=="")st=time;et=time;
     gt[group]++;nk=group"|"node;
     if(us=="正常")up_ok++;if(ds=="正常")down_ok++;
     if(us=="失败"||ds=="失败")fail++;
     if(us=="正常"&&ds=="正常"){success++;go[group]++;
       up_sum+=up;dn_sum+=down;lt_sum+=lat;
       up_sq+=up*up;dn_sq+=down*down;lt_sq+=lat*lat;
       if(bd==""||down>bdv){bd=nk;bdv=down;}if(bu==""||up>buv){bu=nk;buv=up;}if(bl==""||lat<blv){bl=nk;blv=lat;}
       gups[group]+=up;gdns[group]+=down;glts[group]+=lat;gdo[group]++;}}
    END{rounds=0;for(r in round_seen)rounds++;
        print "———————————————— 分析报告 ————————————————";
        print "区间: "st" -> "et;print "样本: "total"  轮次: "rounds;
        printf "双向可用率: %.2f%% (%d/%d)\n",total>0?success/total*100:0,success,total;
        printf "上传/下载/失败: %.2f%%/%.2f%%/%.2f%%\n",total>0?up_ok/total*100:0,total>0?down_ok/total*100:0,total>0?fail/total*100:0;
        if(success>0){
          ua=up_sum/success;da=dn_sum/success;la=lt_sum/success;
          us2=sqrt((up_sq/success)-(ua*ua));if(us2<0)us2=0;
          ds2=sqrt((dn_sq/success)-(da*da));if(ds2<0)ds2=0;
          ls2=sqrt((lt_sq/success)-(la*la));if(ls2<0)ls2=0;
          print "";print "可用样本统计:";
          printf "- 平均上传: %.2f Mbps  波动:%.2f\n",ua,us2;
          printf "- 平均下载: %.2f Mbps  波动:%.2f\n",da,ds2;
          printf "- 平均延迟: %.2f ms    波动:%.2f\n",la,ls2;
          printf "- 峰值上传: %.2f (%s)\n",buv,bu;
          printf "- 峰值下载: %.2f (%s)\n",bdv,bd;
          printf "- 最低延迟: %.2f (%s)\n",blv,bl;
          if(da>=80&&la<=160)print "- 综合: 质量较好";
          else if(da>=40&&la<=200)print "- 综合: 线路可用";
          else print "- 综合: 线路存在短板";}
        print "";print "分组:";
        for(g in gt){r2=(go[g]+0)/gt[g]*100;printf "- %s: %.2f%% (%d/%d)",g,r2,go[g]+0,gt[g];
          if((gdo[g]+0)>0)printf "  ↑%.2f ↓%.2f ↕%.2f",gups[g]/gdo[g],gdns[g]/gdo[g],glts[g]/gdo[g];printf "\n";}
        print "——————————————————————————————————";
    }' "$csv_file" > "$out_file"
}

generate_speed_svg() {
    local data_file="$1" out_svg="$2"
    awk -F',' 'BEGIN{w=1280;h=480;L=80;R=40;T=40;B=70;pW=w-L-R;pH=h-T-B;n=0;maxV=0;}
    NR==1{next}{n++;label[n]=$2;up[n]=$3+0;down[n]=$4+0;if(up[n]>maxV)maxV=up[n];if(down[n]>maxV)maxV=down[n];}
    END{if(maxV<=0)maxV=1;
      print "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\""w"\" height=\""h"\">";
      print "<rect width=\"100%\" height=\"100%\" fill=\"#0b1220\"/>";
      print "<text x=\"40\" y=\"28\" fill=\"#e5e7eb\" font-size=\"20\" font-family=\"Arial\">速度曲线</text>";
      print "<line x1=\""L"\" y1=\""T"\" x2=\""L"\" y2=\""T+pH"\" stroke=\"#94a3b8\" stroke-width=\"1\"/>";
      print "<line x1=\""L"\" y1=\""T+pH"\" x2=\""L+pW"\" y2=\""T+pH"\" stroke=\"#94a3b8\" stroke-width=\"1\"/>";
      for(i=0;i<=4;i++){y=T+pH-(pH*i/4);v=maxV*i/4;
        print "<line x1=\""L"\" y1=\""y"\" x2=\""L+pW"\" y2=\""y"\" stroke=\"#1f2937\" stroke-width=\"1\"/>";
        printf "<text x=\"4\" y=\"%.0f\" fill=\"#94a3b8\" font-size=\"11\">%.0f</text>\n",y+4,v;}
      if(n==0){print "<text x=\"100\" y=\"240\" fill=\"#fbbf24\" font-size=\"18\">暂无数据</text></svg>";exit;}
      step=(n==1)?0:pW/(n-1);uP="";dP="";
      for(i=1;i<=n;i++){x=L+(i-1)*step;yu=T+pH-(up[i]/maxV*pH);yd=T+pH-(down[i]/maxV*pH);
        uP=uP sprintf("%.1f,%.1f ",x,yu);dP=dP sprintf("%.1f,%.1f ",x,yd);
        print "<circle cx=\""x"\" cy=\""yu"\" r=\"3\" fill=\"#38bdf8\"/>";
        print "<circle cx=\""x"\" cy=\""yd"\" r=\"3\" fill=\"#22c55e\"/>";
        printf "<text x=\"%.1f\" y=\"%d\" fill=\"#94a3b8\" font-size=\"10\" text-anchor=\"middle\">%s</text>\n",x,T+pH+18,label[i];}
      print "<polyline fill=\"none\" stroke=\"#38bdf8\" stroke-width=\"2.5\" points=\""uP"\"/>";
      print "<polyline fill=\"none\" stroke=\"#22c55e\" stroke-width=\"2.5\" points=\""dP"\"/>";
      print "<rect x=\"1080\" y=\"14\" width=\"12\" height=\"12\" fill=\"#38bdf8\"/><text x=\"1098\" y=\"25\" fill=\"#e5e7eb\" font-size=\"13\">上传</text>";
      print "<rect x=\"1140\" y=\"14\" width=\"12\" height=\"12\" fill=\"#22c55e\"/><text x=\"1158\" y=\"25\" fill=\"#e5e7eb\" font-size=\"13\">下载</text>";
      print "</svg>";}' "$data_file" > "$out_svg"
}

generate_latency_svg() {
    local data_file="$1" out_svg="$2"
    awk -F',' 'BEGIN{w=1280;h=480;L=80;R=40;T=40;B=70;pW=w-L-R;pH=h-T-B;n=0;maxV=0;}
    NR==1{next}{n++;label[n]=$2;lat[n]=$5+0;jit[n]=$6+0;if(lat[n]>maxV)maxV=lat[n];if(jit[n]>maxV)maxV=jit[n];}
    END{if(maxV<=0)maxV=1;
      print "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\""w"\" height=\""h"\">";
      print "<rect width=\"100%\" height=\"100%\" fill=\"#0f172a\"/>";
      print "<text x=\"40\" y=\"28\" fill=\"#e5e7eb\" font-size=\"20\" font-family=\"Arial\">延迟曲线</text>";
      print "<line x1=\""L"\" y1=\""T"\" x2=\""L"\" y2=\""T+pH"\" stroke=\"#94a3b8\" stroke-width=\"1\"/>";
      print "<line x1=\""L"\" y1=\""T+pH"\" x2=\""L+pW"\" y2=\""T+pH"\" stroke=\"#94a3b8\" stroke-width=\"1\"/>";
      for(i=0;i<=4;i++){y=T+pH-(pH*i/4);v=maxV*i/4;
        print "<line x1=\""L"\" y1=\""y"\" x2=\""L+pW"\" y2=\""y"\" stroke=\"#1f2937\" stroke-width=\"1\"/>";
        printf "<text x=\"4\" y=\"%.0f\" fill=\"#94a3b8\" font-size=\"11\">%.0f</text>\n",y+4,v;}
      if(n==0){print "<text x=\"100\" y=\"240\" fill=\"#fbbf24\" font-size=\"18\">暂无数据</text></svg>";exit;}
      step=(n==1)?0:pW/(n-1);lP="";jP="";
      for(i=1;i<=n;i++){x=L+(i-1)*step;yl=T+pH-(lat[i]/maxV*pH);yj=T+pH-(jit[i]/maxV*pH);
        lP=lP sprintf("%.1f,%.1f ",x,yl);jP=jP sprintf("%.1f,%.1f ",x,yj);
        print "<circle cx=\""x"\" cy=\""yl"\" r=\"3\" fill=\"#f59e0b\"/>";
        print "<circle cx=\""x"\" cy=\""yj"\" r=\"3\" fill=\"#a855f7\"/>";
        printf "<text x=\"%.1f\" y=\"%d\" fill=\"#94a3b8\" font-size=\"10\" text-anchor=\"middle\">%s</text>\n",x,T+pH+18,label[i];}
      print "<polyline fill=\"none\" stroke=\"#f59e0b\" stroke-width=\"2.5\" points=\""lP"\"/>";
      print "<polyline fill=\"none\" stroke=\"#a855f7\" stroke-width=\"2.5\" points=\""jP"\"/>";
      print "<rect x=\"1080\" y=\"14\" width=\"12\" height=\"12\" fill=\"#f59e0b\"/><text x=\"1098\" y=\"25\" fill=\"#e5e7eb\" font-size=\"13\">延迟</text>";
      print "<rect x=\"1140\" y=\"14\" width=\"12\" height=\"12\" fill=\"#a855f7\"/><text x=\"1158\" y=\"25\" fill=\"#e5e7eb\" font-size=\"13\">抖动</text>";
      print "</svg>";}' "$data_file" > "$out_svg"
}

generate_html_report() {
    local summary_file="$1" speed_svg="$2" latency_svg="$3" out_html="$4"
    local sn sp ln
    sn=$(basename "$summary_file"); sp=$(basename "$speed_svg"); ln=$(basename "$latency_svg")
    cat > "$out_html" << HTMLEOF
<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="UTF-8"><title>HyperSpeed Plus 报告</title>
<style>body{background:#020617;color:#e5e7eb;font-family:Arial,sans-serif;margin:0;padding:24px}.wrap{max-width:1320px;margin:0 auto}.card{background:#111827;border:1px solid #1f2937;border-radius:16px;padding:20px;margin-bottom:20px}pre{white-space:pre-wrap;line-height:1.7;font-size:14px}img{width:100%;border-radius:12px;border:1px solid #1f2937}a{color:#7dd3fc}h1,h2{margin-top:0}</style></head>
<body><div class="wrap">
<div class="card"><h1>HyperSpeed Plus 分析报告</h1><p><a href="${sn}">${sn}</a> | <a href="${sp}">${sp}</a> | <a href="${ln}">${ln}</a></p></div>
<div class="card"><h2>分析摘要</h2><pre>$(sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$summary_file")</pre></div>
<div class="card"><h2>速度曲线</h2><img src="${sp}" alt="速度曲线"></div>
<div class="card"><h2>延迟曲线</h2><img src="${ln}" alt="延迟曲线"></div>
</div></body></html>
HTMLEOF
}

analyze_csv_file() {
    local csv_file="$1"
    [ -f "$csv_file" ] || { echo -e "${RED}CSV不存在${ENDC}"; return 1; }
    local base_name; base_name=$(basename "$csv_file" .csv)
    local round_data="${REPORT_DIR}/${base_name}-rounds.csv"
    local summary_txt="${REPORT_DIR}/${base_name}-summary.txt"
    local speed_svg="${REPORT_DIR}/${base_name}-speed.svg"
    local latency_svg="${REPORT_DIR}/${base_name}-latency.svg"
    local report_html="${REPORT_DIR}/${base_name}-report.html"
    build_round_curve_data "$csv_file" "$round_data"
    generate_summary_report "$csv_file" "$summary_txt"
    generate_speed_svg "$round_data" "$speed_svg"
    generate_latency_svg "$round_data" "$latency_svg"
    generate_html_report "$summary_txt" "$speed_svg" "$latency_svg" "$report_html"
    sed -n '1,220p' "$summary_txt"; echo
    echo -e "${GREEN}速度曲线:${ENDC} $speed_svg"
    echo -e "${GREEN}延迟曲线:${ENDC} $latency_svg"
    echo -e "${GREEN}HTML报告:${ENDC} $report_html"
}

analyze_latest_csv() {
    mapfile -t CSV_FILES < <(find "$LOG_DIR" -maxdepth 1 -type f -name '*.csv' | sort -r)
    [ ${#CSV_FILES[@]} -eq 0 ] && { echo -e "${YELLOW}暂无CSV${ENDC}"; return; }
    analyze_csv_file "${CSV_FILES[0]}"
}

analyze_csv_by_menu() {
    list_csvs || return
    local choice; read -r -p "选择CSV编号: " choice
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#CSV_FILES[@]} )); then
        echo -e "${RED}编号无效${ENDC}"; return
    fi
    analyze_csv_file "${CSV_FILES[$((choice-1))]}"
}

pack_latest_report() {
    mapfile -t HTMLS < <(find "$REPORT_DIR" -maxdepth 1 -type f -name '*-report.html' | sort -r)
    if [ ${#HTMLS[@]} -eq 0 ]; then echo -e "${YELLOW}暂无报告，请先执行分析${ENDC}"; return 1; fi
    local html base tarfile
    html="${HTMLS[0]}"; base=$(basename "$html" -report.html)
    tarfile="${REPORT_DIR}/${base}-pack.tar.gz"
    tar -C "$REPORT_DIR" -czf "$tarfile" "${base}-report.html" "${base}-summary.txt" "${base}-speed.svg" "${base}-latency.svg" "${base}-rounds.csv" 2>/dev/null
    echo "$tarfile"
}

upload_latest_report() {
    local tarfile method result
    tarfile=$(pack_latest_report) || return
    echo "准备上传: $tarfile"
    echo "1. Catbox  2. transfer.sh  3. tmpfiles.org"
    read -r -p "选择上传方式(默认1): " method; method="${method:-1}"
    case "$method" in
        1) result=$(curl -fsSL -F "reqtype=fileupload" -F "fileToUpload=@${tarfile}" https://catbox.moe/user/api.php) ;;
        2) result=$(curl -fsSL --upload-file "$tarfile" "https://transfer.sh/$(basename "$tarfile")") ;;
        3) result=$(curl -fsSL -F "file=@${tarfile}" https://tmpfiles.org/api/v1/upload) ;;
        *) echo -e "${RED}无效选项${ENDC}"; return ;;
    esac
    echo -e "${GREEN}上传完成:${ENDC} $result"
}

# ── 选项12：独立单次三网测速 ──────────────────────────────────────────────────

_ecs_run_list() {
    for item in "$@"; do
        local sid; sid=$(echo "$item" | cut -d',' -f1)
        local name; name=$(echo "$item" | cut -d',' -f2)
        local result
        result=$(_ookla_run_test "$sid")
        local ul dl lat pkt
        IFS='|' read -r ul dl lat pkt <<< "$result"
        printf '%-20s ↑%-12s ↓%-12s ↕%-10s 丢包:%s\n' \
            "$name" "${ul}Mbps" "${dl}Mbps" "${lat}ms" "$pkt"
    done
}

run_ecsspeed_test() {
    ecs_check_cdn_file
    ecs_install_speedtest || { echo -e "${RED}speedtest 工具安装失败${ENDC}"; return 1; }
    echo
    echo "  三网/国际 speedtest.net 节点测速"
    echo "——————————————————————————————————————————————————————————————————————————————"
    echo -e "  ${GREEN}1.${ENDC} 三网就近    ${GREEN}2.${ENDC} 三网全测    ${GREEN}3.${ENDC} 联通    ${GREEN}4.${ENDC} 电信"
    echo -e "  ${GREEN}5.${ENDC} 移动        ${GREEN}6.${ENDC} 香港        ${GREEN}7.${ENDC} 台湾    ${GREEN}8.${ENDC} 日本    ${GREEN}9.${ENDC} 新加坡"
    echo -e "  ${GREEN}0.${ENDC} 返回主菜单"
    echo "——————————————————————————————————————————————————————————————————————————————"
    local sel
    while true; do read -r -p "请选择: " sel; [[ "$sel" =~ ^[0-9]$ ]] && break; echo -e "${RED}无效${ENDC}"; done
    [[ "$sel" == "0" ]] && return
    echo "——————————————————————————————————————————————————————————————————————————————"
    printf '%-20s %-14s %-14s %-12s %s\n' "位置" "上传" "下载" "延迟" "丢包率"
    local ts; ts=$(date +%s)
    case "$sel" in
        1) _ecs_run_list $(ecs_get_nearest_data "${SERVER_BASE_URL}/CN_Unicom.csv")
           _ecs_run_list $(ecs_get_nearest_data "${SERVER_BASE_URL}/CN_Telecom.csv")
           _ecs_run_list $(ecs_get_nearest_data "${SERVER_BASE_URL}/CN_Mobile.csv") ;;
        2) _ecs_run_list $(ecs_get_data "${SERVER_BASE_URL}/CN_Unicom.csv")
           _ecs_run_list $(ecs_get_data "${SERVER_BASE_URL}/CN_Telecom.csv")
           _ecs_run_list $(ecs_get_data "${SERVER_BASE_URL}/CN_Mobile.csv") ;;
        3) _ecs_run_list $(ecs_get_data "${SERVER_BASE_URL}/CN_Unicom.csv")  ;;
        4) _ecs_run_list $(ecs_get_data "${SERVER_BASE_URL}/CN_Telecom.csv") ;;
        5) _ecs_run_list $(ecs_get_data "${SERVER_BASE_URL}/CN_Mobile.csv")  ;;
        6) _ecs_run_list $(ecs_get_data "${SERVER_BASE_URL}/HK.csv")         ;;
        7) _ecs_run_list $(ecs_get_data "${SERVER_BASE_URL}/TW.csv")         ;;
        8) _ecs_run_list $(ecs_get_data "${SERVER_BASE_URL}/JP.csv")         ;;
        9) _ecs_run_list $(ecs_get_data "${SERVER_BASE_URL}/SG.csv")         ;;
    esac
    local te; te=$(date +%s)
    echo "——————————————————————————————————————————————————————————————————————————————"
    echo " 总共花费: $(( te - ts )) 秒 | $(date)"
}

main_menu() {
    while true; do
        print_banner
        echo "1. 前台开始测速"
        echo "2. 后台守护开始测速"
        echo "3. 查看后台任务状态"
        echo "4. 停止后台任务"
        echo "5. 日志列表"
        echo "6. 查看最新日志"
        echo "7. 查看指定日志"
        echo "8. 分析最新CSV并生成曲线"
        echo "9. 选择CSV做分析并生成曲线"
        echo "10. 报告文件列表"
        echo "11. 上传最新报告并生成下载链接"
        echo "12. 三网/国际 speedtest.net 测速（单次）"
        echo "0. 退出"
        echo
        read -r -p "请选择: " menu
        case "$menu" in
            1)  start_foreground_task; pause_screen ;;
            2)  start_background_task; pause_screen ;;
            3)  show_status; pause_screen ;;
            4)  stop_background_task; pause_screen ;;
            5)  list_logs; pause_screen ;;
            6)  view_latest_log; pause_screen ;;
            7)  view_log_by_menu; pause_screen ;;
            8)  analyze_latest_csv; pause_screen ;;
            9)  analyze_csv_by_menu; pause_screen ;;
            10) list_reports; pause_screen ;;
            11) upload_latest_report; pause_screen ;;
            12) run_ecsspeed_test; pause_screen ;;
            0)  exit 0 ;;
            *)  echo -e "${RED}无效选项${ENDC}"; sleep 1 ;;
        esac
    done
}

check_dependencies
main_menu
