#!/bin/bash
# ============================================================
# 文档阶段门禁
# 管理五个阶段的进入条件和完成标记
# 用法:
#   bash doc-gate.sh check <stage>     检查能否进入阶段
#   bash doc-gate.sh unpass <stage>    撤销通过标记（评审未通过时）
#   bash doc-gate.sh pass <stage>      标记阶段完成
#   bash doc-gate.sh status            查看全阶段状态
#   bash doc-gate.sh audit             全链路审计
# ============================================================
set -e

GATE_DIR="doc/.gate"
DOC_DIR="doc"

ensure_gate_dir() {
    mkdir -p "$GATE_DIR"
}

# ---- 阶段定义 ----
# 每个阶段的进入条件（upstream）和产出物检查
declare -A UPSTREAM
UPSTREAM[prd]=""                    # 起点，无上游
UPSTREAM[arch]="prd"
UPSTREAM[detailed]="arch"
UPSTREAM[code]="detailed"
UPSTREAM[review]="code"

declare -A OUTPUT
OUTPUT[prd]="$DOC_DIR/prd/*.md"
OUTPUT[arch]="$DOC_DIR/arch/*.md"
OUTPUT[detailed]="$DOC_DIR/detailed/*.md"
OUTPUT[code]="src/"                 # 代码存在性
OUTPUT[review]="$DOC_DIR/review/*_代码评审报告.md"

# 所有已知阶段（用于输入校验）
KNOWN_STAGES="prd arch detailed code review"

# ---- check ----
do_check() {
    local stage="$1"

    if [ -z "$stage" ]; then
        echo "用法: bash doc-gate.sh check <stage>"
        echo "阶段: $KNOWN_STAGES"
        exit 1
    fi

    # 校验阶段名是否合法
    if ! echo "$KNOWN_STAGES" | grep -qw -- "$stage"; then
        echo "  ❌ 未知阶段: [$stage]"
        echo "     合法阶段: $KNOWN_STAGES"
        exit 1
    fi

    local upstream="${UPSTREAM[$stage]}"
    local output_pattern="${OUTPUT[$stage]}"

    echo "=========================================="
    echo " 🔍 [阶段门禁] 检查: $stage"
    echo "=========================================="

    # 查上游是否通过
    if [ -n "$upstream" ]; then
        local upstream_gate="$GATE_DIR/${upstream}.pass"
        if [ ! -f "$upstream_gate" ]; then
            echo "  ❌ 上游阶段 [$upstream] 未完成"
            echo "     缺少: $upstream_gate"
            echo "     请先完成 $upstream 阶段并通过评审"
            exit 1
        fi
        echo "  ✅ 上游 [$upstream] 已通过"
    fi

    # 查当前阶段是否被阻塞（评审未通过）
    local blocked_file="$GATE_DIR/${stage}.blocked"
    if [ -f "$blocked_file" ]; then
        echo "  🔴 本阶段已被阻断"
        echo "     原因: $(cat "$blocked_file")"
        echo "     请先修复问题，然后执行: bash doc-gate.sh pass $stage"
        exit 1
    fi

    # 查下游阶段是否存在已完成的（防止倒退）
    local downstream_blocked=false
    for s in prd arch detailed code review; do
        local g="$GATE_DIR/${s}.pass"
        if [ "$s" = "$stage" ]; then
            break
        fi
        if [ -f "$g" ]; then
            echo "  ⚠️  下游 [$s] 已完成，不能倒退修改"
            downstream_blocked=true
        fi
    done

    echo ""
    echo "  ✅ 可以进入 [$stage] 阶段"
}

# ---- unpass ----
do_unpass() {
    local stage="$1"
    shift
    local reason="$*"

    if [ -z "$stage" ]; then
        echo "用法: bash doc-gate.sh unpass <stage> [原因...]"
        echo "阶段: $KNOWN_STAGES"
        exit 1
    fi

    # 校验阶段名是否合法
    if ! echo "$KNOWN_STAGES" | grep -qw -- "$stage"; then
        echo "  ❌ 未知阶段: [$stage]"
        echo "     合法阶段: $KNOWN_STAGES"
        exit 1
    fi

    ensure_gate_dir

    local gate_file="$GATE_DIR/${stage}.pass"
    if [ ! -f "$gate_file" ]; then
        echo "  ⏭️  [$stage] 尚未通过，无需撤销"
        exit 0
    fi

    # 记录阻断原因
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$ts | $reason" > "$GATE_DIR/${stage}.blocked"

    # 删除通过标记
    rm "$gate_file"

    echo "  🔄 [$stage] 已撤销通过标记"
    echo "    原因: ${reason:-未指定}"
    echo ""
    echo "  请修复问题后重新:"
    echo "    bash doc-gate.sh pass $stage"
}

