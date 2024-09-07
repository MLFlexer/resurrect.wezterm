local wezterm = require("wezterm")

---@class init_module
---@field encryption encryption_opts
local pub = {}

local plugin_dir

--- checks if the user is on windows
local is_windows = wezterm.target_triple == "x86_64-pc-windows-msvc"
local separator = is_windows and "\\" or "/"

--- Checks if the plugin directory exists
--- @return boolean
local function directory_exists(path)
	local success, result = pcall(wezterm.read_dir, plugin_dir .. path)
	return success and result
end

--- Returns the name of the package, used when requiring modules
--- @return string
function pub.get_require_path()
	local path1 = "httpssCssZssZsgithubsDscomsZsMLFlexersZsresurrectsDswezterm"
	local path2 = "httpssCssZssZsgithubsDscomsZsMLFlexersZsresurrectsDsweztermsZs"
	return directory_exists(path2) and path2 or path1
end

--- adds the wezterm plugin directory to the lua path
local function enable_sub_modules()
	plugin_dir = wezterm.plugin.list()[1].plugin_dir:gsub(separator .. "[^" .. separator .. "]*$", "")
	package.path = package.path
		.. ";"
		.. plugin_dir
		.. separator
		.. pub.get_require_path()
		.. separator
		.. "plugin"
		.. separator
		.. "?.lua"
end

enable_sub_modules()

pub.save_state_dir = plugin_dir .. separator .. pub.get_require_path() .. separator .. "state" .. separator

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
	return string.format("%s%s" .. separator .. "%s.json", pub.save_state_dir, type, file_name:gsub(separator, "+"))
end

---executes cmd and passes input to stdin
---@param cmd string command to be run
---@param input string input to stdin
---@return boolean
---@return string
local function execute_cmd_with_stdin(cmd, input)
	if is_windows and #input < 32000 then -- Check if input is larger than max cmd length on Windows
		cmd = string.format("%s | %s", wezterm.shell_join_args({ "Write-Output", "-NoEnumerate", input }), cmd)
		local process_args = { "pwsh.exe", "-NoProfile", "-Command", cmd }

		local success, stdout, stderr = wezterm.run_child_process(process_args)
		if success then
			return success, stdout
		else
			return success, stderr
		end
	elseif #input < 150000 and not is_windows then -- Check if input is larger than common max on MacOS and Linux
		cmd = string.format("%s | %s", wezterm.shell_join_args({ "echo", "-E", "-n", input }), cmd)
		local process_args = { os.getenv("SHELL"), "-c", cmd }

		local success, stdout, stderr = wezterm.run_child_process(process_args)
		if success then
			return success, stdout
		else
			return success, stderr
		end
	else
		-- redirect stderr to stdout to test if cmd will execute
		-- can't check on Windows because it doesn't support /dev/stdin
		if not is_windows then
			local stdout = io.popen(cmd .. " 2>&1", "r")
			if not stdout then
				return false, "Failed to execute: " .. cmd
			end
			local stderr = stdout:read("*all")
			stdout:close()
			if stderr ~= "" then
				wezterm.log_error(stderr)
				return false, stderr
			end
		end
		-- if no errors, execute cmd using stdin with input
		local stdin = io.popen(cmd, "w")
		if not stdin then
			return false, "Failed to execute: " .. cmd
		end
		stdin:write(input)
		stdin:flush()
		stdin:close()
		return true, '"' .. cmd .. '" <input> ran successfully.'
	end
end

---@alias encryption_opts {enable: boolean, method: string, private_key: string | nil, public_key: string | nil, encrypt: fun(file_path: string, lines: string), decrypt: fun(file_path: string): string}
pub.encryption = {
	enable = false,
	method = "age",
	private_key = nil,
	public_key = nil,
	encrypt = function(file_path, lines)
		local cmd = string.format(
			"%s -r %s -o %s",
			pub.encryption.method,
			pub.encryption.public_key,
			file_path:gsub(" ", "\\ ")
		)

		if pub.encryption.method:find("gpg") then
			cmd = string.format(
				"%s --batch --yes --encrypt --recipient %s --output %s",
				pub.encryption.method,
				pub.encryption.public_key,
				file_path:gsub(" ", "\\ ")
			)
		end

		local success, output = execute_cmd_with_stdin(cmd, lines)
		if not success then
			error("Encryption failed:" .. output)
		end
	end,
	decrypt = function(file_path)
		local cmd = { pub.encryption.method, "-d", "-i", pub.encryption.private_key, file_path }

		if pub.encryption.method:find("gpg") then
			cmd = { pub.encryption.method, "--batch", "--yes", "--decrypt", file_path }
		end

		local success, stdout, stderr = wezterm.run_child_process(cmd)
		if not success then
			error("Decryption failed: " .. stderr)
		end

		return stdout
	end,
}

