local wezterm = require("wezterm")
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm/")
local window_state_mod = require(resurrect.get_require_path() .. ".plugin.resurrect.window_state")
local pub = {}

---restore workspace state
---@param workspace_state workspace_state
---@param opts? restore_opts
function pub.restore_workspace(workspace_state, opts)
	if opts == nil then
		opts = {}
	end

	for i, window_state in ipairs(workspace_state.window_states) do
		if i == 1 and opts.window then
			-- inner size is in pixels
			opts.window:gui_window():set_inner_size(window_state.size.pixel_width, window_state.size.pixel_height)
			opts.tab = opts.window:active_tab()
			opts.pane = opts.window:active_pane()
		else
			local spawn_window_args = {
				width = window_state.size.cols,
				height = window_state.size.rows,
				cwd = window_state.tabs[1].pane_tree.cwd,
			}
			opts.tab, opts.pane, opts.window = wezterm.mux.spawn_window(spawn_window_args)
		end

		window_state_mod.restore_window(opts.window, window_state, opts)
	end
end

---Returns the state of the current workspace
---@return workspace_state
function pub.get_workspace_state()
	local workspace_state = {
		workspace = wezterm.mux.get_active_workspace(),
		window_states = {},
	}
	for _, mux_win in ipairs(wezterm.mux.all_windows()) do
		if mux_win:get_workspace() == workspace_state.workspace then
			table.insert(workspace_state.window_states, window_state_mod.get_window_state(mux_win))
		end
	end
	return workspace_state
end

return pub
