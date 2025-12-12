local wezterm = require("wezterm") --[[@as Wezterm]] --- this type cast invokes the LSP module for Wezterm

local utils = {}

utils.is_windows = wezterm.target_triple == "x86_64-pc-windows-msvc"
utils.is_mac = (wezterm.target_triple == "x86_64-apple-darwin" or wezterm.target_triple == "aarch64-apple-darwin")
utils.separator = utils.is_windows and "\\" or "/"

-- Helper function to remove formatting esc sequences in the string
---@param str string
---@return string
function utils.strip_format_esc_seq(str)
	local clean_str, _ = str:gsub(string.char(27) .. "%[[^m]*m", "")
	return clean_str
end

-- getting screen dimensions
---@return number
function utils.get_current_window_width()
	local windows = wezterm.gui.gui_windows()
	for _, window in ipairs(windows) do
		if window:is_focused() then
			return window:active_tab():get_size().cols
		end
	end
	return 80
end

-- replace the center of a string with another string
---@param str string string to be modified
---@param len number length to be removed from the middle of str
---@param pad string string that must be inserted in place of the missing part of str
function utils.replace_center(str, len, pad)
	local mid = #str // 2
	local start = mid - (len // 2)
	return str:sub(1, start) .. pad .. str:sub(start + len + 1)
end

-- returns the length of a utf8 string
---@param str string
---@return number
function utils.utf8len(str)
	local _, len = str:gsub("[%z\1-\127\194-\244][\128-\191]*", "")
	return len
end

-- Execute a cmd and return its stdout
---@param cmd string command
---@return boolean success result
---@return string|nil error
function utils.execute(cmd)
	local stdout
	local suc, err = pcall(function()
		local handle = io.popen(cmd)
		if not handle then
			error("Could not open process: " .. cmd)
		end
		stdout = handle:read("*a")
		if stdout == nil then
			error("Error running process: " .. cmd)
		end
		handle:close()
	end)
	if suc then
		return suc, stdout
	else
		return suc, err
	end
end

-- Create the folder if it does not exist
---@param path string
function utils.ensure_folder_exists(path)
	local sep
	if utils.is_windows then
		-- assuming path is non-windows and that windows paths have
		-- inferior support for allowed characters
		sep = "\\"
		path = path:gsub("/", sep)
	else
		sep = "/"
	end

	local parts = {}
	for part in string.gmatch(path, "[^" .. sep .. "]+") do
		table.insert(parts, part)
	end

	local current = ""
	for i, part in ipairs(parts) do
		current = current == "" and part or (current .. sep .. part)

		-- Check if the folder exists by attempting rename
		local ok = os.rename(current, current)
		if not ok then
			-- Pure Lua "mkdir" using io.open
			-- Create a temp file inside the directory to force the folder to exist
			local tmp = current .. sep .. ".mkdir_tmp"
			local f = io.open(tmp, "w")
			if f then
				f:close()
				os.remove(tmp)
			else
				-- directory creation failed
				return false
			end
		end
	end

	return true
end

-- deep copy
---@param original table
---@return any copy
function utils.deepcopy(original)
	local copy
	if type(original) == "table" then
		copy = {}
		for k, v in pairs(original) do
			copy[k] = utils.deepcopy(v)
		end
	else
		copy = original
	end
	return copy
end

-- extend table
---@alias behavior
---| 'error' # Raises an error if a kye exists in multiple tables
---| 'keep'  # Uses the value from the leftmost table (first occurrence)
---| 'force' # Uses the value from the rightmost table (last occurrence)
---
---@param behavior behavior
---@param ... table
---@return table|nil
function utils.tbl_deep_extend(behavior, ...)
	local tables = { ... }
	if #tables == 0 then
		return {}
	end

	local result = {}
	for k, v in pairs(tables[1]) do
		if type(v) == "table" then
			result[k] = utils.deepcopy(v)
		else
			result[k] = v
		end
	end

	for i = 2, #tables do
		for k, v in pairs(tables[i]) do
			if type(result[k]) == "table" and type(v) == "table" then
				-- For nested tables, we recurse with the same behavior
				result[k] = utils.tbl_deep_extend(behavior, result[k], v)
			elseif result[k] ~= nil then
				-- Key exists in the result already
				if behavior == "error" then
					error("Key '" .. tostring(k) .. "' exists in multiple tables")
				elseif behavior == "force" then
					-- "force" uses value from rightmost table
					if type(v) == "table" then
						result[k] = utils.deepcopy(v)
					else
						result[k] = v
					end
				end
			-- "keep" keeps the leftmost value, which is already in result
			else
				-- Key doesn't exist in result yet, add it
				if type(v) == "table" then
					result[k] = utils.deepcopy(v)
				else
					result[k] = v
				end
			end
		end
	end

	return result
end

return utils
