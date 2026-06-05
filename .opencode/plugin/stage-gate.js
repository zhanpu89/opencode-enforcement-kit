/**
 * 阶段门禁插件
 *
 * 检查编辑目标是否对应合理的开发阶段。
 * doc/ 目录的编辑始终放行；src/ 等代码目录需要
 * doc/.gate/detailed.pass 存在才能编辑。
 */
const { existsSync } = require("fs");
const { join } = require("path");
const homedir = require("os").homedir();

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

function shouldBlock(filePath, projectRoot) {
  const allowed = [
    join(projectRoot, "doc"),
    join(projectRoot, ".opencode"),
    join(projectRoot, "scripts"),
    join(homedir, ".config/opencode/skills"),
    join(homedir, ".agents/skills"),
  ];
  // Also allow relative paths (for when OpenCode sends relative paths)
  const relativeAllowed = ["doc/", "./doc/", ".opencode/", "./.opencode/", "scripts/", "./scripts/"];
  if (relativeAllowed.some(p => filePath.startsWith(p))) {
    return false;
  }
  return !allowed.some(dir => filePath.startsWith(dir));
}

module.exports = async ({ directory }) => {
  const projectRoot = findProjectRoot(directory);

  return {
    "tool.execute.before": async (input, output) => {
      const tool = input && input.tool ? input.tool : "";
      if (!isEditTool(tool)) return;

      const filePath = output && output.args && output.args.filePath;
      if (!filePath) return;

      // Only check gates for code/config files outside doc/.opencode/scripts/
      if (!shouldBlock(filePath, projectRoot)) return;

      const detailedPass = join(projectRoot, "doc/.gate/detailed.pass");
      if (existsSync(detailedPass)) return;

      const blockMsg = [
        "⛔ 阶段门禁阻断：详细设计未完成评审",
        "",
        "编辑代码前必须先完成以下三个阶段：",
        "",
        "  1. PRD 阶段  → doc/prd/     → review-expert 评审归零",
        "  2. 架构阶段   → doc/arch/    → review-expert 评审归零",
        "  3. 详细设计   → doc/detailed/ → review-expert 评审归零",
        "",
        "每个阶段完成后需执行:",
        "  bash scripts/gate.sh pass <stage>",
        "",
        "当 doc/.gate/detailed.pass 存在后即可正常编码。",
        "",
      ].join("\n");

      if (tool === "write" && output && output.args) {
        output.args.content = blockMsg;
      } else if (tool === "edit" && output && output.args) {
        output.args.oldString =
          "___STAGE_GATE_BLOCKED___THIS_STRING_WILL_NEVER_MATCH___";
        output.args.newString = blockMsg;
      }
    },
  };
};
