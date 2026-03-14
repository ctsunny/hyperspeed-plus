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
SCRIPT_VERSION='4.0.0'
BASE_DIR="${HOME}/.hyperspeed-plus"
LOG_DIR="${BASE_DIR}/logs"
WORK_DIR="${BASE_DIR}/tmp"
REPORT_DIR="${BASE_DIR}/reports"
BINARY="${WORK_DIR}/bimc"
THREAD_FLAG=''

mkdir -p "$LOG_DIR" "$WORK_DIR" "$REPORT_DIR"

# 已移除两个教育网断流节点，仅保留当前可用节点
NODES=(
'电信|上海|电信||aHR0cDovL3NwZWVkdGVzdDEub25saW5lLnNoLmNuOjgwODAvZG93bmxvYWQK|aHR0cDovL3NwZWVkdGVzdDEub25saW5lLnNoLmNuOjgwODAvdXBsb2FkCg=='
'电信|江苏镇江5G|电信||aHR0cDovLzVnemhlbmppYW5nLnNwZWVkdGVzdC5qc2luZm8ubmV0OjgwODAvZG93bmxvYWQ=|aHR0cDovLzVnemhlbmppYW5nLnNwZWVkdGVzdC5qc2luZm8ubmV0OjgwODAvdXBsb2Fk'
'电信|江苏南京5G|电信||aHR0cDovLzVnbmFuamluZy5zcGVlZHRlc3QuanNpbmZvLm5ldDo4MDgwL2Rvd25sb2FkCg==|aHR0cDovLzVnbmFuamluZy5zcGVlZHRlc3QuanNpbmZvLm5ldDo4MDgwL3VwbG9hZAo='
'港澳台日韩|环电宽频|香港||aHR0cDovL29va2xhLWhpZGMuaGdjb25haXIuaGdjLmNvbS5oazo4MDgwL2Rvd25sb2FkCg==|aHR0cDovL29va2xhLWhpZGMuaGdjb25haXIuaGdjLmNvbS5oazo4MDgwL3VwbG9hZAo='
'港澳台日韩|中华电信|台北||aHR0cDovL3RwMS5jaHRtLmhpbmV0Lm5ldDo4MDgwL2Rvd25sb2FkCg==|aHR0cDovL3RwMS5jaHRtLmhpbmV0Lm5ldDo4MDgwL3VwbG9hZAo='
)

command_exists() { command -v "$1" >/dev/null 2>&1; }

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
    for cmd in base64 awk sed date sort head tail tr find basename dirname; do
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
    echo "  长时压力测速 | 随机间隔 | 节点多选 | 专业分析 | 曲线报告"
    echo "  日志目录: ${LOG_DIR}"
    echo "  报告目录: ${REPORT_DIR}"
    echo "——————————————————————————————————————————————————————————————————————————————"
}

pause_screen() { read -r -p "按回车继续..." _; }
is_number() { [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]; }

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

