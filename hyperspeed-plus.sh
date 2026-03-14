#!/usr/bin/env bash
set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
ENDC='\033[0m'

SCRIPT_NAME='HyperSpeed Plus'
SCRIPT_VERSION='1.0.0'
BASE_DIR="${HOME}/.hyperspeed-plus"
LOG_DIR="${BASE_DIR}/logs"
WORK_DIR="${BASE_DIR}/tmp"
BINARY="${WORK_DIR}/bimc"
THREAD_FLAG=''

mkdir -p "$LOG_DIR" "$WORK_DIR"

NODES=(
'电信|上海|电信||aHR0cDovL3NwZWVkdGVzdDEub25saW5lLnNoLmNuOjgwODAvZG93bmxvYWQK|aHR0cDovL3NwZWVkdGVzdDEub25saW5lLnNoLmNuOjgwODAvdXBsb2FkCg=='
'电信|江苏镇江5G|电信||aHR0cDovLzVnemhlbmppYW5nLnNwZWVkdGVzdC5qc2luZm8ubmV0OjgwODAvZG93bmxvYWQ=|aHR0cDovLzVnemhlbmppYW5nLnNwZWVkdGVzdC5qc2luZm8ubmV0OjgwODAvdXBsb2Fk'
'电信|江苏南京5G|电信||aHR0cDovLzVnbmFuamluZy5zcGVlZHRlc3QuanNpbmZvLm5ldDo4MDgwL2Rvd25sb2FkCg==|aHR0cDovLzVnbmFuamluZy5zcGVlZHRlc3QuanNpbmZvLm5ldDo4MDgwL3VwbG9hZAo='
'电信|安徽合肥5G|电信||aHR0cDovL3NwZWVkdGVzdDEuYWgxNjMuY29tOjgwODAvZG93bmxvYWQ=|aHR0cDovL3NwZWVkdGVzdDEuYWgxNjMuY29tOjgwODAvdXBsb2Fk'
'电信|天津5G|电信||aHR0cDovL3N5LnRqdGVsZS5jb206ODA4MC9kb3dubG9hZA==|aHR0cDovL3N5LnRqdGVsZS5jb206ODA4MC91cGxvYWQ='
'电信|天津|电信||aHR0cDovL3RqcmF0ZS50anRlbGUuY29tOjgwODAvZG93bmxvYWQ=|aHR0cDovL3RqcmF0ZS50anRlbGUuY29tOjgwODAvdXBsb2Fk'
'电信|四川成都|电信||aHR0cDovL3NwZWVkdGVzdDEuc2MuMTg5LmNuOjgwODAvZG93bmxvYWQ=|aHR0cDovL3NwZWVkdGVzdDEuc2MuMTg5LmNuOjgwODAvdXBsb2Fk'
'电信|甘肃兰州|电信||aHR0cDovL3NwZWVkLmJhamlhbmp1bi5jb206ODA4MC9kb3dubG9hZA==|aHR0cDovL3NwZWVkLmJhamlhbmp1bi5jb206ODA4MC91cGxvYWQ='

'联通|上海5G|联通||aHR0cDovLzVnLnNodW5pY29tdGVzdC5jb206ODA4MC9kb3dubG9hZAo=|aHR0cDovLzVnLnNodW5pY29tdGVzdC5jb206ODA4MC91cGxvYWQK'
'联通|江苏无锡|联通||aHR0cHM6Ly9zcGVlZHRlc3QyLm5pdXRrLmNvbTo4MDgwL2Rvd25sb2Fk|aHR0cHM6Ly9zcGVlZHRlc3QyLm5pdXRrLmNvbTo4MDgwL3VwbG9hZA=='
'联通|江西南昌|联通||aHR0cDovL3NwZWVkdGVzdC5qeHVuaWNvbS5jb206ODA4MC9kb3dubG9hZA==|aHR0cDovL3NwZWVkdGVzdC5qeHVuaWNvbS5jb206ODA4MC91cGxvYWQ='
'联通|河南郑州5G|联通||aHR0cDovLzVndGVzdC5zaGFuZ2R1LmNvbTo4MDgwL2Rvd25sb2Fk|aHR0cDovLzVndGVzdC5zaGFuZ2R1LmNvbTo4MDgwL3VwbG9hZA=='
'联通|湖南长沙5G|联通||aHR0cDovL3NwZWVkdGVzdDAxLmhuMTY1LmNvbTo4MDgwL2Rvd25sb2Fk|aHR0cDovL3NwZWVkdGVzdDAxLmhuMTY1LmNvbTo4MDgwL3VwbG9hZA=='
'联通|辽宁沈阳|联通||aHR0cDovL3VuaWNvbXNwZWVkdGVzdC5jb206ODA4MC9kb3dubG9hZAo=|aHR0cDovL3VuaWNvbXNwZWVkdGVzdC5jb206ODA4MC91cGxvYWQK'
'联通|福建福州|联通||aHR0cDovL3VwbG9hZDEudGVzdHNwZWVkLmNkbjE2LmNvbTo4MDgwL2Rvd25sb2Fk|aHR0cDovL3VwbG9hZDEudGVzdHNwZWVkLmNkbjE2LmNvbTo4MDgwL3VwbG9hZA=='

'移动|北京|移动||aHR0cDovLzIxMS4xMzYuMzAuMTE0OjkwMDAvc3BlZWQvMjAwMDAwMC5kYXRhCg==|aHR0cDovLzIxMS4xMzYuMzAuMTE0OjkwMDAvc3BlZWQvMjAwMDAwLmRhdGEK'
'移动|浙江杭州5G|移动||aHR0cDovL3NwZWVkdGVzdC4xMzlwbGF5LmNvbTo4MDgwL2Rvd25sb2Fk|aHR0cDovL3NwZWVkdGVzdC4xMzlwbGF5LmNvbTo4MDgwL3VwbG9hZA=='
'移动|陕西西安5G|移动||aHR0cDovL3NwZWVkdGVzdC5vbmUtcHVuY2gud2luOjgwODAvZG93bmxvYWQ=|aHR0cDovL3NwZWVkdGVzdC5vbmUtcHVuY2gud2luOjgwODAvdXBsb2Fk'
'移动|四川成都|移动||aHR0cDovL3NwZWVkdGVzdDEuc2MuY2hpbmFtb2JpbGUuY29tOjgwODAvZG93bmxvYWQ=|aHR0cDovL3NwZWVkdGVzdDEuc2MuY2hpbmFtb2JpbGUuY29tOjgwODAvdXBsb2Fk'
'移动|甘肃兰州|移动||aHR0cDovL3NwZWVkdGVzdDEuZ3MuY2hpbmFtb2JpbGUuY29tOjgwODAvZG93bmxvYWQ=|aHR0cDovL3NwZWVkdGVzdDEuZ3MuY2hpbmFtb2JpbGUuY29tOjgwODAvdXBsb2Fk'

'教育网IPv4|中国科技大学|合肥||aHR0cHM6Ly90ZXN0LnVzdGMuZWR1LmNuL2JhY2tlbmQvZ2FyYmFnZS5waHAK|aHR0cHM6Ly90ZXN0LnVzdGMuZWR1LmNuL2JhY2tlbmQvZW1wdHkucGhwCg=='
'教育网IPv4|东北大学|沈阳||aHR0cHM6Ly9pcHR2LnRzaW5naHVhLmVkdS5jbi9zdC9nYXJiYWdlLnBocAo=|aHR0cHM6Ly9pcHR2LnRzaW5naHVhLmVkdS5jbi9zdC9lbXB0eS5waHAK'
'教育网IPv4|上海交通大学|上海||aHR0cHM6Ly93c3VzLnNqdHUuZWR1LmNuL3NwZWVkdGVzdC9iYWNrZW5kL2dhcmJhZ2UucGhwCg==|aHR0cHM6Ly93c3VzLnNqdHUuZWR1LmNuL3NwZWVkdGVzdC9iYWNrZW5kL2VtcHR5LnBocAo='

'教育网IPv6|中国科技大学|合肥|-6|aHR0cHM6Ly90ZXN0Ni51c3RjLmVkdS5jbi9iYWNrZW5kL2dhcmJhZ2UucGhwCg==|aHR0cHM6Ly90ZXN0Ni51c3RjLmVkdS5jbi9iYWNrZW5kL2VtcHR5LnBocAo='
'教育网IPv6|东北大学|沈阳|-6|aHR0cHM6Ly9pcHR2LnRzaW5naHVhLmVkdS5jbi9zdC9nYXJiYWdlLnBocAo=|aHR0cHM6Ly9pcHR2LnRzaW5naHVhLmVkdS5jbi9zdC9lbXB0eS5waHAK'
'教育网IPv6|上海交通大学|上海|-6|aHR0cHM6Ly93c3VzLnNqdHUuZWR1LmNuL3NwZWVkdGVzdC9iYWNrZW5kL2dhcmJhZ2UucGhwCg==|aHR0cHM6Ly93c3VzLnNqdHUuZWR1LmNuL3NwZWVkdGVzdC9iYWNrZW5kL2VtcHR5LnBocAo='

'三网IPv6|甘肃兰州|电信|-6|aHR0cDovL3NwZWVkLmJhamlhbmp1bi5jb206ODA4MC9kb3dubG9hZA==|aHR0cDovL3NwZWVkLmJhamlhbmp1bi5jb206ODA4MC91cGxvYWQ='
'三网IPv6|上海5G|联通|-6|aHR0cDovLzVnLnNodW5pY29tdGVzdC5jb206ODA4MC9kb3dubG9hZAo=|aHR0cDovLzVnLnNodW5pY29tdGVzdC5jb206ODA4MC91cGxvYWQK'

'港澳台日韩|环电宽频|香港||aHR0cDovL29va2xhLWhpZGMuaGdjb25haXIuaGdjLmNvbS5oazo4MDgwL2Rvd25sb2FkCg==|aHR0cDovL29va2xhLWhpZGMuaGdjb25haXIuaGdjLmNvbS5oazo4MDgwL3VwbG9hZAo='
'港澳台日韩|澳门电讯|澳门||aHR0cDovL3NwZWVkdGVzdDUubWFjYXUuY3RtLm5ldDo4MDgwL2Rvd25sb2FkCg==|aHR0cDovL3NwZWVkdGVzdDUubWFjYXUuY3RtLm5ldDo4MDgwL3VwbG9hZAo='
'港澳台日韩|中华电信|台北||aHR0cDovL3RwMS5jaHRtLmhpbmV0Lm5ldDo4MDgwL2Rvd25sb2FkCg==|aHR0cDovL3RwMS5jaHRtLmhpbmV0Lm5ldDo4MDgwL3VwbG9hZAo='
'港澳台日韩|乐天移动|东京||aHR0cDovL29va2xhLm1ic3BlZWQubmV0OjgwODAvZG93bmxvYWQK|aHR0cDovL29va2xhLm1ic3BlZWQubmV0OjgwODAvdXBsb2FkCg=='
'港澳台日韩|Kdatacenter|首尔||aHR0cDovL3NwZWVkdGVzdC5rZGF0YWNlbnRlci5jb206ODA4MC9kb3dubG9hZAo=|aHR0cDovL3NwZWVkdGVzdC5rZGF0YWNlbnRlci5jb206ODA4MC91cGxvYWQK'
)

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

