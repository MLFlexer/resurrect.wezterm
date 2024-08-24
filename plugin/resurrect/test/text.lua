local wezterm = require("wezterm")
local pub = {}

function pub.write_all_bytes(pane)
	-- ascii
	for i = 1, 127 do
		pane:inject_output(string.char(i))
	end
	--utf8
	for i = 128, 55295 do
		pane:inject_output(utf8.char(i))
	end
	local max = 5000 * 150 -- scrolback * some arbitrary number of chars per line
	for i = 57344, max do
		pane:inject_output(utf8.char(i))
	end
end

function pub.write_and_save_current_window()
	return wezterm.action_callback(function(win, pane)
		local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
		local mux_win = win:mux_window()
		pub.write_all_bytes(pane)
		mux_win:set_title("TEST_WRITING_BYTES")
		local state = resurrect.window_state.get_window_state(mux_win)
		resurrect.save_state(state)
		wezterm.log_info("SAVED THE WINDOW AS TEST_WRITING_BYTES")
	end)
end

return pub
