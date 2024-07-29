---@alias tab_size {rows: integer, cols: integer, pixel_width: integer, pixel_height: integer, dpi: integer}
---@alias workspace_state {workspace: string, window_states: window_state[]}
---@alias window_state {title: string, tabs: tab_state[], workspace: string, size: tab_size}
---@alias tab_state {title: string, pane_tree: pane_tree, is_active: boolean}
---@alias MuxTab any
---@alias MuxWindow any

---@alias restore_opts {relative: boolean?, absolute: boolean?, pane: Pane?, tab: MuxTab?, window: MuxWindow, on_pane_restore: fun(pane_tree: pane_tree)}
