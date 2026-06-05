#!/bin/bash
# ============================================================
# 文档阶段门禁
# 管理五个阶段的进入条件和完成标记
# 用法:
#   bash doc-gate.sh check <stage>     检查能否进入阶段
#   bash doc-gate.sh unpass <stage>    撤销通过标记（评审未通过时）
#   bash doc-gate.sh pass <stage>      标记阶段完成
#   bash doc-gate.sh status            查看全阶段状态
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

# ---- 校验评审报告 ----
validate_review_report() {
    local stage="$1"
    local review_pattern="${REVIEW_PATTERNS[$stage]:-}"

    if [ -z "$review_pattern" ]; then
        return 0  # No review needed for this stage
    fi

    # Find the report file (latest match)
    local report_file=""
    report_file=$(ls $DOC_DIR/review/$review_pattern 2>/dev/null | tail -1)

    if [ -z "$report_file" ]; then
        echo "  ❌ 未在 doc/review/ 找到评审报告"
        echo "    期望模式: doc/review/$review_pattern"
        return 1
    fi

    echo "  📄 评审报告: $(basename "$report_file")"

    # -- Parse conclusion --
    local conclusion=""
    local allow_field=""

    if [ "$stage" = "review" ]; then
        # code-reviewer format
        conclusion=$(grep -E '^\| \*\*综合结论\*\* \|' "$report_file" | sed 's/| \*\*综合结论\*\* | *//' | sed 's/ *|.*//')
    else
        # review-expert format (prd/arch/detailed)
        conclusion=$(grep -E '^\| 评审结论 \|' "$report_file" | sed 's/| 评审结论 | *//' | sed 's/ *|.*//')
    fi

    # allow field - same format in all report types
    allow_field=$(grep -E '^\| 是否允许' "$report_file" | sed 's/.*| //' | sed 's/ |.*//')

    # -- Check 1: Conclusion --
    if echo "$conclusion" | grep -qE '✅|通过'; then
        echo "  ✅ 评审结论: 通过"
    elif echo "$conclusion" | grep -qE '⚠️|有条件通过'; then
        echo "  ⚠️ 评审结论: 有条件通过"
    elif echo "$conclusion" | grep -qE '❌|不通过'; then
        echo "  ❌ 评审结论: 不通过 — 阻断"
        return 1
    else
        echo "  ⚠️  无法解析评审结论"
        echo "    原始内容: $conclusion"
        return 1
    fi

    # -- Check 2: Allow field --
    if [ -n "$allow_field" ]; then
        if echo "$allow_field" | grep -q '否'; then
            echo "  ❌ 报告明确不允许进入下一阶段 — 阻断"
            return 1
        elif echo "$allow_field" | grep -q '是'; then
            echo "  ✅ 允许进入下一阶段"
        else
            echo "  ⚠️  无法解析"是否允许"字段"
        fi
    fi

    # -- Check 3: P0 blocking items --
    # Extract section between "阻断项清单" (or "P0 致命问题") and next heading
    local p0_section
    if [ "$stage" = "review" ]; then
        p0_section=$(sed -n '/P0 致命问题/,/^## /p' "$report_file" | head -20)
    else
        p0_section=$(sed -n '/阻断项清单（P0）/,/^##\|^### [^5]\|^### 5\.3/p' "$report_file" | head -20)
    fi

    if echo "$p0_section" | grep -qE '无阻断项|无 P0'; then
        echo "  ✅ 无 P0 阻断项"
    elif echo "$p0_section" | grep -qE '^- \[ \]'; then
        local p0_count
        p0_count=$(echo "$p0_section" | grep -cE '^- \[ \]')
        echo "  ❌ 存在 $p0_count 个未修复的 P0 阻断项"
        return 1
    else
        echo "  ✅ 无 P0 阻断项（未检测到未修复项）"
    fi

    return 0
}

# ---- pass ----
do_pass() {
    local stage="$1"

    if [ -z "$stage" ]; then
        echo "用法: bash doc-gate.sh pass <stage>"
        echo "阶段: $KNOWN_STAGES"
        exit 1
    fi

    # --force 已被移除，不再支持跳过评审校验
    if [ "$stage" = "--force" ]; then
        echo "  ❌ 不再支持 --force 参数"
        echo "     评审报告校验为强制要求，请先完成 review-expert 评审"
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

    # 校验评审报告（内容级校验：结论、P0、是否允许进入）
    declare -A REVIEW_PATTERNS
    REVIEW_PATTERNS[prd]="*需求评审报告*"
    REVIEW_PATTERNS[arch]="*架构评审报告*"
    REVIEW_PATTERNS[detailed]="*详设评审报告*"
    REVIEW_PATTERNS[review]="*代码评审报告*"
    local review_pattern="${REVIEW_PATTERNS[$stage]:-}"

    if [ -n "$review_pattern" ]; then
        echo "--- 评审报告校验 ---"
        if ! validate_review_report "$stage"; then
            echo ""
            echo "  ❌ 评审报告校验未通过，[$stage] 阶段无法通过"
            exit 1
        fi
        echo ""
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
    *)
        echo "用法:"
        echo "  bash doc-gate.sh check <stage>     检查能否进入阶段"
        echo "  bash doc-gate.sh unpass <stage>    撤销通过标记（评审未通过时）"
        echo "  bash doc-gate.sh pass <stage>      标记阶段完成"
        echo "  bash doc-gate.sh status            查看全阶段状态"
        echo ""
        echo "阶段: $KNOWN_STAGES"
        echo ""
        echo "示例:"
        echo "  bash doc-gate.sh unpass detailed \"P0:字段类型与DDL不一致\""
        exit 1
        ;;
esac
fi
