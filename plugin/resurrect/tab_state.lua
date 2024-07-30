local wezterm = require("wezterm")
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm/")
local pane_tree_mod = require(resurrect.get_require_path() .. ".plugin.resurrect.pane_tree")
local pub = {}

---Function used to split panes when mapping over the pane_tree
---@param opts restore_opts
---@return fun(acc: {active_pane: Pane, is_zoomed: boolean}, pane_tree: pane_tree): {active_pane: Pane, is_zoomed: boolean}
local function make_splits(opts)
	if opts == nil then
		opts = {}
	end

	return function(acc, pane_tree)
		local pane = pane_tree.pane

		if opts.on_pane_restore then
			opts.on_pane_restore(pane_tree)
		end

		local bottom = pane_tree.bottom
		if bottom then
			local split_args = { direction = "Bottom", cwd = bottom.cwd }
			if opts.relative then
				split_args.size = bottom.height / (pane_tree.height + bottom.height)
			elseif opts.absolute then
				split_args.size = bottom.height
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

			right.pane = pane:split(split_args)
		end

		if pane_tree.is_active then
			acc.active_pane = pane_tree.pane
		end

		if pane_tree.is_zoomed then
			acc.is_zoomed = true
		end

		return acc
	end
end

---creates and returns the state of the tab
---@param tab MuxTab
---@return tab_state
function pub.get_tab_state(tab)
	local panes = tab:panes_with_info()

	local function is_zoomed()
		for _, pane in ipairs(panes) do
			if pane.is_zoomed then
				return true
			end
		end
		return false
	end

	local tab_state = {
		title = tab:get_title(),
		is_zoomed = is_zoomed(),
		pane_tree = pane_tree_mod.create_pane_tree(panes),
	}

	return tab_state
end

---restore a tab
---@param tab MuxTab
---@param pane_tree pane_tree
---@param opts restore_opts
function pub.restore_tab(tab, pane_tree, opts)
	if opts.pane then
		pane_tree.pane = opts.pane
	else
		pane_tree.pane = tab:active_pane()
	end

	local acc = pane_tree_mod.fold(pane_tree, { is_zoomed = false }, make_splits(opts))
	acc.active_pane:activate()
end

function pub.default_on_pane_restore(pane_tree)
	local pane = pane_tree.pane

	if pane_tree_mod.get_shell_process(pane_tree.process) then
		pane:inject_output(pane_tree.text)
	else
		pane:send_text(pane_tree.process .. "\r\n")
	end
end

return pub
