local wezterm = require("wezterm")

---@alias gui_window any
---@alias window_state any
---@alias tab_state any
---@alias MuxTab any

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
local save_state_dir = wezterm.home_dir .. ".local/share/wezterm/resurrect/"

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
		size = tab:get_size(),
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

---@alias restore_opts {workspace: boolean?, named: boolean?, name: string, relative: boolean?, absolute: boolean?, process_function: fun(args: string): string[]?}

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

			if opts.process_function then
				split_args.args = opts.process_function(bottom.process)
			end

			bottom.pane = pane:split(split_args)
		end

		local right = pane_tree.right
		if right then
			local split_args = { direction = "Right", cwd = right.cwd }
			if opts.relative then
				split_args.size = right.width / (pane_tree.width + right.width)
			elseif opts.absolute then
				split_args.size = right.width
			end

			if opts.process_function then
				split_args.args = opts.process_function(right.process)
			end

			right.pane = pane:split(split_args)
		end
		return pane_tree
	end
end

---restore a tab
---@param tab MuxTab
---@param pane_tree pane_tree
---@param opts restore_opts
local function restore_tab(tab, pane_tree, opts)
	pane_tree.pane = tab:active_pane()
	pane_tree_mod.map(pane_tree, make_splits(opts))
end

---Returns the state of the window
---@param window gui_window
---@return window_state
local function get_window_state(window)
	local mux_win = window:mux_window()
	local window_state = {
		workspace = window:active_workspace(),
		title = mux_win:get_title(),
		tabs = {},
	}

	local tabs = mux_win:tabs_with_info()

	for i, tab in ipairs(tabs) do
		local tab_state = get_tab_state(tab.tab)
		tab_state.is_active = tab.is_active
		window_state.tabs[i] = tab_state
	end

	return window_state
end

---restore window state
---@param window any
---@param opts? restore_opts
---@return unknown
local function restore_window(window, opts)
	local mux_win = window:mux_window()
	if #mux_win:tabs() > 1 then
		wezterm.log_error("Cannot restore tabs, on window with more than 1 tab.")
	end
	local active_tab = window:active_tab()

	if #active_tab:panes() > 1 then
		wezterm.log_error("Cannot restore panes, in tab with more than 1 pane.")
	end
	local active_pane = window:active_pane()

	local state_path
	if opts then
		if opts.workspace then
			state_path = string.format("%sworkspace/%s.json", save_state_dir, opts.name:gsub("/", "+"))
		elseif opts.named then
			state_path = string.format("%snamed/%s.json", save_state_dir, opts.name)
		end
	else
		opts = {}
		state_path = string.format(
			"%scwd/%s.json",
			save_state_dir,
			window:active_pane():get_current_working_dir():gsub("/", "+")
		)
	end

	local window_state = load_json(state_path)
	for _, tab_state in ipairs(window_state.tabs) do
		local spawn_tab_args = { cwd = tab_state.pane_tree.cwd }
		if opts.process_function then
			spawn_tab_args.args = opts.process_function(tab_state.pane_tree.process)
		end
		local tab, _, _ = mux_win:spawn_tab(spawn_tab_args)
		restore_tab(tab, tab_state.pane_tree, opts)
		if tab_state.is_active then
			active_tab = tab
		end
	end

	active_pane:activate()
	window:perform_action(wezterm.action.CloseCurrentPane({ confirm = false }), active_pane)
	active_tab:activate()
	return window_state
end

---Saves the current window state
---@param window any
---@param file_name? string
---@return string
local function save_state(window, file_name)
	local window_state = get_window_state(window)
	local file_path
	if file_name then
		file_path = string.format("%snamed/%s.json", save_state_dir, file_name)
	elseif window_state.workspace then
		file_path = string.format("%sworkspace/%s.json", save_state_dir, window_state.workspace:gsub("/", "+"))
	else
		file_path = string.format("%scwd/%s.json", save_state_dir, window_state.tabs[1].cwd:gsub("/", "+"))
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
		for _, mux_win in ipairs(wezterm.mux.all_windows()) do
			if mux_win:get_workspace() == wezterm.mux.get_active_workspace() then
				save_state(mux_win:gui_window())
			end
		end
	end)
end

return {
	init = init,
	periodic_save = periodic_save,
	save_state = save_state,
	get_window_state = get_window_state,
	restore_window = restore_window,
	write_json = write_json,
	change_state_save_dir = change_state_save_dir,
	save_state_dir = save_state_dir,
}
