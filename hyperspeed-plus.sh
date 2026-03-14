#!/usr/bin/env bash
set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
ENDC='\033[0m'

SCRIPT_NAME='HyperSpeed Plus'
SCRIPT_VERSION='3.0.0'
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
'教育网IPv4|东北大学|沈阳||aHR0cHM6Ly9pcHR2LnRzaW5naHVhLmVkdS5jbi9zdC9nYXJiYWdlLnBocAo=|aHR0cHM6Ly9pcHR2LnRzaW5naHVhLmVkdS5jbi9zdC9lbXB0eS5waHAK'
'教育网IPv4|上海交通大学|上海||aHR0cHM6Ly93c3VzLnNqdHUuZWR1LmNuL3NwZWVkdGVzdC9iYWNrZW5kL2dhcmJhZ2UucGhwCg==|aHR0cHM6Ly93c3VzLnNqdHUuZWR1LmNuL3NwZWVkdGVzdC9iYWNrZW5kL2VtcHR5LnBocAo='
'港澳台日韩|环电宽频|香港||aHR0cDovL29va2xhLWhpZGMuaGdjb25haXIuaGdjLmNvbS5oazo4MDgwL2Rvd25sb2FkCg==|aHR0cDovL29va2xhLWhpZGMuaGdjb25haXIuaGdjLmNvbS5oazo4MDgwL3VwbG9hZAo='
'港澳台日韩|中华电信|台北||aHR0cDovL3RwMS5jaHRtLmhpbmV0Lm5ldDo4MDgwL2Rvd25sb2FkCg==|aHR0cDovL3RwMS5jaHRtLmhpbmV0Lm5ldDo4MDgwL3VwbG9hZAo='
)

command_exists() { command -v "$1" >/dev/null 2>&1; }

array_contains() {
    local seek="$1"; shift
    local item
    for item in "$@"; do
        [[ "$item" == "$seek" ]] && return 0
    done
    return 1
}

download_file() {
    local url="$1" target="$2"
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
    for cmd in base64 awk sed date sort head tail tr find; do
        command_exists "$cmd" || missing+=("$cmd")
    done
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
    echo "  长时压力测速 | 随机间隔 | 节点多选 | 日志分析 | CSV 记录"
    echo "  日志目录: ${LOG_DIR}"
    echo "——————————————————————————————————————————————————————————————————————————————"
}

pause_screen() { read -r -p "按回车继续..." _; }

is_number() { [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]; }

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
    echo "输入示例: 1,2,5"
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
            read -r -p "每轮随机间隔上限(分钟，默认10，表示 1~N分钟内随机秒数): " INTERVAL_MINUTES
            INTERVAL_MINUTES="${INTERVAL_MINUTES:-10}"
            if is_number "$INTERVAL_MINUTES"; then
                break
            fi
            echo -e "${RED}请输入数字，例如 1 / 10 / 30${ENDC}"
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

random_wait_seconds() {
    local max="$1"
    if (( max <= 1 )); then
        echo 1
        return
    fi
    if command_exists shuf; then
        shuf -i 1-"$max" -n 1
    else
        echo $(( RANDOM % max + 1 ))
    fi
}

