> [!WARNING]
> This project is archived and no longer maintained. 
> I'm currently focusing on my PhD and don't find it interesting to work on this anymore. 
> Please fork/use one of the forks instead 😃

# resurrect.wezterm

Resurrect your terminal environment!⚰️ A plugin to save the state of your windows, tabs and panes. Inspired by [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) and [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum).

![Screencastfrom2024-07-2918-50-57-ezgif com-resize](https://github.com/user-attachments/assets/640aefea-793c-486d-9579-1a9c8bb4c1fa)

## Features

- Restore your windows, tabs and panes with the layout and text from a saved state.
- Restore shell output from a saved session.
- Save the state of your current window, with every window, tab and pane state stored in a `json` file.
- Restore the save from a `json` file.
- Re-attach to remote domains (e.g. SSH, SSHMUX, WSL, Docker, ect.).
- Optionally enable encryption and decryption of the saved state.

## Setup example

1. Require the plugin:

```lua
local wezterm = require("wezterm")
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
```

2. Saving workspace, window and/or tab state based on name and title:

```lua
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

config.keys = {
  -- ...
  {
    key = "w",
    mods = "ALT",
    action = wezterm.action_callback(function(win, pane)
        resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
      end),
  },
  {
    key = "W",
    mods = "ALT",
    action = resurrect.window_state.save_window_action(),
  },
  {
    key = "T",
    mods = "ALT",
    action = resurrect.tab_state.save_tab_action(),
  },
  {
    key = "s",
    mods = "ALT",
    action = wezterm.action_callback(function(win, pane)
        resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
        resurrect.window_state.save_window_action()
      end),
  },
}
```

3. Loading workspace or window state via. fuzzy finder:

```lua
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

config.keys = {
  -- ...
  {
    key = "r",
    mods = "ALT",
    action = wezterm.action_callback(function(win, pane)
      resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id, label)
        local type = string.match(id, "^([^/]+)") -- match before '/'
        id = string.match(id, "([^/]+)$") -- match after '/'
        id = string.match(id, "(.+)%..+$") -- remove file extention
        local opts = {
          relative = true,
          restore_text = true,
          on_pane_restore = resurrect.tab_state.default_on_pane_restore,
        }
        if type == "workspace" then
          local state = resurrect.state_manager.load_state(id, "workspace")
          resurrect.workspace_state.restore_workspace(state, opts)
        elseif type == "window" then
          local state = resurrect.state_manager.load_state(id, "window")
          resurrect.window_state.restore_window(pane:window(), state, opts)
        elseif type == "tab" then
          local state = resurrect.state_manager.load_state(id, "tab")
          resurrect.tab_state.restore_tab(pane:tab(), state, opts)
        end
      end)
    end),
  },
}
```

4. Optional, enable encryption (recommended):
   You can optionally configure the plugin to encrypt and decrypt the saved state. [age](https://github.com/FiloSottile/age) is the default encryption provider. [Rage](https://github.com/str4d/rage) and [GnuPG](https://gnupg.org/) encryption are also supported.

4.1. Install `age` and generate a key with:

```sh
$ age-keygen -o key.txt
Public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
```

> [!NOTE]
> If you prefer to use [GnuPG](https://gnupg.org/), generate a key pair: `gpg --full-generate-key`. Get the public key with `gpg --armor --export your_email@example.com`.
> The private key is your email or key ID associated with the gpg key.

4.2. Enable encryption in your Wezterm config:

```lua
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
resurrect.state_manager.set_encryption({
  enable = true,
  method = "age" -- "age" is the default encryption method, but you can also specify "rage" or "gpg"
  private_key = "/path/to/private/key.txt", -- if using "gpg", you can omit this
  public_key = "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p",
})
```

> [!WARNING]
> FOR WINDOWS USERS
>
> Due to Windows limitations with `stdin`, errors cannot be returned from the `encrypt` function.

> [!TIP]
> If the encryption provider is not found in your PATH (common issue for GUI apps on Mac OS), you can specify the absolute path to the executable.
> e.g. `method = "/opt/homebrew/bin/age"`

Alternate implementations are possible by providing your own `encrypt` and `decrypt` functions:

```lua
resurrect.state_manager.set_encryption({
  enable = true,
  private_key = "/path/to/private/key.txt",
  public_key = "public_key",
  encrypt = function(file_path, lines)
    -- substitute for your encryption command
    local cmd = string.format(
      "%s -r %s -o %s",
      pub.encryption.method,
      pub.encryption.public_key,
      file_path:gsub(" ", "\\ ")
    )

    local success, output = execute_cmd_with_stdin(cmd, lines)
    if not success then
      error("Encryption failed:" .. output)
    end
  end,
  decrypt = function(file_path)
    -- substitute for your decryption command
    local cmd = { pub.encryption.method, "-d", "-i", pub.encryption.private_key, file_path }

    local success, stdout, stderr = wezterm.run_child_process(cmd)
    if not success then
      error("Decryption failed: " .. stderr)
    end

    return stdout
  end,
})
```

If you wish to share a non-documented way of encrypting your files or think something is missing, then please make a PR or file an issue.

## How do I use it?

I use the builtin `resurrect.state_manager.periodic_save()` to save my workspaces every 15 minutes.
This ensures that if I close Wezterm, then I can restore my session state to a state which is at most 15 minutes old.

I also use it to restore the state of my workspaces. As I use the plugin [smart_workspace_switcher.wezterm](https://github.com/MLFlexer/smart_workspace_switcher.wezterm),
to change workspaces whenever I change "project" (git repository).
I have added the following to my configuration to be able to do this whenever I change workspaces:

```lua
-- loads the state whenever I create a new workspace
wezterm.on("smart_workspace_switcher.workspace_switcher.created", function(window, path, label)
  local workspace_state = resurrect.workspace_state

  workspace_state.restore_workspace(resurrect.state_manager.load_state(label, "workspace"), {
    window = window,
    relative = true,
    restore_text = true,
    on_pane_restore = resurrect.tab_state.default_on_pane_restore,
  })
end)

-- Saves the state whenever I select a workspace
wezterm.on("smart_workspace_switcher.workspace_switcher.selected", function(window, path, label)
  local workspace_state = resurrect.workspace_state
  resurrect.state_manager.save_state(workspace_state.get_workspace_state())
end)
```

You can checkout my configuration [here](https://github.com/MLFlexer/.dotfiles/tree/main/home-manager/config/wezterm).

## Configuration

### Periodic saving of state

`resurrect.state_manager.periodic_save(opts?)` will save the workspace state every 15 minutes by default.
You can add the `opts` table to change the behaviour. It exposes the following options:

```lua
---@param opts? { interval_seconds: integer?, save_workspaces: boolean?, save_windows: boolean?, save_tabs: boolean? }
```

`interval_seconds` will save the state every time the supplied number of seconds has surpassed.
`save_workspaces` will save workspaces if true otherwise not.
`save_windows` will save windows if true otherwise not.
`save_tabs` will save tabs if true otherwise not.

### Resurrecting on startup

You can resume from where you left off by resurrecting on startup with
the following addition to your config:

```lua
wezterm.on("gui-startup", resurrect.state_manager.resurrect_on_gui_startup)
```

This will read a file which has been written by the
`resurrect.state_manager.write_current_state("workspace name", "workspace")` function.

> [!NOTE]
> For this to work, you must include a way to write the current workspace,
> be it via. the `resurrect.state_manager.periodic_save` event or when changing workspaces.

### Limiting the amount of output lines saved for a pane

`resurrect.state_manager.set_max_nlines(number)` will limit each pane to save
at most `number` lines to the state.
This can improve performance when saving and loading state.

### save_state options

`resurrect.state_manager.save_state(state, opt_name?)` takes an optional string argument,
which will rename the file to the name of the string.

### restore_opts

Options for restoring state:

```lua
{spawn_in_workspace: boolean?, -- Restores in the workspace
relative: boolean?, -- Use relative size when restoring panes
absolute: boolean?, -- Use absolute size when restoring panes
close_open_tabs: boolean?, -- Closes all tabs which are open in the window, only restored tabs are left
close_open_panes: boolean?, -- Closes all panes which are open in the tab, only keeping the panes to be restored
pane: Pane?, -- Restore in this window
tab: MuxTab?, -- Restore in this window
window: MuxWindow, -- Restore in this window
resize_window: boolean?, -- Resizes the window, default: true
on_pane_restore: fun(pane_tree: pane_tree)} -- Function to restore panes, use resurrect.tab_state.default_on_pane_restore
```

#### Windows not resizing correctly

Some users has had problems with `window_decorations` and `window_padding`
configuration options, which caused issues when resizing, see [comment](https://github.com/MLFlexer/resurrect.wezterm/issues/72#issuecomment-2582912347).
To avoid this, set the `resize_window` to false.

### Restoring into the current window

To restore a window state into the current window use the `restore_window`
function with `restore_opts` containing the window and `close_open_tabs` like so:

```lua
local opts = {
  close_open_tabs = true,
  window = pane:window(),
  on_pane_restore = resurrect.tab_state.default_on_pane_restore,
  relative = true,
  restore_text = true,
}
resurrect.window_state.restore_window(pane:window(), state, opts)
```

This will restore the state into the passed window and additionally close all
the tabs in the window, such that only the restored tabs are visible after restoring.

### fuzzy_load opts

the `resurrect.fuzzy_loader.fuzzy_load(window, pane, callback, opts?)` function takes an
optional `opts` argument, which has the following types:

```lua
---@alias fmt_fun fun(label: string): string
---@alias fuzzy_load_opts {
  title: string, -- dialog title, default: "Load state"
  description: string, -- description, default: "Select State to Load and press Enter = accept, Esc = cancel, / = filter"
  fuzzy_description: string, -- description in fyzzy search mode, default: "Search State to Load: "
  is_fuzzy: boolean, -- enter directly in fuzzy mode, default: true
  ignore_workspaces: boolean, -- does not show workspaces, default: false
  ignore_tabs: boolean, -- does not show tabs, default: false
  ignore_windows: boolean, -- does not show windows, default: false
  fmt_window: fmt_fun, -- format function for window state name (wezterm.format)
  fmt_workspace: fmt_fun, -- format function for workspace state name
  fmt_tab: fmt_fun, -- format function for tab state name
  fmt_date: fmt_fun, -- format function for date
  show_state_with_date: boolean, -- show last update of the state file, default: false
  date_format: string, -- date formatting, default: "%d-%m-%Y %H:%M:%S"
  ignore_screen_width: boolean, -- whether or not to shrink the list if the window is too narrow, default: true
  name_truncature: string, -- when state name is truncated, this string replaces the truncation
  min_filename_size: number -- minimum size of state name in case of truncation
}
```

This is used to format labels, ignore saved state, change the title and change the behaviour of the fuzzy finder.

### Change the directory to store the saved state

```lua
resurrect.state_manager.change_state_save_dir("/some/other/directory")
```

> [!WARNING]
> FOR WINDOWS USERS
>
> You must ensure that there is write access to the directory where the state is stored,
> as such it is suggested that you set your own state directory like so:
>
> ```lua
> -- Set some directory where Wezterm has write access
> resurrect.state_manager.change_state_save_dir("C:\\Users\\<user>\\Desktop\\state\\")
> ```

### Events

This plugin emits the following events that you can use for your own callback functions:

- `resurrect.error(err)`
- `resurrect.file_io.decrypt.finished(file_path)`
- `resurrect.file_io.decrypt.start(file_path)`
- `resurrect.file_io.encrypt.finished(file_path)`
- `resurrect.file_io.encrypt.start(file_path)`
- `resurrect.file_io.sanitize_json.finished(data)`
- `resurrect.file_io.sanitize_json.start(data)`
- `resurrect.fuzzy_loader.fuzzy_load.finished(window, pane)`
- `resurrect.fuzzy_loader.fuzzy_load.start(window, pane)`
- `resurrect.state_manager.delete_state.finished(file_path)`
- `resurrect.state_manager.delete_state.start(file_path)`
- `resurrect.state_manager.load_state.finished(name, type)`
- `resurrect.state_manager.load_state.start(name, type)`
- `resurrect.state_manager.periodic_save.start(opts)`
- `resurrect.state_manager.periodic_save.finished(opts)`
- `resurrect.file_io.write_state.finished(file_path, event_type)`
- `resurrect.file_io.write_state.start(file_path, event_type)`
- `resurrect.tab_state.restore_tab.finished`
- `resurrect.tab_state.restore_tab.start`
- `resurrect.window_state.restore_window.finished`
- `resurrect.window_state.restore_window.start`
- `resurrect.workspace_state.restore_workspace.finished`
- `resurrect.workspace_state.restore_workspace.start`

Example: sending a toast notification when specified events occur, but suppress on `periodic_save()`:

```lua
local resurrect_event_listeners = {
  "resurrect.error",
  "resurrect.state_manager.save_state.finished",
}
local is_periodic_save = false
wezterm.on("resurrect.periodic_save", function()
  is_periodic_save = true
end)
for _, event in ipairs(resurrect_event_listeners) do
  wezterm.on(event, function(...)
    if event == "resurrect.state_manager.save_state.finished" and is_periodic_save then
      is_periodic_save = false
      return
    end
    local args = { ... }
    local msg = event
    for _, v in ipairs(args) do
      msg = msg .. " " .. tostring(v)
    end
    wezterm.gui.gui_windows()[1]:toast_notification("Wezterm - resurrect", msg, nil, 4000)
  end)
end
```

## State files

State files are json files, which will be decoded into lua tables.
This can be used to create your own layout files which can then be loaded.
Here is an example of a json file:

```json
{
   "window_states":[
      {
         "size":{
            "cols":191,
            "dpi":96,
            "pixel_height":1000,
            "pixel_width":1910,
            "rows":50
         },
         "tabs":[
            {
               "is_active":true,
               "pane_tree":{
                  "cwd":"/home/user/",
                  "domain": "SSHMUX:domain",
                  "height":50,
                  "index":0,
                  "is_active":true,
                  "is_zoomed":false,
                  "left":0,
                  "pixel_height":1000,
                  "pixel_width":1910,
                  "process":"/bin/bash", -- value is empty if attached to a remote domain
                  "text":"Some text", -- not saved if attached to a remote domain, see https://github.com/MLFlexer/resurrect.wezterm/issues/41
                  "top":0,
                  "width":191
               },
               "title":"tab_title"
            }
         ],
         "title":"window_title"
      }
   ],
   "workspace":"workspace_name"
}
```

### Delete a saved state file via. fuzzy finder

You can use the fuzzy finder to delete a saved state file by adding a keybind to your config:

```lua
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

config.keys = {
  -- ...
  {
    key = "d",
    mods = "ALT",
    action = wezterm.action_callback(function(win, pane)
      resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id)
          resurrect.state_manager.delete_state(id)
        end,
        {
          title = "Delete State",
          description = "Select State to Delete and press Enter = accept, Esc = cancel, / = filter",
          fuzzy_description = "Search State to Delete: ",
          is_fuzzy = true,
        })
    end),
  },
}
```

## Augmenting the command palette

If you would like to add entries in your Wezterm command palette for renaming and switching workspaces:

```lua
local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")

wezterm.on("augment-command-palette", function(window, pane)
  local workspace_state = resurrect.workspace_state
  return {
    {
      brief = "Window | Workspace: Switch Workspace",
      icon = "md_briefcase_arrow_up_down",
      action = workspace_switcher.switch_workspace(),
    },
    {
      brief = "Window | Workspace: Rename Workspace",
      icon = "md_briefcase_edit",
      action = wezterm.action.PromptInputLine({
        description = "Enter new name for workspace",
        action = wezterm.action_callback(function(window, pane, line)
          if line then
            wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
            resurrect.state_manager.save_state(workspace_state.get_workspace_state())
          end
        end),
      }),
    },
  }
end)
```

## FAQ

### Pane CWD is not correct on Windows

If your pane CWD is incorrect then it might be a problem with the shell
integration and OSC 7. See [Wezterm documentation](https://wezfurlong.org/wezterm/shell-integration.html).

### How do I keep my plugins up to date?

#### Manually

Wezterm git clones your plugins into a plugin directory.
Enter `wezterm.plugin.list()` in the Wezterm Debug Overlay (`Ctrl + Shift + L`)
to see where they are stored. You can then update them individually using git pull.

#### Automatically

Add `wezterm.plugin.update_all()` to your Wezterm config.

## Testing

Tests are run with Busted via LuaRocks.

All OSes:

```sh
luarocks install busted
```

Run tests:

```sh
eval "$(luarocks path)"
busted
```

Windows notes:

- PowerShell is the most reliable shell for running LuaRocks and Busted (Git Bash/MSYS can mangle arguments and paths).
- If `luarocks install busted` fails while building native dependencies (for example `luasystem`), install a GCC toolchain (MinGW-w64 or MSYS2 MinGW64) and make sure its `bin` directory is on `PATH` for the PowerShell session.

PowerShell usage:

```powershell
Invoke-Expression (luarocks path)
busted
```

## Contributions

Suggestions, Issues and PRs are welcome!
The features currently implemented are the ones I use the most, but your
workflow might differ. As such, if you have any proposals on how to improve
the plugin, then please feel free to make an issue or even better a PR!

### Technical details

Restoring of the panes are done via. the `pane_tree` file,
which has functions to work on a binary-like-tree of the panes.
Each node in the pane_tree represents a possible split pane.
If the pane has a `bottom` and/or `right` child, then the pane is split.
If you have any questions to the implementation,
then I suggest you read the code or open an issue and I will try to clarify.
Improvements to this section is also very much welcome.

## Disclaimer

If you don't setup encryption then the state of your terminal is saved as
plaintext json files. Please be aware that the plugin will by default write the
output of the shell among other things, which could contain secrets or other
vulnerable data. If you do not want to store this as plaintext, then please use
the provided documentation for encrypting state.
