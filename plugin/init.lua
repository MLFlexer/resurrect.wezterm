local wezterm = require("wezterm")

---@alias tab_size {rows: integer, cols: integer, pixel_width: integer, pixel_height: integer, dpi: integer}
---@alias workspace_state {workspace: string, window_states: window_state[]}
---@alias window_state {title: string, tabs: tab_state[], workspace: string, size: tab_size}
---@alias tab_state {title: string, pane_tree: pane_tree, is_active: boolean}
---@alias MuxTab any
---@alias MuxWindow any

---@alias restore_opts {relative: boolean?, absolute: boolean?, pane: Pane?, tab: MuxTab?, process_function: fun(args: string): string[]?}

-- TODO: enable by default
local function enable_defaults(url)
	for _, plugin in ipairs(wezterm.plugin.list()) do
		if plugin.url == url then
			package.path = package.path .. ";" .. plugin.plugin_dir .. "/?.lua"
			break
		end
	end
end

local pane_tree_mod = require("plugins.plugin.pane_tree")
local save_state_dir = wezterm.home_dir .. "/.local/share/wezterm/resurrect/"

---Changes the directory to save the state to
---@param directory string
local function change_state_save_dir(directory)
	save_state_dir = directory
end

---creates and returns the state of the tab
---@param tab MuxTab
---@return tab_state
local function get_tab_state(tab)
	local panes = tab:panes_with_info()

	local tab_state = {
		title = tab:get_title(),
		pane_tree = pane_tree_mod.create_pane_tree(panes),
	}

	return tab_state
end

---@param file_path string
---@param json_table table
local function write_json(file_path, json_table)
	local file = assert(io.open(file_path, "w"))
	file:write(wezterm.json_encode(json_table))
	file:close()
end

---@param file_path string
---@return table
local function load_json(file_path)
	local lines = {}
	for line in io.lines(file_path) do
		table.insert(lines, line)
	end
	local json = table.concat(lines)
	return wezterm.json_parse(json)
end

---Function used to split panes when mapping over the pane_tree
---@param opts restore_opts
---@return fun(pane_tree): pane_tree
local function make_splits(opts)
	if opts == nil then
		opts = {}
	end
	return function(pane_tree)
		local pane = pane_tree.pane
		local bottom = pane_tree.bottom
		if bottom then
			local split_args = { direction = "Bottom", cwd = bottom.cwd }
			if opts.relative then
				split_args.size = bottom.height / (pane_tree.height + bottom.height)
			elseif opts.absolute then
				split_args.size = bottom.height
			end

			bottom.pane = pane:split(split_args)
			if opts.process_function then
				bottom.pane:send_text(opts.process_function(bottom.process))
			end
		end

		local right = pane_tree.right
		if right then
			local split_args = { direction = "Right", cwd = right.cwd }
			if opts.relative then
				split_args.size = right.width / (pane_tree.width + right.width)
			elseif opts.absolute then
				split_args.size = right.width
			end

			right.pane = pane:split(split_args)
			if opts.process_function then
				right.pane:send_text(opts.process_function(right.process))
			end
		end
		return pane_tree
	end
end

---restore a tab
---@param tab MuxTab
---@param pane_tree pane_tree
---@param opts restore_opts
local function restore_tab(tab, pane_tree, opts)
	if opts.pane then
		pane_tree.pane = opts.pane
	else
		pane_tree.pane = tab:active_pane()
	end
	pane_tree_mod.map(pane_tree, make_splits(opts))
end

---Returns the state of the window
---@param window MuxWindow
---@return window_state
local function get_window_state(window)
	local window_state = {
		title = window:get_title(),
		tabs = {},
	}

	local tabs = window:tabs_with_info()

	for i, tab in ipairs(tabs) do
		local tab_state = get_tab_state(tab.tab)
		tab_state.is_active = tab.is_active
		window_state.tabs[i] = tab_state
	end

	window_state.size = tabs[1].tab:get_size()

	return window_state
end

---restore window state
---@param window MuxWindow
---@param opts? restore_opts
local function restore_window(window, window_state, opts)
	if opts then
	else
		opts = {}
		if #window:tabs() > 1 then
			wezterm.log_error("Cannot restore tabs, on window with more than 1 tab.")
		end
		local active_tab = window:active_tab()

		if #active_tab:panes() > 1 then
			wezterm.log_error("Cannot restore panes, in tab with more than 1 pane.")
		end
	end

	local active_tab -- TODO: remove???
	for i, tab_state in ipairs(window_state.tabs) do
		local tab
		if i == 1 and opts.tab then
			tab = opts.tab
		else
			local spawn_tab_args = { cwd = tab_state.pane_tree.cwd }
			tab, opts.pane, _ = window:spawn_tab(spawn_tab_args)
		end

		if opts.process_function then
			opts.pane:send_text(opts.process_function(tab_state.pane_tree.process))
		end
		restore_tab(tab, tab_state.pane_tree, opts)
		if tab_state.is_active then
			active_tab = tab
		end
	end

	active_tab:activate()
