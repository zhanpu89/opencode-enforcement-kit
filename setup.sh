#!/bin/bash
# ============================================================
# 编码门禁套件 —— 一键植入/更新目标项目
# 本文件所在目录即为唯一源，setup.sh 确保目标与源一致
# 用法: bash setup.sh [目标项目路径]
#       默认目标为当前目录（自愈模式）
#       指定路径则为安装到其他项目
#       可安全重复执行（幂等）
# ============================================================
set -e

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-.}"
TARGET="$(cd "$TARGET" && pwd)"

# Safe copy: skip if source and target are the same file
safe_cp() {
    if [ "$1" != "$2" ]; then
        cp "$1" "$2"
    fi
}

echo "=========================================="
echo " 🔒 编码门禁套件植入/更新"
echo "   源: $KIT_DIR"
echo "   目标: $TARGET"
echo "=========================================="
echo ""

# ---- 1. 门禁脚本 ----
echo "[1/7] 复制 scripts...（gate.sh + doc-gate.sh + verify-coding.sh）"
mkdir -p "$TARGET/scripts"
safe_cp "$KIT_DIR/scripts/gate.sh" "$TARGET/scripts/gate.sh"
chmod +x "$TARGET/scripts/gate.sh"
safe_cp "$KIT_DIR/scripts/doc-gate.sh" "$TARGET/scripts/doc-gate.sh"
chmod +x "$TARGET/scripts/doc-gate.sh"
safe_cp "$KIT_DIR/scripts/verify-coding.sh" "$TARGET/scripts/verify-coding.sh"
chmod +x "$TARGET/scripts/verify-coding.sh"
echo "  ✅ scripts/gate.sh（统一入口）"
echo "  ✅ scripts/doc-gate.sh"
echo "  ✅ scripts/verify-coding.sh"

# ---- 2. agents ----
echo "[2/7] 复制 agents...（coding-executor + verify-agent）"
mkdir -p "$TARGET/.opencode/agent"
safe_cp "$KIT_DIR/.opencode/agent/coding-executor.md" "$TARGET/.opencode/agent/coding-executor.md"
safe_cp "$KIT_DIR/.opencode/agent/verify-agent.md" "$TARGET/.opencode/agent/verify-agent.md"
echo "  ✅ .opencode/agent/coding-executor.md"
echo "  ✅ .opencode/agent/verify-agent.md"

# ---- 3. plugins ----
echo "[3/7] 复制 plugins...（stage-gate.js + verify-gate.js）"
mkdir -p "$TARGET/.opencode/plugin"
safe_cp "$KIT_DIR/.opencode/plugin/stage-gate.js" "$TARGET/.opencode/plugin/stage-gate.js"
safe_cp "$KIT_DIR/.opencode/plugin/verify-gate.js" "$TARGET/.opencode/plugin/verify-gate.js"
echo "  ✅ .opencode/plugin/stage-gate.js"
echo "  ✅ .opencode/plugin/verify-gate.js"

# ---- 4. skills ----
echo "[4/7] 复制 skills...（prd-writer / system-architect / task-decomposer / code-reviewer / review-expert / audit-system）"
if [ -d "$KIT_DIR/.opencode/skills" ]; then
    mkdir -p "$TARGET/.opencode/skills"
    cp -r "$KIT_DIR/.opencode/skills/"* "$TARGET/.opencode/skills/"
    echo "  ✅ .opencode/skills/"
fi

# ---- 5. .opencode/rules 规则文件 ----
echo "[5/7] 复制 rules...（coding-rules.md + endpoint-lock.md + precise-location.md）"
if [ -d "$KIT_DIR/.opencode/rules" ]; then
    mkdir -p "$TARGET/.opencode/rules"
    safe_cp "$KIT_DIR/.opencode/rules/coding-rules.md" "$TARGET/.opencode/rules/coding-rules.md"
    safe_cp "$KIT_DIR/.opencode/rules/endpoint-lock.md" "$TARGET/.opencode/rules/endpoint-lock.md"
    safe_cp "$KIT_DIR/.opencode/rules/precise-location.md" "$TARGET/.opencode/rules/precise-location.md"
    echo "  ✅ .opencode/rules/coding-rules.md"
    echo "  ✅ .opencode/rules/endpoint-lock.md"
    echo "  ✅ .opencode/rules/precise-location.md"
