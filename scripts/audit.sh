#!/bin/bash
# ============================================================
# 管道审计 —— 检查各阶段文档/评审/门禁状态
# 轻量审计，不加载任何 skill
# ============================================================

GATE_DIR="doc/.gate"
DOC_DIR="doc"
REVIEW_DIR="doc/review"

declare -A STAGE_DOC
STAGE_DOC[prd]="$DOC_DIR/prd"
STAGE_DOC[arch]="$DOC_DIR/arch"
STAGE_DOC[detailed]="$DOC_DIR/detailed"

declare -A STAGE_REVIEW_KEY
STAGE_REVIEW_KEY[prd]="需求评审报告"
STAGE_REVIEW_KEY[arch]="架构评审报告"
STAGE_REVIEW_KEY[detailed]="详细设计评审报告"

declare -A STAGE_REVIEW_MODE
STAGE_REVIEW_MODE[prd]="需求"
STAGE_REVIEW_MODE[arch]="架构"
STAGE_REVIEW_MODE[detailed]="详细设计"

# -------------------- 评审报告深度分析 --------------------
analyze_report() {
    local report_file="$1"
    [ ! -f "$report_file" ] && return

    local conclusion=""
    local p0_count=0
    local p1_count=0

    # 解析结论（取报告中最后出现的结论标记）
    if grep -q '✅' "$report_file"; then
        conclusion="✅ 通过"
    elif grep -q '⚠️' "$report_file" || grep -q '有条件通过' "$report_file"; then
        conclusion="⚠️ 有条件通过"
    elif grep -q '❌' "$report_file" || grep -q '不通过' "$report_file"; then
        conclusion="❌ 不通过"
    fi

    # 统计 P0/P1 问题数
    p0_count=$(grep -c 'P0' "$report_file" 2>/dev/null || true)
    p1_count=$(grep -c 'P1' "$report_file" 2>/dev/null || true)

    # 取最新一轮的结论（多轮评审取最后一轮）
    local round_info=""
    local round_count=$(grep -c '轮' "$report_file" 2>/dev/null || true)
    [ "$round_count" -gt 0 ] && round_info="（第${round_count}轮）" || round_info="（单轮）"

    echo "$conclusion|$p0_count|$p1_count|$round_info"
}

# -------------------- 主逻辑 --------------------
echo "=========================================="
echo " 📋 管道审计报告"
echo "=========================================="
echo ""

all_done=true

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

    # 按修改时间排序取最新报告
    latest_report=$(ls -1t "$REVIEW_DIR/"*"$review_key"*.md 2>/dev/null | head -1)
    [ -n "$latest_report" ] && has_review=true

    if [ "$has_review" = true ]; then
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

    # 深度评审结论
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
        # 门禁已通过 → 交叉校验
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
        # 门禁未通过 → 常规建议
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