--- Merges user-supplied options with default options
--- @param user_opts encryption_opts
function pub.set_encryption(user_opts)
	for k, v in pairs(user_opts) do
		if v ~= nil then
			pub.encryption[k] = v
		end
	end
end

--- Sanitize the input by replacing control characters and invalid UTF-8 sequences with valid \uxxxx unicode
--- @param data string
--- @return string
local function sanitize_json(data)
	wezterm.emit("resurrect.sanitize_json.start", data)
	-- escapes control characters to ensure valid json
	data = data:gsub("[\x00-\x1F]", function(c)
		return string.format("\\u00%02X", string.byte(c))
	end)
	wezterm.emit("resurrect.sanitize_json.finished")
	return data
end

---@param file_path string
---@param state table
local function write_state(file_path, state)
	wezterm.emit("resurrect.save_state.start", file_path)
	local json_state = wezterm.json_encode(state)
	json_state = sanitize_json(json_state)
	if pub.encryption.enable then
		wezterm.emit("resurrect.encrypt.start", file_path)
		local ok, err = pcall(function()
			return pub.encryption.encrypt(file_path, json_state)
		end)
		if not ok then
			wezterm.log_error("Encryption failed: ")
			wezterm.log_error(err)
			wezterm.emit("resurrect.error", err)
		else
			wezterm.emit("resurrect.encrypt.finished", file_path)
		end
	else
		local ok, err = pcall(function()
			local file = assert(io.open(file_path, "w"))
			file:write(json_state)
			file:close()
		end)
		if not ok then
			wezterm.emit("resurrect.error", "Failed to write state: " .. err)
			wezterm.log_error("Failed to write state: " .. err)
		end
	end
	wezterm.emit("resurrect.save_state.finished", file_path)
end

---@param file_path string
---@return table|nil
local function load_json(file_path)
	local json
	if pub.encryption.enable then
		wezterm.emit("resurrect.decrypt.start", file_path)
		local ok, output = pcall(function()
			return pub.encryption.decrypt(file_path)
		end)
		if not ok then
			wezterm.emit("resurrect.error", "Decryption failed: " .. tostring(output))
			wezterm.log_error("Decryption failed: " .. tostring(output))
		else
			json = output
			wezterm.emit("resurrect.decrypt.finished", file_path)
		end
	else
		local lines = {}
		for line in io.lines(file_path) do
			table.insert(lines, line)
		end
		json = table.concat(lines)
	end
	if not json then
		return nil
	end
	json = sanitize_json(json)

	return wezterm.json_parse(json)
end

---save state to a file
---@param state workspace_state | window_state | tab_state
---@param opt_name? string
function pub.save_state(state, opt_name)
	if state.window_states then
		write_state(get_file_path(state.workspace, "workspace", opt_name), state)
	elseif state.tabs then
		write_state(get_file_path(state.title, "window", opt_name), state)
	elseif state.pane_tree then
		write_state(get_file_path(state.title, "tab", opt_name), state)
	end
end

---Reads a file with the state
---@param name string
---@param type string
---@return table
function pub.load_state(name, type)
	wezterm.emit("resurrect.load_state.start", name, type)
	local json = load_json(get_file_path(name, type))
	if not json then
		wezterm.emit("resurrect.error", "Invalid json: " .. get_file_path(name, type))
		return {}
	end
	wezterm.emit("resurrect.load_state.finished", name, type)
	return json
end

