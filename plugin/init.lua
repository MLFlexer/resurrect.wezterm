local wezterm = require("wezterm")
local file_path = "/home/mlflexer/repos/resurrect.wezterm/test.json"

local function compare_pane_by_left_coord(a, b)
	if a.left == b.left then
		return a.top < b.top
	else
		return a.left < b.left
	end
end

local function is_right(root, pane)
	if root.left + root.width < pane.left then
		return true
	end
end

local function is_bottom(root, pane)
	if root.top + root.height < pane.top then
		return true
	end
end

local function pop_connected_bottom(root, panes)
	if #panes == 0 then
		return nil
	end
	wezterm.log_warn(root)
	for i, pane in ipairs(panes) do
		wezterm.log_info(pane)
		if root.left == pane.left and root.top + root.height + 1 == pane.top then
			table.remove(panes, i)
			return pane
		end
	end
	-- error("No pane connected bottom")
end

local function pop_connected_right(root, panes)
	if #panes == 0 then
		return nil
	end
	wezterm.log_warn(root)
	for i, pane in ipairs(panes) do
		wezterm.log_info(pane)
		if root.top == pane.top and root.left + root.width + 1 == pane.left then
			table.remove(panes, i)
			return pane
		end
	end
	-- error("No pane connected right")
end

local function insert_panes(root, panes)
	if root == nil then
		return nil
	end

	root.pane = nil
	if #panes == 0 then
		return root
	end

	local right, bottom = {}, {}
	for _, pane in ipairs(panes) do
		if is_right(root, pane) then
			table.insert(right, pane)
		end
		if is_bottom(root, pane) then
			table.insert(bottom, pane)
		end
	end

	if #right > 0 then
		local right_child = pop_connected_right(root, right)
		root.right = insert_panes(right_child, right)
	end

	if #bottom > 0 then
		local bottom_child = pop_connected_bottom(root, bottom)
		root.bottom = insert_panes(bottom_child, bottom)
	end

	return root
end

local function merge_panes(panes)
	local root = panes[1]
	table.remove(panes, 1)
	return insert_panes(root, panes)
end

local function save_tab(tab)
	local panes = tab:panes_with_info()

	table.sort(panes, compare_pane_by_left_coord)

	local pane_tree = merge_panes(panes)

	local file = assert(io.open(file_path, "w"))
	file:write(wezterm.json_encode(pane_tree))
	file:close()
end

local function map(pane_tree, f)
	if pane_tree == nil then
		return nil
	end

	pane_tree = f(pane_tree)
	if pane_tree.right then
		map(pane_tree.right, f)
	end
	if pane_tree.bottom then
		map(pane_tree.bottom, f)
	end

	return pane_tree
end

local function activate_and_split(pane_tree)
	local pane = pane_tree.pane
	if pane_tree.bottom then
		pane_tree.bottom.pane = pane:split({ direction = "Bottom" })
	end

	if pane_tree.right then
		pane_tree.right.pane = pane:split({ direction = "Right" })
	end
	return pane_tree
end

local function restore_tab(tab, pane_tree)
	tab:activate()

	local active_pane = tab:active_pane()
	pane_tree.pane = active_pane
	map(pane_tree, activate_and_split)
end

local function restore_from_file(tab)
	local lines = {}
	for line in io.lines(file_path) do
		table.insert(lines, line)
	end
	local json = table.concat(lines)
	local pane_tree = wezterm.json_parse(json)
	restore_tab(tab, pane_tree)
end

return {
	save_tab = save_tab,
	restore_from_file = restore_from_file,
}