list_reports() {
    mapfile -t REPORT_FILES < <(find "$REPORT_DIR" -maxdepth 1 -type f \( -name '*.html' -o -name '*.txt' -o -name '*.svg' \) | sort -r)
    if [ ${#REPORT_FILES[@]} -eq 0 ]; then
        echo -e "${YELLOW}暂无报告${ENDC}"
        return 1
    fi
    echo
    local i
    for i in "${!REPORT_FILES[@]}"; do
        printf '  %02d. %s\n' "$((i+1))" "$(basename "${REPORT_FILES[$i]}")"
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
    sed -n '1,260p' "${LOG_FILES[0]}"
}

view_log_by_menu() {
    list_logs || return
    local choice
    read -r -p "选择要查看的日志编号: " choice
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#LOG_FILES[@]} )); then
        echo -e "${RED}编号无效${ENDC}"
        return
    fi
    sed -n '1,260p' "${LOG_FILES[$((choice-1))]}"
}

build_round_curve_data() {
    local csv_file="$1"
    local out_file="$2"
    awk -F',' '
    function trim(s) { gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s); return s }
    NR==1 { next }
    {
        round=trim($2); time=trim($1); up=trim($7)+0; up_status=trim($8); down=trim($9)+0; down_status=trim($10); lat=trim($11)+0; jit=trim($12)+0;
        if (!(round in round_time)) round_time[round]=substr(time,12,8);
        if (up_status=="正常" && down_status=="正常") {
            cnt[round]++;
            up_sum[round]+=up;
            down_sum[round]+=down;
            lat_sum[round]+=lat;
            jit_sum[round]+=jit;
        }
    }
    END {
        print "round,time,avg_upload,avg_download,avg_latency,avg_jitter,count";
        for (r in cnt) {
            printf "%d,%s,%.4f,%.4f,%.4f,%.4f,%d\n", r, round_time[r], up_sum[r]/cnt[r], down_sum[r]/cnt[r], lat_sum[r]/cnt[r], jit_sum[r]/cnt[r], cnt[r];
        }
    }' "$csv_file" | sort -t',' -k1,1n > "$out_file"
}

generate_summary_report() {
    local csv_file="$1"
    local out_file="$2"
    awk -F',' '
    function trim(s) { gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s); return s }
    function abs(v) { return v<0?-v:v }
    BEGIN {
        total=0; success=0; up_ok=0; down_ok=0; fail=0; cancel=0; broken=0; both_zero=0;
    }
    NR==1 { next }
    {
        time=trim($1); round=trim($2); group=trim($3); node=trim($6);
        up=trim($7)+0; up_status=trim($8); down=trim($9)+0; down_status=trim($10); lat=trim($11)+0; jit=trim($12)+0;
        total++;
        round_seen[round]=1;
        if (start_time=="") start_time=time;
        end_time=time;
        group_total[group]++;
        node_key=group "|" node;
        node_total[node_key]++;

        if (up_status=="正常") up_ok++;
        if (down_status=="正常") down_ok++;
        if (up_status=="失败" || down_status=="失败") fail++;
        if (up_status=="取消" || down_status=="取消") cancel++;
        if (up_status=="断流" || down_status=="断流") broken++;
        if (up==0 && down==0) both_zero++;

        if (up_status=="正常" && down_status=="正常") {
            success++;
            group_ok[group]++;
            node_ok[node_key]++;
            up_sum+=up; down_sum+=down; lat_sum+=lat; jit_sum+=jit;
            up_sq+=up*up; down_sq+=down*down; lat_sq+=lat*lat; jit_sq+=jit*jit;
            if (best_down=="" || down>best_down_val) { best_down=node_key; best_down_val=down; }
            if (best_up=="" || up>best_up_val) { best_up=node_key; best_up_val=up; }
            if (best_lat=="" || lat<best_lat_val) { best_lat=node_key; best_lat_val=lat; }
            if (best_jit=="" || jit<best_jit_val) { best_jit=node_key; best_jit_val=jit; }

            node_up_sum[node_key]+=up; node_down_sum[node_key]+=down; node_lat_sum[node_key]+=lat; node_jit_sum[node_key]+=jit; node_dual_ok[node_key]++;
            group_up_sum[group]+=up; group_down_sum[group]+=down; group_lat_sum[group]+=lat; group_jit_sum[group]+=jit; group_dual_ok[group]++;
        }
    }
    END {
        rounds=0;
        for (r in round_seen) rounds++;
        dual_rate = total>0 ? success/total*100 : 0;
        up_rate = total>0 ? up_ok/total*100 : 0;
        down_rate = total>0 ? down_ok/total*100 : 0;
        fail_rate = total>0 ? fail/total*100 : 0;
        cancel_rate = total>0 ? cancel/total*100 : 0;
        broken_rate = total>0 ? broken/total*100 : 0;
        zero_rate = total>0 ? both_zero/total*100 : 0;

        print "———————————————— 专业分析报告 ————————————————";
        print "测试区间: " start_time "  ->  " end_time;
        print "样本总数: " total;
        print "测试轮数: " rounds;
        printf "双向可用率: %.2f%% (%d/%d)\n", dual_rate, success, total;
        printf "上传可用率: %.2f%% (%d/%d)\n", up_rate, up_ok, total;
        printf "下载可用率: %.2f%% (%d/%d)\n", down_rate, down_ok, total;
        printf "失败占比: %.2f%% | 取消占比: %.2f%% | 断流占比: %.2f%% | 零速占比: %.2f%%\n", fail_rate, cancel_rate, broken_rate, zero_rate;

        if (success > 0) {
            up_avg = up_sum/success;
            down_avg = down_sum/success;
            lat_avg = lat_sum/success;
            jit_avg = jit_sum/success;
            up_sd = sqrt((up_sq/success) - (up_avg*up_avg)); if (up_sd<0) up_sd=0;
            down_sd = sqrt((down_sq/success) - (down_avg*down_avg)); if (down_sd<0) down_sd=0;
            lat_sd = sqrt((lat_sq/success) - (lat_avg*lat_avg)); if (lat_sd<0) lat_sd=0;
            jit_sd = sqrt((jit_sq/success) - (jit_avg*jit_avg)); if (jit_sd<0) jit_sd=0;
            print "";
            print "可用样本统计(仅双向正常):";
            printf "- 平均上传: %.2f Mbps，波动: %.2f Mbps\n", up_avg, up_sd;
            printf "- 平均下载: %.2f Mbps，波动: %.2f Mbps\n", down_avg, down_sd;
            printf "- 平均延迟: %.2f ms，波动: %.2f ms\n", lat_avg, lat_sd;
            printf "- 平均抖动: %.2f ms，波动: %.2f ms\n", jit_avg, jit_sd;
            printf "- 峰值上传: %.2f Mbps (%s)\n", best_up_val, best_up;
            printf "- 峰值下载: %.2f Mbps (%s)\n", best_down_val, best_down;
            printf "- 最低延迟: %.2f ms (%s)\n", best_lat_val, best_lat;
            printf "- 最低抖动: %.2f ms (%s)\n", best_jit_val, best_jit;
            print "";
            print "线路判断:";
            if (down_avg >= 80 && lat_avg <= 160 && jit_avg <= 8) {
                print "- 综合评价: 质量较好，适合持续跑带宽类业务。";
            } else if (down_avg >= 40 && lat_avg <= 200) {
                print "- 综合评价: 线路可用，适合常规业务，高峰时段需继续观察。";
            } else {
                print "- 综合评价: 线路存在明显短板，建议延长压测并观察曲线尾部波动。";
            }
            if (down_sd > (down_avg * 0.25)) {
                print "- 下载波动偏大，说明带宽稳定性一般，可能受共享链路或回程策略影响。";
            }
            if (lat_sd > 20) {
                print "- 延迟波动明显，实时交互类业务体验可能在高峰期下降。";
            }
            if (jit_avg > 10) {
                print "- 平均抖动偏高，建议结合更长时段观察队列拥塞情况。";
            }
        } else {
            print "";
            print "可用样本统计: 暂无双向正常样本，无法进行有效吞吐和时延评估。";
        }

        print "";
        print "分组画像:";
        for (g in group_total) {
            rate=(group_ok[g]+0)/group_total[g]*100;
            printf "- %s: 双向可用率 %.2f%% (%d/%d)", g, rate, group_ok[g]+0, group_total[g];
            if ((group_dual_ok[g]+0) > 0) {
                printf "，平均上传 %.2f Mbps，平均下载 %.2f Mbps，平均延迟 %.2f ms，平均抖动 %.2f ms", group_up_sum[g]/group_dual_ok[g], group_down_sum[g]/group_dual_ok[g], group_lat_sum[g]/group_dual_ok[g], group_jit_sum[g]/group_dual_ok[g];
            }
            printf "\n";
        }

        print "";
        print "节点画像:";
        for (n in node_total) {
            rate=(node_ok[n]+0)/node_total[n]*100;
            printf "- %s: 双向可用率 %.2f%% (%d/%d)", n, rate, node_ok[n]+0, node_total[n];
            if ((node_dual_ok[n]+0) > 0) {
                printf "，平均上传 %.2f Mbps，平均下载 %.2f Mbps，平均延迟 %.2f ms，平均抖动 %.2f ms", node_up_sum[n]/node_dual_ok[n], node_down_sum[n]/node_dual_ok[n], node_lat_sum[n]/node_dual_ok[n], node_jit_sum[n]/node_dual_ok[n];
            }
            printf "\n";
        }
        print "——————————————————————————————————————————";
    }' "$csv_file" > "$out_file"
}