run_single_test() {
    local id="$1" round="$2"
    local entry group location isp extra dl_b64 ul_b64 dl ul node_name output
    local upload up_status download down_status latency jitter now screen plain color

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
    if (( DURATION_SECONDS > 0 )); then
        log_line "${CYAN}随机间隔规则: 1 ~ ${INTERVAL_SECONDS} 秒${ENDC}" "随机间隔规则: 1 ~ ${INTERVAL_SECONDS} 秒"
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

        sleep_seconds=$(random_wait_seconds "$INTERVAL_SECONDS")
        if (( now + sleep_seconds > end_epoch )); then
            sleep_seconds=$(( end_epoch - now ))
        fi
        if (( sleep_seconds <= 0 )); then
            break
        fi

        log_line "${CYAN}随机等待 ${sleep_seconds} 秒后继续下一轮${ENDC}" "随机等待 ${sleep_seconds} 秒后继续下一轮"
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

list_csvs() {
    mapfile -t CSV_FILES < <(find "$LOG_DIR" -maxdepth 1 -type f -name '*.csv' | sort -r)
    if [ ${#CSV_FILES[@]} -eq 0 ]; then
        echo -e "${YELLOW}暂无CSV日志${ENDC}"
        return 1
    fi
    echo
    local i
    for i in "${!CSV_FILES[@]}"; do
        printf '  %02d. %s\n' "$((i+1))" "$(basename "${CSV_FILES[$i]}")"
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
    sed -n '1,240p' "${LOG_FILES[0]}"
}

view_log_by_menu() {
    list_logs || return
    local choice
    read -r -p "选择要查看的日志编号: " choice
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#LOG_FILES[@]} )); then
        echo -e "${RED}编号无效${ENDC}"
        return
    fi
    sed -n '1,240p' "${LOG_FILES[$((choice-1))]}"
}

analyze_csv_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo -e "${RED}CSV文件不存在${ENDC}"
        return 1
    fi

    awk -F',' '
    function trim(s) { gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s); return s }
    function numcmp(i1, v1, i2, v2,    a, b) { a=v1+0; b=v2+0; return (a<b?-1:(a>b?1:0)) }
    function percentile(arr, n, p,    idx) {
        if (n <= 0) return 0;
        asort(arr, sorted, "numcmp");
        idx = int((n - 1) * p + 1);
        if (idx < 1) idx = 1;
        if (idx > n) idx = n;
        return sorted[idx] + 0;
    }
    BEGIN {
        total=0; rounds=0; success=0; up_ok=0; down_ok=0; fail=0; cancel=0; broken=0;
        both_zero=0; sample_up=0; sample_down=0; sample_lat=0; sample_jit=0;
    }
    NR==1 { next }
    {
        round=trim($2); group=trim($3); location=trim($4); isp=trim($5); node=trim($6);
        up=trim($7)+0; up_status=trim($8); down=trim($9)+0; down_status=trim($10); latency=trim($11)+0; jitter=trim($12)+0;
        total++;
        round_seen[round]=1;
        node_key=group "|" node;
        group_total[group]++;
        node_total[node_key]++;

        if (up==0 && down==0) both_zero++;
        if (up_status=="正常") up_ok++;
        if (down_status=="正常") down_ok++;
        if (up_status=="失败" || down_status=="失败") fail++;
        if (up_status=="取消" || down_status=="取消") cancel++;
        if (up_status=="断流" || down_status=="断流") broken++;

        if (up_status=="正常" && down_status=="正常") {
            success++;
            group_ok[group]++;
            node_ok[node_key]++;

            sample_up++; up_arr[sample_up]=up; up_sum+=up;
            sample_down++; down_arr[sample_down]=down; down_sum+=down;
            sample_lat++; lat_arr[sample_lat]=latency; lat_sum+=latency;
            sample_jit++; jit_arr[sample_jit]=jitter; jit_sum+=jitter;

            node_up_sum[node_key]+=up; node_down_sum[node_key]+=down; node_lat_sum[node_key]+=latency; node_jit_sum[node_key]+=jitter;
            node_full_ok[node_key]++;
            group_up_sum[group]+=up; group_down_sum[group]+=down; group_lat_sum[group]+=latency; group_jit_sum[group]+=jitter;
            group_full_ok[group]++;

            if (best_down=="" || down>best_down_val) { best_down_val=down; best_down=node_key; }
            if (best_up=="" || up>best_up_val) { best_up_val=up; best_up=node_key; }
            if (best_lat=="" || latency<best_lat_val) { best_lat_val=latency; best_lat=node_key; }
            if (best_jit=="" || jitter<best_jit_val) { best_jit_val=jitter; best_jit=node_key; }
        }
    }
    END {
        for (r in round_seen) rounds++;
        success_rate = total>0 ? success/total*100 : 0;
        up_rate = total>0 ? up_ok/total*100 : 0;
        down_rate = total>0 ? down_ok/total*100 : 0;
        broken_rate = total>0 ? broken/total*100 : 0;
        zero_rate = total>0 ? both_zero/total*100 : 0;

        printf "\n———————————————— 专业分析报告 ————————————————\n";
        printf "样本总数: %d\n", total;
        printf "测试轮数: %d\n", rounds;
        printf "双向可用率: %.2f%% (%d/%d)\n", success_rate, success, total;
        printf "上传可用率: %.2f%% (%d/%d)\n", up_rate, up_ok, total;
        printf "下载可用率: %.2f%% (%d/%d)\n", down_rate, down_ok, total;
        printf "断流占比: %.2f%% (%d/%d)\n", broken_rate, broken, total;
        printf "零速占比: %.2f%% (%d/%d)\n", zero_rate, both_zero, total;
        printf "失败次数: %d | 取消次数: %d | 断流次数: %d\n", fail, cancel, broken;

        if (success > 0) {
            up_avg=up_sum/success; down_avg=down_sum/success; lat_avg=lat_sum/success; jit_avg=jit_sum/success;
            up_p50=percentile(up_arr, sample_up, 0.50); up_p95=percentile(up_arr, sample_up, 0.95);
            down_p50=percentile(down_arr, sample_down, 0.50); down_p95=percentile(down_arr, sample_down, 0.95);
            lat_p50=percentile(lat_arr, sample_lat, 0.50); lat_p95=percentile(lat_arr, sample_lat, 0.95);
            jit_p50=percentile(jit_arr, sample_jit, 0.50); jit_p95=percentile(jit_arr, sample_jit, 0.95);

            printf "\n可用样本统计(仅双向正常):\n";
            printf "- 上传均值/P50/P95: %.2f / %.2f / %.2f Mbps\n", up_avg, up_p50, up_p95;
            printf "- 下载均值/P50/P95: %.2f / %.2f / %.2f Mbps\n", down_avg, down_p50, down_p95;
            printf "- 延迟均值/P50/P95: %.2f / %.2f / %.2f ms\n", lat_avg, lat_p50, lat_p95;
            printf "- 抖动均值/P50/P95: %.2f / %.2f / %.2f ms\n", jit_avg, jit_p50, jit_p95;
            printf "- 峰值下载: %.2f Mbps (%s)\n", best_down_val, best_down;
            printf "- 峰值上传: %.2f Mbps (%s)\n", best_up_val, best_up;
            printf "- 最低延迟: %.2f ms (%s)\n", best_lat_val, best_lat;
            printf "- 最低抖动: %.2f ms (%s)\n", best_jit_val, best_jit;

            printf "\n线路判断:\n";
            if (down_avg >= 50 && lat_p95 <= 200 && jit_p95 <= 15) {
                printf "- 综合评价: 线路质量较好，适合持续跑带宽业务。\n";
            } else if (down_avg >= 20 && lat_p95 <= 250) {
                printf "- 综合评价: 线路可用，适合常规业务，但高峰稳定性还需继续观察。\n";
            } else {
                printf "- 综合评价: 线路存在明显短板，建议拉长压测时间后再定结论。\n";
            }
            if (broken > 0 && broken_rate >= 20) {
                printf "- 下载链路存在断流特征，优先排查目标测速端下载方向、回程策略或中间限流。\n";
            }
            if (lat_p95 > 180) {
                printf "- 时延尾部偏高，说明跨境或跨网高峰抖动明显，实时业务体验会受影响。\n";
            }
            if (jit_p95 > 10) {
                printf "- 抖动尾部偏大，建议结合更长时间压测判断是否为队列拥塞或共享带宽波动。\n";
            }
        } else {
            printf "\n可用样本统计: 暂无双向正常样本，无法做吞吐与时延质量评估。\n";
        }

        printf "\n分组画像:\n";
        for (g in group_total) {
            rate=(group_ok[g]+0)/group_total[g]*100;
            printf "- %s: 双向可用率 %.2f%% (%d/%d)", g, rate, group_ok[g]+0, group_total[g];
            if ((group_full_ok[g]+0) > 0) {
                printf ", 平均上传 %.2f Mbps, 平均下载 %.2f Mbps, 平均延迟 %.2f ms, 平均抖动 %.2f ms", group_up_sum[g]/group_full_ok[g], group_down_sum[g]/group_full_ok[g], group_lat_sum[g]/group_full_ok[g], group_jit_sum[g]/group_full_ok[g];
            }
            printf "\n";
        }

        printf "\n节点画像:\n";
        for (n in node_total) {
            rate=(node_ok[n]+0)/node_total[n]*100;
            printf "- %s: 双向可用率 %.2f%% (%d/%d)", n, rate, node_ok[n]+0, node_total[n];
            if ((node_full_ok[n]+0) > 0) {
                printf ", 平均上传 %.2f Mbps, 平均下载 %.2f Mbps, 平均延迟 %.2f ms, 平均抖动 %.2f ms", node_up_sum[n]/node_full_ok[n], node_down_sum[n]/node_full_ok[n], node_lat_sum[n]/node_full_ok[n], node_jit_sum[n]/node_full_ok[n];
            }
            printf "\n";
        }
        printf "——————————————————————————————————————————\n\n";
    }' "$file"
}

analyze_latest_csv() {
    mapfile -t CSV_FILES < <(find "$LOG_DIR" -maxdepth 1 -type f -name '*.csv' | sort -r)
    if [ ${#CSV_FILES[@]} -eq 0 ]; then
        echo -e "${YELLOW}暂无CSV日志${ENDC}"
        return
    fi
    analyze_csv_file "${CSV_FILES[0]}"
}

analyze_csv_by_menu() {
    list_csvs || return
    local choice
    read -r -p "选择要分析的CSV编号: " choice
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#CSV_FILES[@]} )); then
        echo -e "${RED}编号无效${ENDC}"
        return
    fi
    analyze_csv_file "${CSV_FILES[$((choice-1))]}"
}

main_menu() {
    while true; do
        print_banner
        echo "1. 开始测速"
        echo "2. 日志列表"
        echo "3. 查看最新日志"
        echo "4. 查看指定日志"
        echo "5. 分析最新CSV"
        echo "6. 选择CSV做分析"
        echo "0. 退出"
        echo
        read -r -p "请选择: " menu
        case "$menu" in
            1) prepare_bimc; select_nodes; get_thread_option; get_duration_option; run_test_plan; pause_screen ;;
            2) list_logs; pause_screen ;;
            3) view_latest_log; pause_screen ;;
            4) view_log_by_menu; pause_screen ;;
            5) analyze_latest_csv; pause_screen ;;
            6) analyze_csv_by_menu; pause_screen ;;
            0) exit 0 ;;
            *) echo -e "${RED}无效选项${ENDC}"; sleep 1 ;;
        esac
    done
}

check_dependencies
main_menu