---Saves the stater after interval in seconds
---@param opts? { interval_seconds: integer?, save_workspaces: boolean?, save_windows: boolean?, save_tabs: boolean? }
function pub.periodic_save(opts)
	if opts == nil then
		opts = { save_workspaces = true }
	end
	if opts.interval_seconds == nil then
		opts.interval_seconds = 60 * 15
	end
	wezterm.time.call_after(opts.interval_seconds, function()
		wezterm.emit("resurrect.periodic_save", opts)
		if opts.save_workspaces then
			pub.save_state(pub.workspace_state.get_workspace_state())
		end

		if opts.save_windows then
			for _, gui_win in ipairs(wezterm.gui.gui_windows()) do
				local mux_win = gui_win:mux_window()
				local title = mux_win:get_title()
				if title ~= "" and title ~= nil then
					pub.save_state(pub.window_state.get_window_state(mux_win))
				end
			end
		end

		pub.periodic_save(opts)
	end)
end

---@alias fmt_fun fun(label: string): string
---@alias fuzzy_load_opts {title: string, description: string, fuzzy_description: string, is_fuzzy: boolean, ignore_workspaces: boolean, ignore_tabs: boolean, ignore_windows: boolean, fmt_window: fmt_fun, fmt_workspace: fmt_fun, fmt_tab: fmt_fun }

---Returns default fuzzy loading options
---@return fuzzy_load_opts
function pub.get_default_fuzzy_load_opts()
	return {
		title = "Load State",
		description = "Select State to Load and press Enter = accept, Esc = cancel, / = filter",
		fuzzy_description = "Search State to Load: ",
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

---A fuzzy finder to restore saved state
---@param window MuxWindow
---@param pane Pane
---@param callback fun(id: string, label: string, save_state_dir: string)
---@param opts fuzzy_load_opts?
function pub.fuzzy_load(window, pane, callback, opts)
	wezterm.emit("resurrect.fuzzy_load.start", window, pane)
	local state_files = {}

	if opts == nil then
		opts = pub.get_default_fuzzy_load_opts()
	else
		-- Merge user opts with defaults
		local default_opts = pub.get_default_fuzzy_load_opts()
		for k, v in pairs(default_opts) do
			if opts[k] == nil then
				opts[k] = v
			end
		end
	end

	local function insert_choices(type, fmt)
		for _, file in ipairs(wezterm.glob("*", pub.save_state_dir .. "/" .. type)) do
			local label
			local id = type .. "/" .. file

			if fmt then
				label = fmt(file)
			else
				label = file
			end
			table.insert(state_files, { id = id, label = label })
		end
	end

	if not opts.ignore_workspaces then
		insert_choices("workspace", opts.fmt_workspace)
	end

	if not opts.ignore_windows then
		insert_choices("window", opts.fmt_window)
	end

	if not opts.ignore_tabs then
		insert_choices("tab", opts.fmt_tab)
	end

	window:perform_action(
		wezterm.action.InputSelector({
			action = wezterm.action_callback(function(_, _, id, label)
				if id and label then
					callback(id, label, pub.save_state_dir)
				end
				wezterm.emit("resurrect.fuzzy_load.finished", window, pane)
			end),
			title = opts.title,
			description = opts.description,
			fuzzy_description = opts.fuzzy_description,
			choices = state_files,
			fuzzy = opts.is_fuzzy,
		}),
		pane
	)
end

---@param file_path string
function pub.delete_state(file_path)
	wezterm.emit("resurrect.delete_state.start", file_path)
	local path = pub.save_state_dir .. file_path
	local success = os.remove(path)
	if not success then
		wezterm.emit("resurrect.error", "Failed to delete state: " .. path)
		wezterm.log_error("Failed to delete state: " .. path)
	end
	wezterm.emit("resurrect.delete_state.finished", file_path)
end

-- Export submodules
local workspace_state = require("resurrect.workspace_state")
pub.workspace_state = workspace_state
local window_state = require("resurrect.window_state")
pub.window_state = window_state
local tab_state = require("resurrect.tab_state")
pub.tab_state = tab_state

function pub.set_max_nlines(max_nlines)
	require("resurrect.pane_tree").max_nlines = max_nlines
end

return pub