generate_speed_svg() {
    local data_file="$1"
    local out_svg="$2"
    awk -F',' '
    BEGIN {
        width=1280; height=480; left=80; right=40; top=40; bottom=70;
        plotW=width-left-right; plotH=height-top-bottom; n=0; maxV=0;
    }
    NR==1 { next }
    {
        n++;
        label[n]=$2;
        up[n]=$3+0;
        down[n]=$4+0;
        if (up[n] > maxV) maxV=up[n];
        if (down[n] > maxV) maxV=down[n];
    }
    END {
        if (maxV <= 0) maxV=1;
        print "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"" width "\" height=\"" height "\" viewBox=\"0 0 " width " " height "\">";
        print "<rect width=\"100%\" height=\"100%\" fill=\"#0b1220\"/>";
        print "<text x=\"40\" y=\"28\" fill=\"#e5e7eb\" font-size=\"22\" font-family=\"Arial\">速度曲线（按轮次平均）</text>";
        print "<line x1=\"" left "\" y1=\"" top "\" x2=\"" left "\" y2=\"" top+plotH "\" stroke=\"#94a3b8\" stroke-width=\"1\"/>";
        print "<line x1=\"" left "\" y1=\"" top+plotH "\" x2=\"" left+plotW "\" y2=\"" top+plotH "\" stroke=\"#94a3b8\" stroke-width=\"1\"/>";
        for (i=0; i<=4; i++) {
            y=top+plotH-(plotH*i/4);
            v=maxV*i/4;
            print "<line x1=\"" left "\" y1=\"" y "\" x2=\"" left+plotW "\" y2=\"" y "\" stroke=\"#1f2937\" stroke-width=\"1\"/>";
            printf "<text x=\"18\" y=\"%.2f\" fill=\"#cbd5e1\" font-size=\"12\" font-family=\"Arial\">%.0f</text>\n", y+4, v;
        }
        if (n == 0) {
            print "<text x=\"140\" y=\"240\" fill=\"#fbbf24\" font-size=\"22\" font-family=\"Arial\">暂无双向正常样本，无法生成速度曲线</text></svg>";
            exit;
        }
        if (n == 1) step=0; else step=plotW/(n-1);
        upPts=""; downPts="";
        for (i=1; i<=n; i++) {
            x=left+(i-1)*step;
            yu=top+plotH-(up[i]/maxV*plotH);
            yd=top+plotH-(down[i]/maxV*plotH);
            upPts=upPts sprintf("%.2f,%.2f ", x, yu);
            downPts=downPts sprintf("%.2f,%.2f ", x, yd);
            print "<circle cx=\"" x "\" cy=\"" yu "\" r=\"4\" fill=\"#38bdf8\"/>";
            print "<circle cx=\"" x "\" cy=\"" yd "\" r=\"4\" fill=\"#22c55e\"/>";
            txt=label[i];
            printf "<text x=\"%.2f\" y=\"%d\" fill=\"#cbd5e1\" font-size=\"11\" font-family=\"Arial\" text-anchor=\"middle\">%s</text>\n", x, top+plotH+22, txt;
        }
        print "<polyline fill=\"none\" stroke=\"#38bdf8\" stroke-width=\"3\" points=\"" upPts "\"/>";
        print "<polyline fill=\"none\" stroke=\"#22c55e\" stroke-width=\"3\" points=\"" downPts "\"/>";
        print "<rect x=\"980\" y=\"18\" width=\"14\" height=\"14\" fill=\"#38bdf8\"/><text x=\"1002\" y=\"30\" fill=\"#e5e7eb\" font-size=\"13\" font-family=\"Arial\">上传</text>";
        print "<rect x=\"1060\" y=\"18\" width=\"14\" height=\"14\" fill=\"#22c55e\"/><text x=\"1082\" y=\"30\" fill=\"#e5e7eb\" font-size=\"13\" font-family=\"Arial\">下载</text>";
        print "</svg>";
    }' "$data_file" > "$out_svg"
}

