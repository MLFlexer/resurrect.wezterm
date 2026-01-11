---@type Wezterm
local wezterm = require("wezterm")
local utils = require("resurrect.utils")

---@class ShellApi
---Module for extracting raw data from WezTerm pane/tab/window objects.
---All WezTerm API calls that extract data for state capture are centralized here.
local M = {}

--------------------------------------------------------------------------------
-- Pane Data Extraction
--------------------------------------------------------------------------------

---Extract raw data from a WezTerm pane (IMPURE - all API calls here)
---@param pane Pane
---@param max_lines number
---@return RawPaneData
function M.extract_pane(pane, max_lines)
	local domain = pane:get_domain_name()
	local is_spawnable = wezterm.mux.get_domain(domain):is_spawnable()

	-- Handle CWD with Windows path fix
	local cwd = ""
	local cwd_obj = pane:get_current_working_dir()
	if cwd_obj then
		cwd = cwd_obj.file_path
		if utils.is_windows then
			cwd = cwd:gsub("^/([a-zA-Z]):", "%1:")
		end
	end

	-- Extract process info or scrollback based on alt screen state
	local text = ""
	local process = nil
	local alt_screen_active = pane:is_alt_screen_active()

	-- Only extract scrollback/process for local domain
	-- pane:inject_output() is unavailable for non-local domains
	-- See: https://github.com/MLFlexer/resurrect.wezterm/issues/41
	if is_spawnable and domain == "local" then
		if alt_screen_active then
			local process_info = pane:get_foreground_process_info()
			if process_info then
				-- Clear transient fields that shouldn't be persisted
				process_info.children = nil
				process_info.pid = nil
				process_info.ppid = nil
				process = process_info
			end
		else
			local nlines = pane:get_dimensions().scrollback_rows
			if nlines > max_lines then
				nlines = max_lines
			end
			text = pane:get_lines_as_escapes(nlines)
		end
	end

	return {
		left = 0, -- Set by caller from PaneInfo
		top = 0,
		width = 0,
		height = 0,
		cwd = cwd,
		domain = domain,
		is_spawnable = is_spawnable,
		text = text,
		process = process,
		is_active = false, -- Set by caller
		is_zoomed = false, -- Set by caller
		alt_screen_active = alt_screen_active,
	}
end

---Extract pane data from PaneInfo list
---@param pane_infos PaneInfo[]
---@param max_lines number
---@return RawPaneData[]
function M.extract_panes(pane_infos, max_lines)
	local result = {}
	for _, info in ipairs(pane_infos) do
		-- Guard: skip if pane is nil (can happen with invalid state)
		if info.pane then
			local raw = M.extract_pane(info.pane, max_lines)
			-- Overlay geometry from PaneInfo
			raw.left = info.left
			raw.top = info.top
			raw.width = info.width
			raw.height = info.height
			raw.is_active = info.is_active or false
			raw.is_zoomed = info.is_zoomed or false
			result[#result + 1] = raw
		end
	end
	return result
end

--------------------------------------------------------------------------------
-- Tab Data Extraction
--------------------------------------------------------------------------------

---Extract raw tab data from a MuxTab
---@param mux_tab MuxTab
---@param max_lines number
---@return RawTabData
function M.extract_tab(mux_tab, max_lines)
	local panes_info = mux_tab:panes_with_info()
	local panes = M.extract_panes(panes_info, max_lines)

	-- Check if any pane is zoomed
	local is_zoomed = false
	for _, pane in ipairs(panes) do
		if pane.is_zoomed then
			is_zoomed = true
			break
		end
	end

	return {
		title = mux_tab:get_title(),
		panes = panes,
		is_active = false, -- Set by caller
		is_zoomed = is_zoomed,
	}
end

--------------------------------------------------------------------------------
-- Window Data Extraction
--------------------------------------------------------------------------------

---Extract raw window data from a MuxWindow
---@param mux_win MuxWindow
---@param max_lines number
---@return RawWindowData
function M.extract_window(mux_win, max_lines)
	local tabs = {}
	for _, tab_info in ipairs(mux_win:tabs_with_info()) do
		local tab = M.extract_tab(tab_info.tab, max_lines)
		tab.is_active = tab_info.is_active or false
		tabs[#tabs + 1] = tab
	end

	-- Compute size from active tab
	local size = nil
	local active_tab = mux_win:active_tab()
	if active_tab then
		local tab_size = active_tab:get_size()
		if tab_size then
			size = {
				cols = tab_size.cols or 0,
				rows = tab_size.rows or 0,
				pixel_width = tab_size.pixel_width or 0,
				pixel_height = tab_size.pixel_height or 0,
			}
		end
	end

	return {
		title = mux_win:get_title(),
		tabs = tabs,
		size = size,
	}
end

--------------------------------------------------------------------------------
-- Domain Spawnability Warning
--------------------------------------------------------------------------------

---Log warning and emit error event for non-spawnable domain
---@param domain string
function M.warn_not_spawnable(domain)
	wezterm.log_warn("Domain " .. domain .. " is not spawnable")
	wezterm.emit("resurrect.error", "Domain " .. domain .. " is not spawnable")
end

return M