end

---restore workspace state
---@param workspace_state workspace_state
---@param opts? restore_opts
local function restore_workspace(workspace_state, opts)
	if opts == nil then
		opts = {}
	end

	for _, window_state in ipairs(workspace_state.window_states) do
		local spawn_window_args = {
			width = window_state.size.cols,
			height = window_state.size.rows,
			cwd = window_state.tabs[1].pane_tree.cwd,
		}
		local tab, pane, window = wezterm.mux.spawn_window(spawn_window_args)
		opts.pane = pane
		opts.tab = tab
		restore_window(window, window_state, opts)
	end
end

local function get_workspace_state()
	local workspace_state = {
		workspace = wezterm.mux.get_active_workspace(),
		window_states = {},
	}
	for _, mux_win in ipairs(wezterm.mux.all_windows()) do
		if mux_win:get_workspace() == workspace_state.workspace then
			table.insert(workspace_state.window_states, get_window_state(mux_win))
		end
	end
	return workspace_state
end

---Saves the current workspace state
---@param file_name? string
---@return string
local function save_workspace_state(file_name)
	local workspace_state = get_workspace_state()
	local file_path
	if file_name then
		file_path = string.format("%snamed/%s.json", save_state_dir, file_name)
	else
		file_path = string.format("%sworkspace/%s.json", save_state_dir, workspace_state.workspace:gsub("/", "+"))
	end
	write_json(file_path, workspace_state)
	return file_path
end

---Saves the current window state
---@param window MuxWindow
---@param file_name? string
---@return string
local function save_window_state(window, file_name)
	local window_state = get_window_state(window)
	local file_path
	if file_name then
		file_path = string.format("%snamed/%s.json", save_state_dir, file_name)
	elseif window_state.workspace then
		file_path = string.format("%sworkspace/%s.json", save_state_dir, window_state.workspace:gsub("/", "+"))
	else
		file_path = string.format("%scwd/%s.json", save_state_dir, window_state.tabs[1].pane_tree.cwd:gsub("/", "+"))
	end
	write_json(file_path, window_state)
	return file_path
end

---initialize by creating the directories, can be avoided if they are already
---present on the system
---@param state_dir string
local function init(state_dir)
	if state_dir then
		save_state_dir = state_dir
	end

	-- initialize directories
	wezterm.background_child_process({
		"mkdir",
		"-p",
		save_state_dir .. "named",
	})
	wezterm.background_child_process({
		"mkdir",
		"-p",
		save_state_dir .. "workspace",
	})
	wezterm.background_child_process({
		"mkdir",
		"-p",
		save_state_dir .. "cwd",
	})
end

---Saves the stater after interval in seconds
---@param interval_seconds integer
local function periodic_save(interval_seconds)
	if interval_seconds == nil then
		interval_seconds = 60 * 15
	end
	wezterm.time.call_after(interval_seconds, function()
		local workspace = wezterm.mux.get_active_workspace()
		for _, mux_win in ipairs(wezterm.mux.all_windows()) do
			if mux_win:get_workspace() == workspace then
				save_window_state(mux_win)
			end
		end
	end)
end

local function fuzzy_load(window, pane, callback)
	local state_files = {}
	for i, file_path in ipairs(wezterm.glob("*/*", save_state_dir)) do
		state_files[i] = { id = file_path, label = file_path }
	end

	window:perform_action(
		wezterm.action.InputSelector({
			action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
				if id and label then
					callback(id, label, save_state_dir)
				end
			end),
			title = "Choose State to Load",
			choices = state_files,
			fuzzy = true,
		}),
		pane
	)
end

return {
	init = init,
	fuzzy_load = fuzzy_load,
	periodic_save = periodic_save,
	save_workspace_state = save_workspace_state,
	restore_workspace = restore_workspace,
	save_state = save_window_state,
	get_window_state = get_window_state,
	restore_window = restore_window,
	write_json = write_json,
	change_state_save_dir = change_state_save_dir,
	save_state_dir = save_state_dir,
	load_json = load_json,
}