array_contains() {
    local seek="$1"
    shift
    local item
    for item in "$@"; do
        [[ "$item" == "$seek" ]] && return 0
    done
    return 1
}

download_file() {
    local url="$1"
    local target="$2"
    if command_exists curl; then
        curl -fsSL "$url" -o "$target"
    elif command_exists wget; then
        wget --no-check-certificate -qO "$target" "$url"
    else
        return 1
    fi
}

check_dependencies() {
    local missing=()
    command_exists base64 || missing+=(base64)
    command_exists awk || missing+=(awk)
    command_exists sed || missing+=(sed)
    command_exists date || missing+=(date)
    if ! command_exists curl && ! command_exists wget; then
        missing+=(curl/wget)
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}缺少依赖: ${missing[*]}${ENDC}"
        exit 1
    fi
}

prepare_bimc() {
    if [ ! -x "$BINARY" ]; then
        local arch
        arch=$(uname -m)
        echo -e "${CYAN}正在获取 bimc 组件...${ENDC}"
        download_file "https://bench.im/bimc-${arch}" "$BINARY" || {
            echo -e "${RED}bimc 下载失败${ENDC}"
            exit 1
        }
        chmod +x "$BINARY"
    fi
}

print_banner() {
    clear
    echo "—————————————————————— ${SCRIPT_NAME} ${SCRIPT_VERSION} ——————————————————————"
    echo "  长时压力测速 | 节点多选 | 日志查询 | CSV 记录"
    echo "  日志目录: ${LOG_DIR}"
    echo "——————————————————————————————————————————————————————————————————————————————"
}