generate_latency_svg() {
    local data_file="$1"
    local out_svg="$2"
    awk -F',' '
    BEGIN {
        width=1280; height=480; left=80; right=40; top=40; bottom=70;
        plotW=width-left-right; plotH=height-top-bottom; n=0; maxV=0;
    }
    NR==1 { next }
    {
        n++;
        label[n]=$2;
        lat[n]=$5+0;
        jit[n]=$6+0;
        if (lat[n] > maxV) maxV=lat[n];
        if (jit[n] > maxV) maxV=jit[n];
    }
    END {
        if (maxV <= 0) maxV=1;
        print "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"" width "\" height=\"" height "\" viewBox=\"0 0 " width " " height "\">";
        print "<rect width=\"100%\" height=\"100%\" fill=\"#0f172a\"/>";
        print "<text x=\"40\" y=\"28\" fill=\"#e5e7eb\" font-size=\"22\" font-family=\"Arial\">延迟曲线（按轮次平均）</text>";
        print "<line x1=\"" left "\" y1=\"" top "\" x2=\"" left "\" y2=\"" top+plotH "\" stroke=\"#94a3b8\" stroke-width=\"1\"/>";
        print "<line x1=\"" left "\" y1=\"" top+plotH "\" x2=\"" left+plotW "\" y2=\"" top+plotH "\" stroke=\"#94a3b8\" stroke-width=\"1\"/>";
        for (i=0; i<=4; i++) {
            y=top+plotH-(plotH*i/4);
            v=maxV*i/4;
            print "<line x1=\"" left "\" y1=\"" y "\" x2=\"" left+plotW "\" y2=\"" y "\" stroke=\"#1f2937\" stroke-width=\"1\"/>";
            printf "<text x=\"18\" y=\"%.2f\" fill=\"#cbd5e1\" font-size=\"12\" font-family=\"Arial\">%.0f</text>\n", y+4, v;
        }
        if (n == 0) {
            print "<text x=\"140\" y=\"240\" fill=\"#fbbf24\" font-size=\"22\" font-family=\"Arial\">暂无双向正常样本，无法生成延迟曲线</text></svg>";
            exit;
        }
        if (n == 1) step=0; else step=plotW/(n-1);
        latPts=""; jitPts="";
        for (i=1; i<=n; i++) {
            x=left+(i-1)*step;
            yl=top+plotH-(lat[i]/maxV*plotH);
            yj=top+plotH-(jit[i]/maxV*plotH);
            latPts=latPts sprintf("%.2f,%.2f ", x, yl);
            jitPts=jitPts sprintf("%.2f,%.2f ", x, yj);
            print "<circle cx=\"" x "\" cy=\"" yl "\" r=\"4\" fill=\"#f59e0b\"/>";
            print "<circle cx=\"" x "\" cy=\"" yj "\" r=\"4\" fill=\"#a855f7\"/>";
            txt=label[i];
            printf "<text x=\"%.2f\" y=\"%d\" fill=\"#cbd5e1\" font-size=\"11\" font-family=\"Arial\" text-anchor=\"middle\">%s</text>\n", x, top+plotH+22, txt;
        }
        print "<polyline fill=\"none\" stroke=\"#f59e0b\" stroke-width=\"3\" points=\"" latPts "\"/>";
        print "<polyline fill=\"none\" stroke=\"#a855f7\" stroke-width=\"3\" points=\"" jitPts "\"/>";
        print "<rect x=\"960\" y=\"18\" width=\"14\" height=\"14\" fill=\"#f59e0b\"/><text x=\"982\" y=\"30\" fill=\"#e5e7eb\" font-size=\"13\" font-family=\"Arial\">延迟</text>";
        print "<rect x=\"1040\" y=\"18\" width=\"14\" height=\"14\" fill=\"#a855f7\"/><text x=\"1062\" y=\"30\" fill=\"#e5e7eb\" font-size=\"13\" font-family=\"Arial\">抖动</text>";
        print "</svg>";
    }' "$data_file" > "$out_svg"
}

