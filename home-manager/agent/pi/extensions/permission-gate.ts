/**
 * Permission Gate Extension for Pi
 *
 * Restricts the agent to read-only access by default:
 *   - read/grep/ls/find  -> always allowed
 *   - write/edit/bash    -> requires user confirmation
 *   - any other tool     -> blocked (fail-safe)
 *
 * Confirmation dialog offers three choices:
 *   - Yes          -> allow this one call only
 *   - No (Esc)     -> block this call
 *   - Always allow -> allow all write/edit/bash calls for the rest of
 *                     this conversation (reset on /new, /resume, /reload)
 *
 * In non-interactive modes (no UI), mutating tools are blocked outright.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const READ_ONLY_TOOLS = new Set(["read", "grep", "ls", "find"]);
const MUTATING_TOOLS = new Set(["write", "edit"]);
// 安全工具（调度/状态类）：自身不直接改动文件或执行命令，副作用受到二次把关：
// - subagent 工具 spawn 的 explore 子代理只有只读工具；general 子代理的
//   write/edit/bash 在无 UI 时同样会被这里拦截。
// - todo 工具只维护会话内任务列表（session entries），不碰文件系统。
const SAFE_TOOLS = new Set(["subagent", "todo"]);

export default function (pi: ExtensionAPI) {
  // "Always allow" 状态：仅对当前对话生效
  let alwaysAllow = false;

  // 会话切换（/new、/resume、/fork 等）时重置，确保只影响同一个对话
  pi.on("session_start", () => {
    alwaysAllow = false;
  });

  pi.on("tool_call", async (event, ctx) => {
    const toolName = event.toolName;

    // 全自动模式（由 cc-connect 通过环境变量 CC_PERMISSION_MODE=yolo 注入）：
    // 直接放行所有工具，不再弹出权限确认卡片。
    if (process.env.CC_PERMISSION_MODE === "yolo") {
      return undefined;
    }

    if (READ_ONLY_TOOLS.has(toolName)) {
      return undefined;
    }

    // 安全工具放行（subagent 调度、todo 状态管理等），副作用仍受本 gate 约束
    if (SAFE_TOOLS.has(toolName)) {
      return undefined;
    }

    const isBash = toolName === "bash";
    const isMutating = MUTATING_TOOLS.has(toolName);

    if (!isBash && !isMutating) {
      return { block: true, reason: `Tool "${toolName}" is not allowed` };
    }

    // 已选择 Always allow：本次对话内直接放行
    if (alwaysAllow) {
      return undefined;
    }

    if (!ctx.hasUI) {
      return {
        block: true,
        reason: `${toolName} requires user approval (no UI available)`,
      };
    }

    const detail =
      toolName === "bash"
        ? `Command: ${(event.input as { command?: string }).command ?? ""}`
        : `Path: ${(event.input as { path?: string }).path ?? ""}`;

    const choice = await ctx.ui.select(
      `Allow ${toolName}?`,
      ["Yes", "No", "Always allow"],
    );

    if (choice === "Always allow") {
      alwaysAllow = true;
      return undefined;
    }
    if (choice !== "Yes") {
      // 选择 No 或按 Esc 取消都视为拒绝
      return { block: true, reason: "Rejected by user" };
    }

    return undefined;
  });
}