# ---- 下一阶段提示 ----
next_stage_hint() {
    case "$1" in
        prd)     echo "bash gate.sh check arch → 使用 system-architect 写架构文档" ;;
        arch)    echo "bash gate.sh check detailed → 使用 task-decomposer 写详细设计" ;;
        detailed) echo "bash gate.sh check code → 使用 coding-executor 编码（需 gate.sh pre 开始）" ;;
        review)  echo "🎉 所有阶段已完成，管道结束" ;;
        *)       echo "未知阶段" ;;
    esac
}

# ---- pass ----
do_pass() {
    local stage="$1"

    if [ -z "$stage" ]; then
        echo "用法: bash doc-gate.sh pass <stage>"
        echo "阶段: $KNOWN_STAGES"
        exit 1
    fi

    # 校验阶段名是否合法
    if ! echo "$KNOWN_STAGES" | grep -qw -- "$stage"; then
        echo "  ❌ 未知阶段: [$stage]"
        echo "     合法阶段: $KNOWN_STAGES"
        exit 1
    fi

    # code 阶段由 verify-coding.sh 管理
    if [ "$stage" = "code" ]; then
        if ls .verify/*.post.ini 2>/dev/null | grep -q .; then
            echo "✅ code 阶段已完成（由 verify-coding.sh 管理）"
            exit 0
        else
            echo "❌ code 阶段未完成 - 未找到 .verify/*.post.ini"
            echo "   请运行 bash scripts/gate.sh post <module> '<报告>' 完成验证"
            exit 1
        fi
    fi

    # --force 已废弃
    if [ "$stage" = "--force" ]; then
        echo "  ❌ 不再支持 --force 参数"
        exit 1
    fi

    ensure_gate_dir

    local gate_file="$GATE_DIR/${stage}.pass"
    if [ -f "$gate_file" ]; then
        echo "  ⏭️  [$stage] 已完成，跳过"
        exit 0
    fi

    # 产出物检查
    local output_pattern="${OUTPUT[$stage]}"
    local has_output=false
    case "$stage" in
        prd|arch|detailed|review)
            if ls $output_pattern 2>/dev/null | grep -q .; then
                has_output=true
            fi
            ;;
    esac

    if [ "$has_output" = false ]; then
        echo "  ❌ 未找到 [$stage] 阶段的产出物"
        echo "     期望: $output_pattern"
        exit 1
    fi

    # 清除阻断记录（如果有）
    rm -f "$GATE_DIR/${stage}.blocked"

    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$gate_file"
    echo "  ✅ [$stage] 阶段通过，已标记完成"
    echo ""
    echo "  下一阶段: $(next_stage_hint $stage)"
}

# ---- status ----
do_status() {
    ensure_gate_dir

    echo "=========================================="
    echo " 📋 阶段门禁状态"
    echo "=========================================="
    echo ""

    local all_done=true
    for s in prd arch detailed code review; do
        local gate_file="$GATE_DIR/${s}.pass"
        local output_pattern="${OUTPUT[$s]}"
        local has_output=false

        case "$s" in
            prd|arch|detailed|review)
                if ls $output_pattern 2>/dev/null | grep -q .; then
                    has_output=true
                fi
                ;;
            code)
                if [ -d "src" ]; then
                    has_output=true
                fi
                ;;
        esac

        local gate_status
        local blocked_file="$GATE_DIR/${s}.blocked"
        if [ -f "$gate_file" ]; then
            gate_status="✅ 通过 ($(cat "$gate_file"))"
        elif [ -f "$blocked_file" ]; then
            gate_status="🔴 阻断 ($(cat "$blocked_file"))"
            all_done=false
        else
            gate_status="⏳ 未完成"
            all_done=false
        fi

        printf "  %-10s  产出: %-5s  门禁: %s\n" "[$s]" "$( $has_output && echo '有' || echo '无' )" "$gate_status"
    done

    echo ""
    if [ "$all_done" = true ]; then
        echo " 🎉 所有阶段已完成"
    else
        echo " 💡 仍有阶段未完成"
    fi
}

# ---- diagnose ----
do_diagnose() {
    echo "=========================================="
    echo " 🔍 门禁诊断"
    echo "=========================================="
    echo ""

    # Check .verify/ directory
    if [ -d ".verify" ]; then
        local pre_files=()
        local post_files=()
        for f in .verify/*.ini; do
            if [ -f "$f" ]; then
                if echo "$f" | grep -q '.post.'; then
                    post_files+=("$f")
                else
                    pre_files+=("$f")
                fi
            fi
        done
        echo "📁 .verify/ 目录:"
        if [ ${#pre_files[@]} -gt 0 ]; then
            for f in "${pre_files[@]}"; do
                echo "   ⏳ 编码前验证: $f"
            done
        fi
        if [ ${#post_files[@]} -gt 0 ]; then
            for f in "${post_files[@]}"; do
                echo "   ✅ 编码后验证: $f"
            done
        fi
        if [ ${#pre_files[@]} -eq 0 ] && [ ${#post_files[@]} -eq 0 ]; then
            echo "   (空)"
        fi
    else
        echo "📁 .verify/ 目录不存在"
    fi
    echo ""

    # Check doc/.gate/ directory
    if [ -d "doc/.gate" ]; then
        echo "📁 doc/.gate/ 阶段门禁:"
    for s in prd arch detailed code review; do
            local pass_file="doc/.gate/${s}.pass"
            local block_file="doc/.gate/${s}.blocked"
            if [ -f "$pass_file" ]; then
                echo "   ✅ [$s] 已通过 ($(cat "$pass_file"))"
            elif [ -f "$block_file" ]; then
                echo "   🔴 [$s] 被阻断 ($(cat "$block_file"))"
            else
                echo "   ⏳ [$s] 未完成"
            fi
        done
    else
        echo "📁 doc/.gate/ 目录不存在"
        echo "   请先创建设计文档并通过评审"
    fi
    echo ""

    # Check if detailed.pass exists (needed for coding)
    if [ -f "doc/.gate/detailed.pass" ]; then
        echo "✅ 可以开始编码（详细设计已通过评审）"
        if [ -d ".verify" ] && ls .verify/*.ini 2>/dev/null | grep -qv '.post.'; then
            echo "✅ 编码前验证已完成，可以编辑文件"
        else
            echo "⏳ 需要先运行: bash scripts/gate.sh pre <模块> <文档>"
        fi
    else
        echo "⏳ 详细设计尚未通过评审，无法编码"
        echo "   请先完成 prd → arch → detailed 阶段"
    fi
}

# ---- 审计辅助函数 ----
analyze_report() {
    local report_file="$1"
    [ ! -f "$report_file" ] && return

    local conclusion=""
    local p0_count=0
    local p1_count=0

    if grep -q '✅' "$report_file"; then
        conclusion="✅ 通过"
    elif grep -q '⚠️' "$report_file" || grep -q '有条件通过' "$report_file"; then
        conclusion="⚠️ 有条件通过"
    elif grep -q '❌' "$report_file" || grep -q '不通过' "$report_file"; then
        conclusion="❌ 不通过"
    fi

    p0_count=$(grep -c '\[P0-' "$report_file" 2>/dev/null || true)
    p1_count=$(grep -c '\[P1-' "$report_file" 2>/dev/null || true)

    local round_info=""
    local round_count=$(grep -c '轮' "$report_file" 2>/dev/null || true)
    [ "$round_count" -gt 0 ] && round_info="（第${round_count}轮）" || round_info="（单轮）"

    echo "$conclusion|$p0_count|$p1_count|$round_info"
}

# ---- audit ----
do_audit() {
    local stage
    local doc_dir
    local review_key
    local review_mode
    local gate_file
    local block_file

    REVIEW_DIR="$DOC_DIR/review"

    echo "=========================================="
    echo " 📋 管道审计报告"
    echo "=========================================="
    echo ""

    local all_done=true

    for stage in prd arch detailed; do
        doc_dir="${STAGE_DOC[$stage]}"
        review_key="${STAGE_REVIEW_KEY[$stage]}"
        review_mode="${STAGE_REVIEW_MODE[$stage]}"
        gate_file="$GATE_DIR/${stage}.pass"
        block_file="$GATE_DIR/${stage}.blocked"

        # ---- 文档 ----
        doc_count=$(ls -1 "$doc_dir/"*.md 2>/dev/null | wc -l)
        has_docs=false
        [ "$doc_count" -gt 0 ] && has_docs=true

        # ---- 评审报告（取最新一份做深度分析） ----
        latest_report=""
        has_review=false
        conclusion=""
        p0_count=0
        p1_count=0
        round_info=""

        latest_report=$(ls -1t "$REVIEW_DIR/"*"$review_key"*.md 2>/dev/null | head -1)
        [ -n "$latest_report" ] && has_review=true

        if [ "$has_review" = true ]; then
            local report_data
            report_data=$(analyze_report "$latest_report")
            conclusion=$(echo "$report_data" | cut -d'|' -f1)
            p0_count=$(echo "$report_data" | cut -d'|' -f2)
            p1_count=$(echo "$report_data" | cut -d'|' -f3)
            round_info=$(echo "$report_data" | cut -d'|' -f4)
        fi

        # ---- 多轮报告检测 ----
        multi_round=false
        report_count=$(ls -1 "$REVIEW_DIR/"*"$review_key"*.md 2>/dev/null | wc -l)
        [ "$report_count" -gt 1 ] && multi_round=true

        # ---- 门禁 ----
        gate_status="⏳ 未完成"
        if [ -f "$gate_file" ]; then
            gate_status="✅ 已通过 ($(cat "$gate_file"))"
        elif [ -f "$block_file" ]; then
            gate_status="🔴 被阻断 ($(cat "$block_file"))"
            all_done=false
        else
            all_done=false
        fi

        # ---- 输出 ----
        echo "[$stage]"
        echo "  文档:    $([ "$has_docs" = true ] && echo "✅ $doc_count 个" || echo "⏳ 无")"
        echo "  评审:    $([ "$has_review" = true ] && echo "✅ $report_count 份" || echo "⏳ 无")"

        if [ "$has_review" = true ]; then
            echo "  结论:    $conclusion $round_info"
            echo "  P0:      $p0_count 个"
            echo "  P1:      $p1_count 个"
        fi
        if [ "$multi_round" = true ]; then
            echo "  多轮:    ✅ 存在多轮评审报告"
        fi

        echo "  门禁:    $gate_status"

        # ---- 交叉校验与建议 ----
        warnings=""
        status="✅ 正常"

        if [ -f "$gate_file" ]; then
            if [ "$has_review" = false ]; then
                warnings='⚠️ 门禁已通过但无评审报告（可能为伪造）'
                status="⚠️ 异常"
                all_done=false
            elif echo "$conclusion" | grep -q '❌'; then
                warnings='❌ 门禁已通过但评审结论为不通过'
                status="❌ 异常"
                all_done=false
            elif [ "$p0_count" -gt 0 ] && echo "$conclusion" | grep -q '✅'; then
                warnings='⚠️ 评审结论通过但存在 P0 问题（结论与内容不一致）'
                status="⚠️ 异常"
                all_done=false
            elif [ "$p0_count" -gt 0 ]; then
                warnings="⚠️ 有 $p0_count 个 P0 未修复"
                status="⚠️ 异常"
                all_done=false
            fi
        else
            if [ "$has_review" = true ]; then
                if echo "$conclusion" | grep -q '❌'; then
                    warnings="❌ 评审不通过（有 P0 阻断），需修复后重评"
                    status="❌ 阻断"
                elif echo "$conclusion" | grep -q '⚠️'; then
                    warnings="⚠️ 有条件通过，可 gate.sh pass $stage 推进"
                    status="⚠️ 待推进"
                elif [ -z "$conclusion" ]; then
                    warnings="⚠️ 无法解析评审结论"
                    status="⚠️ 异常"
                else
                    warnings="✅ 评审通过，运行 gate.sh pass $stage"
                    status="✅ 待推进"
                fi
            elif [ "$has_docs" = true ]; then
                warnings="缺评审 → 加载 review-expert 做${review_mode}评审"
                status="⏳ 缺评审"
            else
                warnings="缺文档 → 加载对应 skill 生成"
                status="⏳ 缺文档"
            fi
            all_done=false
        fi

        echo "  状态:    $status"
        [ -n "$warnings" ] && echo "  建议:    $warnings"
        echo ""
    done

    echo "=========================================="
    if [ "$all_done" = true ]; then
        echo " ✅ 全链路审计通过"
    else
        echo " 💡 存在异常或未完成项，见上方建议"
    fi
    echo "=========================================="
}

# ---- main (仅在直接执行时触发，source 时不触发) ----
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
case "${1:-}" in
    check)
        shift; do_check "$@"
        ;;
    unpass)
        shift; do_unpass "$@"
        ;;
    pass)
        shift; do_pass "$@"
        ;;
    status)
        do_status
        ;;
    diagnose)
        do_diagnose
        ;;
    audit)
        do_audit
        ;;
    *)
        echo "用法:"
        echo "  bash doc-gate.sh check <stage>     检查能否进入阶段"
        echo "  bash doc-gate.sh unpass <stage>    撤销通过标记（评审未通过时）"
        echo "  bash doc-gate.sh pass <stage>      标记阶段完成"
        echo "  bash doc-gate.sh status            查看全阶段状态"
        echo "  bash doc-gate.sh audit             全链路审计"
        echo ""
        echo "阶段: $KNOWN_STAGES"
        echo ""
        echo "示例:"
        echo "  bash doc-gate.sh unpass detailed \"P0:字段类型与DDL不一致\""
        exit 1
        ;;
esac
fi