generate_html_report() {
    local summary_file="$1"
    local speed_svg="$2"
    local latency_svg="$3"
    local out_html="$4"
    local summary_name speed_name latency_name
    summary_name=$(basename "$summary_file")
    speed_name=$(basename "$speed_svg")
    latency_name=$(basename "$latency_svg")
    cat > "$out_html" <<EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>HyperSpeed Plus 报告</title>
<style>
body{background:#020617;color:#e5e7eb;font-family:Arial,Helvetica,sans-serif;margin:0;padding:24px}
.wrap{max-width:1320px;margin:0 auto}
.card{background:#111827;border:1px solid #1f2937;border-radius:16px;padding:20px;margin-bottom:20px}
pre{white-space:pre-wrap;line-height:1.65;font-size:14px;color:#e5e7eb}
img{width:100%;height:auto;background:#0b1220;border-radius:12px;border:1px solid #1f2937}
h1,h2{margin-top:0}
a{color:#7dd3fc}
</style>
</head>
<body>
<div class="wrap">
<div class="card">
<h1>HyperSpeed Plus 分析报告</h1>
<p>同目录文件：<a href="${summary_name}">${summary_name}</a>、<a href="${speed_name}">${speed_name}</a>、<a href="${latency_name}">${latency_name}</a></p>
</div>
<div class="card">
<h2>文字分析</h2>
<pre>$(sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$summary_file")</pre>
</div>
<div class="card">
<h2>速度曲线</h2>
<img src="${speed_name}" alt="速度曲线">
</div>
<div class="card">
<h2>延迟曲线</h2>
<img src="${latency_name}" alt="延迟曲线">
</div>
</div>
</body>
</html>
EOF
}

analyze_csv_file() {
    local csv_file="$1"
    if [ ! -f "$csv_file" ]; then
        echo -e "${RED}CSV文件不存在${ENDC}"
        return 1
    fi

    local base_name round_data summary_txt speed_svg latency_svg report_html
    base_name=$(basename "$csv_file" .csv)
    round_data="${REPORT_DIR}/${base_name}-rounds.csv"
    summary_txt="${REPORT_DIR}/${base_name}-summary.txt"
    speed_svg="${REPORT_DIR}/${base_name}-speed.svg"
    latency_svg="${REPORT_DIR}/${base_name}-latency.svg"
    report_html="${REPORT_DIR}/${base_name}-report.html"

    build_round_curve_data "$csv_file" "$round_data"
    generate_summary_report "$csv_file" "$summary_txt"
    generate_speed_svg "$round_data" "$speed_svg"
    generate_latency_svg "$round_data" "$latency_svg"
    generate_html_report "$summary_txt" "$speed_svg" "$latency_svg" "$report_html"

    sed -n '1,220p' "$summary_txt"
    echo
    echo -e "${GREEN}速度曲线:${ENDC} ${speed_svg}"
    echo -e "${GREEN}延迟曲线:${ENDC} ${latency_svg}"
    echo -e "${GREEN}HTML报告:${ENDC} ${report_html}"
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
        echo "5. 分析最新CSV并生成曲线"
        echo "6. 选择CSV做分析并生成曲线"
        echo "7. 报告文件列表"
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
            7) list_reports; pause_screen ;;
            0) exit 0 ;;
            *) echo -e "${RED}无效选项${ENDC}"; sleep 1 ;;
        esac
    done
}

check_dependencies
main_menu
