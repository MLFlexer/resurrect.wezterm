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

-- Shell-safe wrapper around mkdir for a single already-assembled path segment.
-- On Unix, single-quote wrapping is used so that spaces and most metacharacters
-- are inert; embedded single quotes are escaped with the '\'' idiom.
-- On Windows, " is not a valid NTFS filename character so we validate and reject
-- rather than attempt to escape it; remaining quoting via double-quotes is safe.
local function shell_mkdir(path)
	if utils.is_windows then
		if path:find('"') then
			return false
		end
		return os.execute('mkdir "' .. path .. '"')
	else
		local quoted = "'" .. path:gsub("'", "'\\''") .. "'"
		return os.execute("mkdir " .. quoted)
	end
end

-- Normalise separators and strip the root prefix from path.
-- Returns the platform separator, the root component (e.g. "C:\", "/", "\\"),
-- and the remaining path with the root removed.
-- On Windows forward slashes are converted to backslashes before parsing.
---@param path string
---@return string sep, string root, string stripped
local function parse_root(path)
	local sep
	if utils.is_windows then
		sep = "\\"
		path = path:gsub("/", sep)
	else
		sep = "/"
	end

	local root = ""
	if utils.is_windows then
		local drive = path:match("^(%a:)[/\\]")
		if drive then
			-- Absolute path (e.g. C:\foo): capture "C:", append sep to form "C:\",
			-- then strip the 3-char prefix so the remainder is "foo\...".
			root = drive .. sep
			path = path:sub(4)
		elseif path:match("^%a:[^/\\]") then
			-- Drive-relative path (e.g. C:foo); normalise to absolute from drive root.
			-- Strip the 2-char "C:" prefix; root gets the explicit separator added.
			root = path:sub(1, 2) .. sep
			path = path:sub(3)
		elseif path:sub(1, 2) == "\\\\" then
			-- UNC path (e.g. \\server\share\...): strip the 2-char "\\" prefix.
			-- The server and share components cannot be created via mkdir;
			-- this only works when the share already exists.
			root = "\\\\"
			path = path:sub(3)
		end
	else
		if path:sub(1, 1) == "/" then
			-- Absolute Unix path: strip the leading separator; root is "/".
			root = "/"
			path = path:sub(2)
		end
	end

	return sep, root, path
end

-- Probe-write check: attempts to create and immediately remove a temp file
-- inside path. More reliable than os.rename on Windows, where open handles
-- held by WezTerm itself cause os.rename(dir, dir) to return nil even when
-- the directory exists and is fully usable.
-- A unique suffix from tostring({}) (table address) avoids collisions across
-- concurrent processes or calls.
local function dir_is_accessible(path)
	local probe = path .. utils.separator .. ".resurrect_probe_" .. tostring({}):gsub("[^%w]", "")
	local f = io.open(probe, "w")
	if f then
		f:close()
		os.remove(probe)
		return true
	end
	return false
end

-- Ensure a single already-assembled path exists, creating it if necessary.
-- Returns false if the directory could not be created or verified.
---@param path string
---@return boolean
local function mkdir_if_missing(path)
	-- Probe-write is the primary existence check. os.rename is skipped because
	-- it gives false negatives on Windows when WezTerm holds open handles,
	-- which would cause shell_mkdir to be called on every startup for
	-- directories that already exist, producing visible cmd.exe window flashes.
	if dir_is_accessible(path) then
		return true
	end
	if shell_mkdir(path) then
		-- Post-verify: confirm the directory is actually usable after creation.
		return dir_is_accessible(path)
	end
	return false
end

-- Create the folder if it does not exist.
-- Drive-relative paths on Windows (e.g. C:foo\bar) are normalised to absolute
-- from the drive root (C:\foo\bar). UNC paths (\\server\share\...) are
-- supported only when the server and share components already exist.
-- Path components are not sanitized; . and .. segments produce undefined behavior.
---@param path string
---@return boolean success
function utils.ensure_folder_exists(path)
	local sep, root, stripped = parse_root(path)
	local current = root
	for part in string.gmatch(stripped, "[^" .. sep .. "]+") do
		if current == "" then
			current = part
		elseif current:sub(-1) == sep then
			current = current .. part
		else
			current = current .. sep .. part
		end
		if not mkdir_if_missing(current) then
			return false
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
