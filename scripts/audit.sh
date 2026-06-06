#!/bin/bash
# ============================================================
# 管道审计 —— 检查各阶段文档/评审/门禁状态
# 轻量审计，不加载任何 skill，不扫描项目文件
# ============================================================

GATE_DIR="doc/.gate"
DOC_DIR="doc"
REVIEW_DIR="doc/review"

declare -A STAGE_DOC
STAGE_DOC[prd]="$DOC_DIR/prd"
STAGE_DOC[arch]="$DOC_DIR/arch"
STAGE_DOC[detailed]="$DOC_DIR/detailed"

declare -A STAGE_REVIEW
STAGE_REVIEW[prd]="需求评审报告"
STAGE_REVIEW[arch]="架构评审报告"
STAGE_REVIEW[detailed]="详细设计评审报告"

echo "=========================================="
echo " 📋 管道审计报告"
echo "=========================================="
echo ""

all_done=true

for stage in prd arch detailed; do
    doc_dir="${STAGE_DOC[$stage]}"
    review_key="${STAGE_REVIEW[$stage]}"
    gate_file="$GATE_DIR/${stage}.pass"
    block_file="$GATE_DIR/${stage}.blocked"

    # 文档
    doc_count=$(ls -1 "$doc_dir/"*.md 2>/dev/null | wc -l)
    has_docs=$([ "$doc_count" -gt 0 ] && echo true || echo false)

    # 评审报告
    review_count=$(ls -1 "$REVIEW_DIR/"*"$review_key"*.md 2>/dev/null | wc -l)
    has_review=$([ "$review_count" -gt 0 ] && echo true || echo false)

    # 门禁
    gate_status="⏳ 未完成"
    if [ -f "$gate_file" ]; then
        gate_status="✅ 已通过 ($(cat "$gate_file"))"
    elif [ -f "$block_file" ]; then
        gate_status="🔴 被阻断 ($(cat "$block_file"))"
        all_done=false
    else
        all_done=false
    fi

    echo "[$stage]"
    echo "  文档:    $([ "$has_docs" = true ] && echo "✅ $doc_count 个" || echo "⏳ 无")"
    echo "  评审:    $([ "$has_review" = true ] && echo "✅ $review_count 份" || echo "⏳ 无")"
    echo "  门禁:    $gate_status"

    # 建议处理
    if [ -f "$gate_file" ]; then
        echo "  状态:    无需处理"
    elif [ "$has_docs" = true ] && [ "$has_review" = false ]; then
        echo "  建议:    文档已存在，缺评审 → 加载 review-expert skill 评审"
    elif [ "$has_docs" = false ]; then
        echo "  建议:    缺文档 → 加载对应 skill 生成（prd-writer/system-architect/task-decomposer）"
    fi
    echo ""
done

echo "=========================================="
if [ "$all_done" = true ]; then
    echo " ✅ 全链路已完成"
else
    echo " 💡 部分阶段未完成，见上方建议"
fi
echo "=========================================="
