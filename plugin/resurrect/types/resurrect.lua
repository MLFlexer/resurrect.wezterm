---@meta
-- Resurrect plugin internal types

---@class WorkspaceState
---@field workspace string Workspace name
---@field window_states WindowState[]

---@class WindowState
---@field title string Window title
---@field size TabSize
---@field tabs TabState[]

---@class TabState
---@field title string Tab title
---@field is_active boolean
---@field is_zoomed boolean
---@field pane_tree PaneTree

---@class PaneTree
---@field left number X coordinate
---@field top number Y coordinate
---@field width number Pane width in cells
---@field height number Pane height in cells
---@field cwd string Current working directory
---@field domain? string Mux domain name
---@field text? string Scrollback content
---@field process? ProcessInfo Foreground process
---@field is_active boolean Is active pane
---@field is_zoomed boolean Is zoomed
---@field alt_screen_active boolean Alt screen mode (vim, etc.)
---@field right? PaneTree Right child (horizontal split)
---@field bottom? PaneTree Bottom child (vertical split)
---@field pane? Pane Current pane object (set during restore)

---@class RestoreOptions
---@field relative? boolean Use relative sizing
---@field absolute? boolean Use absolute sizing
---@field window? MuxWindow Target window
---@field tab? MuxTab Target tab
---@field pane? Pane Target pane
---@field on_pane_restore? fun(pane_tree: PaneTree) Custom restore callback
---@field close_open_panes? boolean Close existing panes
---@field close_open_tabs? boolean Close existing tabs
---@field spawn_in_workspace? boolean Spawn in workspace
---@field resize_window? boolean Resize window to match saved state
---@field restore_text? boolean Restore scrollback text

---@class SplitCommand
---@field direction "Right"|"Bottom"
---@field cwd string
---@field size? number
---@field text? string
---@field domain? string

---@class RawPaneData
---@field left number
---@field top number
---@field width number
---@field height number
---@field cwd string
---@field domain string
---@field is_spawnable boolean
---@field text string
---@field process? ProcessInfo
---@field is_active boolean
---@field is_zoomed boolean
---@field alt_screen_active boolean

---@class RawTabData
---@field title string
---@field panes RawPaneData[]
---@field is_active boolean
---@field is_zoomed boolean

---@class RawWindowData
---@field title string
---@field tabs RawTabData[]
---@field size TabSize?

---@class ShellApi
---@field extract_pane fun(pane: Pane, max_lines: number): RawPaneData
---@field extract_panes fun(pane_infos: PaneInformation[], max_lines: number): RawPaneData[]
---@field extract_tab fun(mux_tab: MuxTab, max_lines: number): RawTabData
---@field extract_window fun(mux_win: MuxWindow, max_lines: number): RawWindowData
---@field warn_not_spawnable fun(domain: string): nil
