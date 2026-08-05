-- OSC 52 剪贴板覆盖（after/plugin 在 nvim 启动序列最末加载）
-- 强制使用终端 OSC 52 转义序列传递剪贴板，无需 X11/Wayland，
-- 穿透 SSH/tmux/Docker 均可。Ghostty/iTerm2/WezTerm/Kitty/Alacritty 原生支持。
-- 覆盖 DefectingCat/nvim 0.12 可能自带的 xclip/socat 配置。
if vim.g.vscode then return end

local ok, osc52 = pcall(require, 'vim.ui.clipboard.osc52')
if not ok then return end

vim.g.clipboard = {
  name = 'OSC 52',
  copy  = { ['+'] = osc52.copy('+'),  ['*'] = osc52.copy('*')  },
  paste = { ['+'] = osc52.paste('+'), ['*'] = osc52.paste('*') },
}
vim.opt.clipboard:append('unnamedplus')