fi

# ---- 6. opencode.json（幂等合并） ----
echo "[6/7] 处理 opencode.json..."

if [ -f "$TARGET/opencode.json" ]; then
    TARGET="$TARGET" KIT_DIR="$KIT_DIR" node -e '
const fs = require("fs");
const targetPath = process.env.TARGET + "/opencode.json";
const kitPath = process.env.KIT_DIR + "/opencode.json";

let target, kit;
try {
    target = JSON.parse(fs.readFileSync(targetPath, "utf-8"));
    kit = JSON.parse(fs.readFileSync(kitPath, "utf-8"));
} catch (e) {
    console.error("  ❌ JSON 解析失败:", e.message);
    process.exit(1);
}

// 合并 instructions —— 添加 .opencode/rules/ 全局匹配
if (!Array.isArray(target.instructions)) {
    target.instructions = [];
}
if (!target.instructions.includes(".opencode/rules/*.md")) {
    target.instructions.unshift(".opencode/rules/*.md");
}

// 合并 agent —— 以 kit 为准
if (typeof target.agent !== "object" || target.agent === null) {
    target.agent = {};
}
for (const name of ["coding-executor", "verify-agent"]) {
    if (kit.agent[name]) {
        target.agent[name] = JSON.parse(JSON.stringify(kit.agent[name]));
    }
}

// 合并 permission —— 补充门禁必需项，保留用户已有配置
if (typeof target.permission !== "object" || target.permission === null) {
    target.permission = {};
}
target.permission.edit = "ask";
if (typeof target.permission.bash !== "object" || target.permission.bash === null) {
    target.permission.bash = {};
}
target.permission.bash["scripts/gate.sh *"] = "allow";
target.permission.bash["scripts/verify-coding.sh *"] = "allow";
target.permission.bash["scripts/doc-gate.sh *"] = "allow";
if (!target.permission.bash["*"]) {
    target.permission.bash["*"] = "ask";
}

// 合并 plugin —— stage-gate + verify-gate
if (!Array.isArray(target.plugin)) {
    target.plugin = [];
}
const addPlugins = [".opencode/plugin/stage-gate.js", ".opencode/plugin/verify-gate.js"];
for (const p of addPlugins) {
    if (!target.plugin.includes(p)) {
        target.plugin.push(p);
    }
}

fs.writeFileSync(targetPath, JSON.stringify(target, null, 2) + "\n");
console.log("  ✅ opencode.json 已合并");
'
else
    cp "$KIT_DIR/opencode.json" "$TARGET/opencode.json"
    echo "  ✅ opencode.json 已创建"
fi


# ---- 7. .gitignore ----
echo "[7/7] 处理 .gitignore..."
TARGET_GITIGNORE="$TARGET/.gitignore"
append_gitignore_entry() {
    local entry="$1"
    if ! grep -qF "$entry" "$TARGET_GITIGNORE" 2>/dev/null; then
        echo "$entry" >> "$TARGET_GITIGNORE"
    fi
}

if [ -f "$TARGET_GITIGNORE" ]; then
    append_gitignore_entry ""
    append_gitignore_entry "# opencode-enforcement-kit state files"
    append_gitignore_entry ".verify/"
    append_gitignore_entry "doc/.gate/"
    echo "  ✅ .gitignore 已追加"
else
    {
        echo ""
        echo "# opencode-enforcement-kit state files"
        echo ".verify/"
        echo "doc/.gate/"
    } > "$TARGET_GITIGNORE"
    echo "  ✅ .gitignore 已创建"
fi

echo ""
echo "=========================================="
echo " ✅ 植入/更新完成"
echo ""
echo "请重启 opencode 后生效。"
echo "=========================================="
