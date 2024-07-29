local wezterm = require("wezterm")
local pub = {}

--- adds the wezterm plugin directory to the lua path
function pub.enable_defaults()
	local plugin_dir = wezterm.plugin.list()[1].plugin_dir:gsub("/[^/]*$", "")
	package.path = package.path .. ";" .. plugin_dir .. "/?.lua"
end

--- Returns the name of the package, used when requiring modules
--- @return string
function pub.get_wezterm_package_name()
	return "httpssCssZssZsgithubsDscomsZsMLFlexersZsresurrectsDsweztermsZs"
end

pub.save_state_dir = wezterm.home_dir .. "/.local/share/wezterm/resurrect/"

---Changes the directory to save the state to
---@param directory string
function pub.change_state_save_dir(directory)
	pub.save_state_dir = directory
end

---@param file_name string
---@param type string
---@param opt_name string?
---@return string
local function get_file_path(file_name, type, opt_name)
	if opt_name then
		file_name = opt_name
	end
	return string.format("%s%s/%s.json", pub.save_state_dir, type, file_name:gsub("/", "+"))
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

---save state to a file
---@param state workspace_state | window_state | tab_state
---@param opt_name? string
function pub.save_state(state, opt_name)
	if state.window_states then
		write_json(get_file_path(state.workspace, "workspace", opt_name), state)
	elseif state.tabs then
		write_json(get_file_path(state.workspace, "window", opt_name), state)
	elseif state.pane_tree then
		write_json(get_file_path(state.pane_tree.cwd, "tab", opt_name), state)
	end
end

---Reads a file with the state
---@param name string
---@param type string
function pub.load_state(name, type)
	return load_json(get_file_path(name, type))
end

---initialize by creating the directories, can be avoided if they are already
---present on the system
---@param state_dir string
function pub.init(state_dir)
	if state_dir then
		pub.save_state_dir = state_dir
	end

	-- initialize directories
	wezterm.background_child_process({
		"mkdir",
		"-p",
		pub.save_state_dir .. "named",
	})
	wezterm.background_child_process({
		"mkdir",
		"-p",
		pub.save_state_dir .. "workspace",
	})
	wezterm.background_child_process({
		"mkdir",
		"-p",
		pub.save_state_dir .. "cwd",
	})
end

---Saves the stater after interval in seconds
---@param interval_seconds integer
function pub.periodic_save(interval_seconds)
	if interval_seconds == nil then
		interval_seconds = 60 * 15
	end
	wezterm.time.call_after(interval_seconds, function()
		local workspace_state = require(pub.get_wezterm_package_name() .. ".plugin.workspace_state")
		pub.save_state(workspace_state.get_workspace_state())
	end)
end

function pub.get_default_fuzzy_load_opts()
	return {
		title = "Choose State to Load",
		is_fuzzy = true,
		ignore_workspaces = false,
		ignore_windows = false,
		ignore_tabs = false,
		fmt_workspace = function(label)
			return wezterm.format({
				{ Foreground = { AnsiColor = "Green" } },
				{ Text = "󱂬 : " .. label:gsub("%.json$", "") },
			})
		end,
		fmt_window = function(label)
			return wezterm.format({
				{ Foreground = { AnsiColor = "Yellow" } },
				{ Text = " : " .. label:gsub("%.json$", "") },
			})
		end,
		fmt_tab = function(label)
			return wezterm.format({
				{ Foreground = { AnsiColor = "Red" } },
				{ Text = "󰓩 : " .. label:gsub("%.json$", "") },
			})
		end,
	}
end

function pub.fuzzy_load(window, pane, callback, opts)
	local state_files = {}

	if opts == nil then
		opts = pub.get_default_fuzzy_load_opts()
	end

	if not opts.ignore_workspaces then
		for i, file_path in ipairs(wezterm.glob("*", pub.save_state_dir .. "/workspace")) do
			if opts.fmt_workspace then
				state_files[i] = { id = file_path, label = opts.fmt_workspace(file_path) }
			else
				state_files[i] = { id = file_path, label = file_path }
			end
		end
	end

	if not opts.ignore_windows then
		for i, file_path in ipairs(wezterm.glob("*", pub.save_state_dir .. "/window")) do
			if opts.fmt_window then
				state_files[i] = { id = file_path, label = opts.fmt_window(file_path) }
			else
				state_files[i] = { id = file_path, label = file_path }
			end
		end
	end

	if not opts.ignore_tabs then
		for i, file_path in ipairs(wezterm.glob("*", pub.save_state_dir .. "/tab")) do
			if opts.fmt_tabs then
				state_files[i] = { id = file_path, label = opts.fmt_tabs(file_path) }
			else
				state_files[i] = { id = file_path, label = file_path }
			end
		end
	end

	window:perform_action(
		wezterm.action.InputSelector({
			action = wezterm.action_callback(function(_, _, id, label)
				if id and label then
					callback(id, label, pub.save_state_dir)
				end
			end),
			title = opts.title,
			choices = state_files,
			fuzzy = opts.is_fuzzy,
		}),
		pane
	)
end

return pub
