/**
 * confirm-writes.mjs — dsh 权限策略插件
 *
 * 策略:与 pi 相同的权限模型
 *   - 读操作(read / read_image / fs_search / skill / web 等):默认放行
 *   - 写操作(write / edit / str_replace_editor)与命令执行(bash / pwsh /
 *     terminal_send):每次调用前发起 approval 询问(web UI 弹窗)
 *
 * 实现机制:监听 tools/pre-execute 瀑布,对写/执行类工具返回 { kind: 'ask' },
 * dsh 工具管线会将其转交给 ctx.approval;web UI 的 apiproxy 提供 human
 * answerer,批准一次(allowed-once)才放行,拒绝/取消则工具收到拒绝结果。
 *
 * 零依赖纯 ESM:不 import 任何 dsh/cordis 包,由 loader 经相对路径加载。
 */
export const name = 'confirm-writes'
export const inject = ['tools']

/** 默认需要询问的工具名单(文件写 + 命令执行)。 */
const DEFAULT_ASK_TOOLS = [
  // 文件写入
  'write', 'edit', 'str_replace_editor',
  // 命令执行
  'bash', 'pwsh', 'terminal_send',
]

/**
 * @param ctx    cordis 上下文(tools 服务、approval 服务等)
 * @param config 可选配置:
 *   - askTools: string[] 覆盖默认询问名单
 *   - reason:   string   询问理由模板(拼在工具名后)
 */
export function apply(ctx, config = {}) {
  const askTools = new Set(config.askTools ?? DEFAULT_ASK_TOOLS)
  const reasonSuffix = config.reason ?? 'requires your approval (write/execute)'

  ctx.on('tools/pre-execute', async (exec, next) => {
    if (askTools.has(exec.name)) {
      return { kind: 'ask', reason: `tool "${exec.name}" ${reasonSuffix}` }
    }
    return next()
  })
}
