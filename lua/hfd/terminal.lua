local M = {}

local terminals = {}
local active_id = 1

M.config = {
  layout = "float", -- "float" or "horizontal"
  height = 15,
  shell = vim.o.shell,
}

local function resolve_target_dir()
  local buf = vim.api.nvim_get_current_buf()
  local buftype = vim.bo[buf].buftype
  local file_path = vim.api.nvim_buf_get_name(buf)

  if buftype ~= "" or file_path == "" then
    return vim.uv.os_homedir()
  end

  local dir = vim.fn.fnamemodify(file_path, ":p:h")
  if vim.fn.isdirectory(dir) == 1 then
    return dir
  end

  return vim.uv.os_homedir()
end

local function close_window(id)
  local term = terminals[id]
  if term and term.win and vim.api.nvim_win_is_valid(term.win) then
    vim.api.nvim_win_close(term.win, true)
    term.win = nil
  end
end

local function find_open_window()
  for id, term in pairs(terminals) do
    if term.win and vim.api.nvim_win_is_valid(term.win) then
      return id
    end
  end
  return nil
end

local function open_float_window(buf, id, cwd)
  local ui = vim.api.nvim_list_uis()[1]
  local width = math.floor(ui.width * 0.8)
  local height = math.floor(ui.height * 0.75)

  return vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((ui.height - height) / 2),
    col = math.floor((ui.width - width) / 2),
    style = "minimal",
    border = "rounded",
    title = (" hfd-terminal [%d] — %s "):format(id, vim.fn.fnamemodify(cwd, ":t")),
    title_pos = "center",
  })
end

local function open_horizontal_window(buf)
  vim.cmd("botright " .. M.config.height .. "split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  return win
end

function M.open(id, opts)
  opts = opts or {}
  id = tonumber(id) or active_id
  local open_id = find_open_window()

  if opts.toggle ~= false and open_id == id then
    close_window(id)
    return
  end

  if open_id and open_id ~= id then
    close_window(open_id)
  end

  active_id = id
  terminals[id] = terminals[id] or {}
  local term = terminals[id]

  local is_new = false
  if not term.buf or not vim.api.nvim_buf_is_valid(term.buf) then
    term.buf = vim.api.nvim_create_buf(false, true)
    term.cwd = resolve_target_dir()
    is_new = true
  end

  if not term.win or not vim.api.nvim_win_is_valid(term.win) then
    if M.config.layout == "horizontal" then
      term.win = open_horizontal_window(term.buf)
    else
      term.win = open_float_window(term.buf, id, term.cwd or resolve_target_dir())
    end
  else
    vim.api.nvim_set_current_win(term.win)
  end

  if is_new then
    local job_id = vim.fn.jobstart(M.config.shell, {
      term = true,
      cwd = term.cwd,
      on_exit = function()
        vim.schedule(function()
          close_window(id)
          if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
            vim.api.nvim_buf_delete(term.buf, { force = true })
          end
          terminals[id] = nil
        end)
      end,
    })
    term.job_id = job_id
  end

  vim.cmd("startinsert")
end

function M.send_command(cmd, id)
  if not cmd or cmd == "" then
    vim.notify("Please provide a command to send. Example: :HfdTerminal C cargo run", vim.log.levels.WARN)
    return
  end

  id = tonumber(id) or active_id
  if find_open_window() ~= id then
    M.open(id, { toggle = false })
  end

  local term = terminals[id]
  if not term or not term.buf or not vim.api.nvim_buf_is_valid(term.buf) then
    vim.notify("Failed to initialize terminal channel.", vim.log.levels.ERROR)
    return
  end

  vim.defer_fn(function()
    if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
      local chan = vim.bo[term.buf].channel
      if chan and chan > 0 then
        vim.fn.chansend(chan, cmd .. "\r")
        vim.cmd("startinsert")
      end
    end
  end, 80)
end

function M.list()
  local lines = {}
  local ids = {}

  for id, term in pairs(terminals) do
    if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
      table.insert(ids, id)
    else
      terminals[id] = nil
    end
  end

  table.sort(ids)

  if #ids == 0 then
    vim.notify("No active or background terminal sessions.", vim.log.levels.INFO)
    return
  end

  for _, id in ipairs(ids) do
    local term = terminals[id]
    local visible = term.win and vim.api.nvim_win_is_valid(term.win)
    local status = visible and "Visible" or "Background"
    local current = (id == active_id) and " [ACTIVE]" or ""
    local short_cwd = vim.fn.fnamemodify(term.cwd or "", ":~")
    table.insert(lines, ("#%d%s — %s (%s)"):format(id, current, status, short_cwd))
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "hfd-terminal Sessions" })
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  vim.api.nvim_create_user_command("HfdTerminal", function(cmd_opts)
    local args = vim.trim(cmd_opts.args)

    if args == "" then
      M.open(active_id, { toggle = true })
      return
    end

    local first_word, rest = args:match("^(%S+)%s*(.*)$")
    if first_word and first_word:upper() == "C" then
      local target_id, cmd = rest:match("^(%d+)%s+(.+)$")
      if target_id and cmd then
        M.send_command(cmd, tonumber(target_id))
      else
        M.send_command(rest, active_id)
      end
      return
    end

    M.open(args, { toggle = true })
  end, {
    nargs = "*",
    desc = "Toggle hfd-terminal or send a command with 'C'",
  })

  vim.api.nvim_create_user_command("HfdTerminalList", function()
    M.list()
  end, { desc = "List active and background hfd-terminal sessions" })

  local all_modes = { "n", "i", "v", "x", "s", "o", "c", "t" }
  if M.config.keymap then
    vim.keymap.set(all_modes, M.config.keymap, function()
      M.open(active_id, { toggle = true })
    end, { desc = "hfd-terminal: Toggle (All Modes)" })
  end

  vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
end

return M