pause_screen() {
    read -r -p "按回车继续..." _
}

is_number() {
    [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

show_nodes() {
    echo
    echo "可选测试地区/节点:"
    local i entry group location isp extra dl ul
    for i in "${!NODES[@]}"; do
        entry="${NODES[$i]}"
        IFS='|' read -r group location isp extra dl ul <<< "$entry"
        printf '  %02d. %-12s %-12s (%s)\n' "$((i+1))" "$group" "$location" "$isp"
    done
    echo
    echo "输入示例: 1,2,9,16"
    echo "输入 all 表示全选"
}

select_nodes() {
    local input token
    SELECTED_IDS=()
    show_nodes

    while true; do
        read -r -p "请选择测试地区编号(多选): " input
        input="${input// /}"

        if [[ -z "$input" || "$input" == "all" ]]; then
            for token in "${!NODES[@]}"; do
                SELECTED_IDS+=("$((token+1))")
            done
            break
        fi

        IFS=',' read -r -a TOKENS <<< "$input"
        local valid=1
        for token in "${TOKENS[@]}"; do
            [[ "$token" =~ ^[0-9]+$ ]] || valid=0
            if (( token < 1 || token > ${#NODES[@]} )); then
                valid=0
            fi
        done

        if (( valid == 0 )); then
            echo -e "${RED}输入无效，请重新输入${ENDC}"
            continue
        fi

        for token in "${TOKENS[@]}"; do
            if ! array_contains "$token" "${SELECTED_IDS[@]}"; then
                SELECTED_IDS+=("$token")
            fi
        done

        [ ${#SELECTED_IDS[@]} -gt 0 ] && break
    done
}

get_thread_option() {
    read -r -p "启用八线程测速? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        THREAD_FLAG='-m'
    else
        THREAD_FLAG=''
    fi
}

get_duration_option() {
    while true; do
        read -r -p "压力测速时长(小时，0=只跑一轮，支持小数，默认0): " DURATION_HOURS
        DURATION_HOURS="${DURATION_HOURS:-0}"
        if is_number "$DURATION_HOURS"; then
            break
        fi
        echo -e "${RED}请输入数字，例如 0 / 1 / 2.5${ENDC}"
    done

    if awk "BEGIN{exit !($DURATION_HOURS>0)}"; then
        while true; do
            read -r -p "每轮测试间隔(分钟，默认10): " INTERVAL_MINUTES
            INTERVAL_MINUTES="${INTERVAL_MINUTES:-10}"
            if is_number "$INTERVAL_MINUTES"; then
                break
            fi
            echo -e "${RED}请输入数字，例如 5 / 10 / 30${ENDC}"
        done
    else
        INTERVAL_MINUTES=0
    fi

    DURATION_SECONDS=$(awk "BEGIN{printf \"%d\", $DURATION_HOURS*3600}")
    INTERVAL_SECONDS=$(awk "BEGIN{printf \"%d\", $INTERVAL_MINUTES*60}")
}

new_log_files() {
    local ts
    ts=$(date '+%Y%m%d-%H%M%S')
    LOG_FILE="${LOG_DIR}/hyperspeed-${ts}.log"
    CSV_FILE="${LOG_DIR}/hyperspeed-${ts}.csv"
    printf 'time,round,group,location,isp,node_name,upload_mbps,upload_status,download_mbps,download_status,latency_ms,jitter_ms\n' > "$CSV_FILE"
}

log_line() {
    printf '%b\n' "$1"
    printf '%b\n' "$2" >> "$LOG_FILE"
}

decode_b64() {
    printf '%s' "$1" | base64 -d 2>/dev/null | tr -d '\r\n'
}

run_single_test() {
    local id="$1"
    local round="$2"
    local entry group location isp extra dl_b64 ul_b64
    local dl ul node_name output upload up_status download down_status latency jitter now
    local screen plain color

    entry="${NODES[$((id-1))]}"
    IFS='|' read -r group location isp extra dl_b64 ul_b64 <<< "$entry"

    dl=$(decode_b64 "$dl_b64")
    ul=$(decode_b64 "$ul_b64")
    node_name=$("$BINARY" -n "$location" 2>/dev/null)
    [ -n "$node_name" ] || node_name="$location"

    local cmd=("$BINARY" "$dl" "$ul")
    [ -n "$THREAD_FLAG" ] && cmd+=("$THREAD_FLAG")
    [ -n "$extra" ] && cmd+=("$extra")

    output=$("${cmd[@]}" 2>/dev/null)
    IFS=',' read -r upload up_status download down_status latency jitter <<< "$output"

    upload="${upload:-0}"
    up_status="${up_status:-失败}"
    download="${download:-0}"
    down_status="${down_status:-失败}"
    latency="${latency:-0}"
    jitter="${jitter:-0}"
    now=$(date '+%F %T')

    color="$GREEN"
    if [[ "$up_status" != "正常" || "$down_status" != "正常" ]]; then
        color="$RED"
    fi

    screen="${YELLOW}[第${round}轮]${ENDC} ${PURPLE}${group}${ENDC} | ${GREEN}${node_name}${ENDC} ${CYAN}↑${upload}${ENDC} ${color}${up_status}${ENDC} ${CYAN}↓${download}${ENDC} ${color}${down_status}${ENDC} ${CYAN}↕${latency} ϟ${jitter}${ENDC}"
    plain="[第${round}轮] ${group} | ${node_name} ↑${upload} ${up_status} ↓${download} ${down_status} ↕${latency} ϟ${jitter}"

    log_line "$screen" "$plain"
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$now" "$round" "$group" "$location" "$isp" "$node_name" "$upload" "$up_status" "$download" "$down_status" "$latency" "$jitter" >> "$CSV_FILE"
}

run_test_plan() {
    new_log_files

    local end_epoch=0 now round=1 sleep_seconds
    local selected_text=""
    local id entry group location isp extra dl ul

    for id in "${SELECTED_IDS[@]}"; do
        entry="${NODES[$((id-1))]}"
        IFS='|' read -r group location isp extra dl ul <<< "$entry"
        selected_text+="${group}-${location} "
    done

    if (( DURATION_SECONDS > 0 )); then
        end_epoch=$(( $(date +%s) + DURATION_SECONDS ))
    fi

    log_line "${CYAN}开始测试，日志: ${LOG_FILE}${ENDC}" "开始测试，日志: ${LOG_FILE}"
    log_line "${CYAN}CSV结果: ${CSV_FILE}${ENDC}" "CSV结果: ${CSV_FILE}"
    log_line "${CYAN}所选节点: ${selected_text}${ENDC}" "所选节点: ${selected_text}"
    if [[ -n "$THREAD_FLAG" ]]; then
        log_line "${CYAN}线程模式: 八线程${ENDC}" "线程模式: 八线程"
    else
        log_line "${CYAN}线程模式: 单线程${ENDC}" "线程模式: 单线程"
    fi

    while true; do
        log_line "${PURPLE}———————————————— 第 ${round} 轮 ————————————————${ENDC}" "———————————————— 第 ${round} 轮 ————————————————"
        for id in "${SELECTED_IDS[@]}"; do
            run_single_test "$id" "$round"
            sleep 2
        done

        if (( DURATION_SECONDS == 0 )); then
            break
        fi

        now=$(date +%s)
        if (( now >= end_epoch )); then
            break
        fi

        sleep_seconds=$INTERVAL_SECONDS
        if (( now + sleep_seconds > end_epoch )); then
            sleep_seconds=$(( end_epoch - now ))
        fi

        log_line "${CYAN}等待 ${sleep_seconds} 秒后继续下一轮${ENDC}" "等待 ${sleep_seconds} 秒后继续下一轮"
        sleep "$sleep_seconds"
        round=$((round+1))
    done

    log_line "${GREEN}测试完成${ENDC}" "测试完成"
}

list_logs() {
    mapfile -t LOG_FILES < <(find "$LOG_DIR" -maxdepth 1 -type f -name '*.log' | sort -r)
    if [ ${#LOG_FILES[@]} -eq 0 ]; then
        echo -e "${YELLOW}暂无日志${ENDC}"
        return 1
    fi

    echo
    local i
    for i in "${!LOG_FILES[@]}"; do
        printf '  %02d. %s\n' "$((i+1))" "$(basename "${LOG_FILES[$i]}")"
    done
    echo
    return 0
}

view_latest_log() {
    mapfile -t LOG_FILES < <(find "$LOG_DIR" -maxdepth 1 -type f -name '*.log' | sort -r)
    if [ ${#LOG_FILES[@]} -eq 0 ]; then
        echo -e "${YELLOW}暂无日志${ENDC}"
        return
    fi
    sed -n '1,200p' "${LOG_FILES[0]}"
}

view_log_by_menu() {
    list_logs || return
    local choice
    read -r -p "选择要查看的日志编号: " choice
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#LOG_FILES[@]} )); then
        echo -e "${RED}编号无效${ENDC}"
        return
    fi
    sed -n '1,200p' "${LOG_FILES[$((choice-1))]}"
}

main_menu() {
    while true; do
        print_banner
        echo "1. 开始测速"
        echo "2. 日志列表"
        echo "3. 查看最新日志"
        echo "4. 查看指定日志"
        echo "0. 退出"
        echo
        read -r -p "请选择: " menu

        case "$menu" in
            1)
                prepare_bimc
                select_nodes
                get_thread_option
                get_duration_option
                run_test_plan
                pause_screen
                ;;
            2)
                list_logs
                pause_screen
                ;;
            3)
                view_latest_log
                pause_screen
                ;;
            4)
                view_log_by_menu
                pause_screen
                ;;
            0)
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项${ENDC}"
                sleep 1
                ;;
        esac
    done
}

check_dependencies
main_menu
