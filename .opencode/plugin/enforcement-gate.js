const { existsSync, readdirSync } = require("fs");
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

module.exports = async ({ directory }) => {
  const projectRoot = findProjectRoot(directory);
  const stageGatePass = join(projectRoot, "doc/.gate/detailed.pass");
  const verifyDir = join(projectRoot, ".verify");

  return {
    "tool.execute.before": async (input, output) => {
      const tool = input && input.tool ? input.tool : "";
      if (!isEditTool(tool)) return;

      const filePath = output && output.args && output.args.filePath;
      if (!filePath) return;

      // Stage gate: allow doc/.opencode/scripts edits without detailed.pass
      const allowed = [
        join(projectRoot, "doc"),
        join(projectRoot, ".opencode"),
        join(projectRoot, "scripts"),
        join(homedir, ".config/opencode/skills"),
        join(homedir, ".agents/skills"),
      ];
      const relativeAllowed = ["doc/", "./doc/", ".opencode/", "./.opencode/", "scripts/", "./scripts/"];
      const isAllowed = relativeAllowed.some(p => filePath.startsWith(p)) ||
        allowed.some(dir => filePath.startsWith(dir));

      if (!isAllowed && !existsSync(stageGatePass)) {
        const msg = [
          "\u26D4 \u9636\u6BB5\u95E8\u7981\uFF1A\u8BE6\u7EC6\u8BBE\u8BA1\u672A\u5B8C\u6210\u8BC4\u5BA1",
          "\u5B8C\u6210 PRD \u2192 \u67B6\u6784 \u2192 \u8BE6\u7EC6\u8BBE\u8BA1 \u4E09\u4E2A\u9636\u6BB5\u5E76 pass \u540E\u5373\u53EF\u7F16\u8F91\u3002",
          "\u8BE6\u60C5: bash scripts/gate.sh status",
        ].join("\n");
        if (tool === "write") output.args.content = msg;
        else if (tool === "edit") {
          output.args.oldString = "___STAGE_GATE_BLOCKED___";
          output.args.newString = msg;
        }
        return;
      }

      // Verify gate: check pre-check record
      let hasPreCheck = false;
      try {
        hasPreCheck =
          existsSync(verifyDir) &&
          readdirSync(verifyDir).some(
            (f) => f.endsWith(".ini") && !f.includes(".post.")
          );
      } catch (e) {}

      if (!hasPreCheck) {
        const msg = [
          "\u26D4 \u7F16\u7801\u963B\u65AD\uFF1A\u672A\u68C0\u6D4B\u5230\u9A8C\u8BC1\u8BB0\u5F55",
          "\u59D4\u6258 coding-executor \u5B8C\u6210\u4E09\u9636\u6BB5\u6D41\u7A0B\uFF1A",
          "  bash scripts/gate.sh pre <\u6A21\u5757> <\u6587\u6863>",
        ].join("\n");
        if (tool === "write") output.args.content = msg;
        else if (tool === "edit") {
          output.args.oldString = "___VERIFY_GATE_BLOCKED___";
          output.args.newString = msg;
        }
      }
    },
  };
};
