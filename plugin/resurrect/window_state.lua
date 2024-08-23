local wezterm = require("wezterm")
local tab_state_mod = require("resurrect.tab_state")
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
---@param window_state window_state
---@param opts? restore_opts
function pub.restore_window(window, window_state, opts)
	wezterm.emit("resurrect.window_state.restore_window.start")
	if opts then
	else
		opts = {}
	end

	if window_state.title then
		window:set_title(window_state.title)
	end

	local active_tab
	for i, tab_state in ipairs(window_state.tabs) do
		local tab
		if i == 1 and opts.tab then
			tab = opts.tab
		else
			local spawn_tab_args = { cwd = tab_state.pane_tree.cwd }
			if tab_state.pane_tree.domain then
				spawn_tab_args.domain = { DomainName = tab_state.pane_tree.domain }
			end
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
	wezterm.emit("resurrect.window_state.restore_window.finished")
end

function pub.save_window_action()
	return wezterm.action_callback(function(win, pane)
		local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
		local mux_win = win:mux_window()
		if mux_win:get_title() == "" then
			win:perform_action(
				wezterm.action.PromptInputLine({
					description = "Enter new window title",
					action = wezterm.action_callback(function(window, _, title)
						if title then
							window:mux_window():set_title(title)
							local state = pub.get_window_state(mux_win)
							resurrect.save_state(state)
						end
					end),
				}),
				pane
			)
		elseif mux_win:get_title() then
			local state = pub.get_window_state(mux_win)
			resurrect.save_state(state)
		end
	end)
end

return pub
