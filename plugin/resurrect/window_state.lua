local wezterm = require("wezterm")
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm/")
local tab_state_mod = require(resurrect.get_require_path() .. ".plugin.resurrect.tab_state")
local pub = {}

---Returns the state of the window
---@param window MuxWindow
---@return window_state
function pub.get_window_state(window)
	local window_state = {
		title = window:get_title(),
		tabs = {},
	}

	local tabs = window:tabs_with_info()

	for i, tab in ipairs(tabs) do
		local tab_state = tab_state_mod.get_tab_state(tab.tab)
		tab_state.is_active = tab.is_active
		window_state.tabs[i] = tab_state
	end

	window_state.size = tabs[1].tab:get_size()

	return window_state
end

---restore window state
---@param window MuxWindow
---@param opts? restore_opts
function pub.restore_window(window, window_state, opts)
	if opts then
	else
		opts = {}
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

		tab_state_mod.restore_tab(tab, tab_state.pane_tree, opts)
		if tab_state.is_active then
			active_tab = tab
		end

		if tab_state.is_zoomed then
			tab:set_zoomed(true)
		end
	end

	active_tab:activate()
end

return pub
