/**
 * 编码验证门禁插件
 *
 * 拦截 edit/write 工具，检测是否已完成编码前验证。
 * 未验证时自动将文件内容替换为阻断提示。
 *
 * 工作原理：
 *   1. 模型调用 edit/write 工具时触发
 *   2. 检查 .verify/ 目录下是否有前置验证记录
 *   3. 无记录 → 阻断，文件内容被替换为警告信息
 *   4. 有记录 → 正常放行
 */
const { existsSync, readdirSync } = require("fs");
const { join } = require("path");

const isEditTool = (tool) =>
  tool === "edit" || tool === "write";

function findProjectRoot(start) {
  let dir = start;
  while (dir && dir !== "/") {
    if (
      existsSync(join(dir, "opencode.json")) ||
      existsSync(join(dir, ".opencode"))
    ) {
      return dir;
    }
    dir = join(dir, "..");
  }
  return start;
}

module.exports = async ({ directory }) => {
  const projectRoot = findProjectRoot(directory);

  return {
    "tool.execute.before": async (input, output) => {
      const tool = input && input.tool ? input.tool : "";
      if (!isEditTool(tool)) return;

      const verifyDir = join(projectRoot, ".verify");
      let hasPreCheck = false;
      try {
        hasPreCheck =
          existsSync(verifyDir) &&
          readdirSync(verifyDir).some(
            (f) => f.endsWith(".ini") && !f.includes(".post.")
          );
      } catch (e) {
        // .verify/ 不可读时放行（避免插件崩溃），由 gate.sh pre 重新创建
      }

      if (hasPreCheck) return;

      const blockMsg = [
        "⛔ 编码阻断：未检测到验证记录",
        "",
        "编辑代码前必须先委托 coding-executor 完成三阶段流程：",
        "",
        "  1. 加载记忆 → memory_init_session()",
        "  2. 编码前验证 → bash scripts/gate.sh pre <模块名> <相关文档路径>",
        "  3. 验证通过后即可正常编辑",
        "",
        "委托 coding-executor 后，它会自动处理以上步骤。",
        "（零号铁律：禁止直接编辑，必须走 coding-executor）",
        "",
      ].join("\n");

      if (tool === "write" && output && output.args) {
        // Replace content with block message
        output.args.content = blockMsg;
      } else if (tool === "edit" && output && output.args) {
        // Primary: make oldString unmatchable so the edit fails
        output.args.oldString =
          "___VERIFY_GATE_BLOCKED___THIS_STRING_WILL_NEVER_MATCH___";
        // Fallback: replace newString with block message in case oldString ever matches
        output.args.newString = blockMsg;
      }
    },
  };
};
