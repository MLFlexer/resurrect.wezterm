# resurrect.wezterm
Resurrect your terminal environment!⚰️ A plugin to save the state of your windows, tabs and panes. Inspired by [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) and [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum).

![Screencastfrom2024-07-2918-50-57-ezgif com-resize](https://github.com/user-attachments/assets/640aefea-793c-486d-9579-1a9c8bb4c1fa)

## Features
* Restore your windows, tabs and panes with the layout and text from a saved state.
* Restore shell output from a saved session.
* Save the state of your current window, with every window, tab and pane state stored in a `json` file.
* Restore the save from a `json` file.
* Optionally enable [age](https://github.com/FiloSottile/age) encryption and decryption of the saved state.

## Setup example
1. Require the plugin:
```lua
local wezterm = require("wezterm")
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
```
> [!WARNING] 
> 1.1 FOR WINDOWS USERS
> 
> You must ensure that there is write access to the directory where the state is stored, as such it is suggested that you set your own state direcory like so:
> ```lua
> resurrect.save_state_dir = "C:\\Users\\Admin\\Desktop\\state\\" -- Set some directory where wezterm has write access
> ```

2. Saving workspace state:
```lua
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

config.keys = {
  -- ...
  {
  key = "s",
  mods = "ALT",
  action = wezterm.action.Multiple({
    wezterm.action_callback(function(win, pane)
      resurrect.save_state(resurrect.workspace_state.get_workspace_state())
    end),
    }),
  },
}
```

3. Loading workspace state via. fuzzy finder:
```lua
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

config.keys = {
  -- ...
  {
    key = "l",
    mods = "ALT",
    action = wezterm.action.Multiple({
      wezterm.action_callback(function(win, pane)
	resurrect.fuzzy_load(win, pane, function(id, label)
	  id = string.match(id, "([^/]+)$")
	  id = string.match(id, "(.+)%..+$")
	  local state = resurrect.load_state(id, "workspace")
	  resurrect.workspace_state.restore_workspace(state, {
	    relative = true,
	    restore_text = true,
            on_pane_restore = resurrect.tab_state.default_on_pane_restore,
	  })
	end)
      end),
    }),
  },
}
```

4. Optional: Enable `age` encryption (requires [age](https://github.com/FiloSottile/age) to be installed and available on your PATH):

You can optionally configure the plugin to encrypt and decrypt the saved state.
See [encryption doc](/encryption.md) for other encryption providers and configuration.

4.1. Install `age` and generate a key with:
```sh
$ age-keygen -o key.txt
Public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
```

4.2. Enable encryption in your Wezterm config:
```lua
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")
resurrect.set_encryption({
  enable = true,
  private_key = "/path/to/private/key.txt",
  public_key = "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p",
})
```

 Currently, only `age` encryption is supported. Alternate implementations are possible by providing your own `encrypt` and `decrypt` functions:
```lua
resurrect.set_encryption({
  enable = true,
  private_key = "/path/to/private/key.txt",
  public_key = "public_key",
  encrypt = function(file_path, lines)
    local success, stdout, stderr = wezterm.run_child_process({
      os.getenv("SHELL"),
      "-c",
      -- command to encrypt
    })
    if not success then
        wezterm.log_error(stderr)
    end
    wezterm.log_info(stdout)
  end,
  decrypt = function(file_path)
    local success, stdout, stderr = wezterm.run_child_process({
      os.getenv("SHELL"),
      "-c",
      -- command to decrypt
    })
    if not success then
        wezterm.log_error(stderr)
    else
        return stdout
    end
  end,
})
```

## How do I use it?
I use the buildin `resurrect.periodic_save()` to save my workspaces every 15 minutes. This ensures that if I close Wezterm, then I can restore my session state to a state which is at most 15 minutes old.


I also use it to restore the state of my workspaces. As I use the plugin [smart_workspace_switcher.wezterm](https://github.com/MLFlexer/smart_workspace_switcher.wezterm), to change workspaces whenever I change "project" (git repository).
I have added the following to my configuration to be able to do this whenever I change workspaces:
```lua
-- loads the state whenever I create a new workspace
wezterm.on("smart_workspace_switcher.workspace_switcher.created", function(window, path, label)
  local workspace_state = resurrect.workspace_state

  workspace_state.restore_workspace(resurrect.load_state(label, "workspace"), {
    window = window,
    relative = true,
    restore_text = true,
    on_pane_restore = resurrect.tab_state.default_on_pane_restore,
  })
end)

-- Saves the state whenever I select a workspace
wezterm.on("smart_workspace_switcher.workspace_switcher.selected", function(window, path, label)
  local workspace_state = resurrect.workspace_state
  resurrect.save_state(workspace_state.get_workspace_state())
end)
```
You can checkout my configuration [here](https://github.com/MLFlexer/.dotfiles/tree/main/home-manager/config/wezterm).

## Configuration
### Periodic saving of state
`resurrect.periodic_save(interval_seconds?)` will save the workspace state every 15 minutes or `interval_seconds` if supplied.
### Limiting the amount of output lines saved for a pane
`resurrect.set_max_nlines(number)` will limit each pane to save at most `number` lines to the state. This can improve performance when saving and loading state.
### save_state options
`resurrect.save_state(state, opt_name?)` takes an optional string argument, which will rename the file to the name of the string.
### fuzzy_load opts
the `resurrect.fuzzy_load(window, pane, callback, opts?)` function takes an optional `opts` argument, which has the following types:
```lua
---@alias fmt_fun fun(label: string): string
---@alias fuzzy_load_opts {title: string, is_fuzzy: boolean, ignore_workspaces: boolean, ignore_tabs: boolean, ignore_windows: boolean, fmt_window: fmt_fun, fmt_workspace: fmt_fun, fmt_tab: fmt_fun }
```
This is used to format labels, ignore saved state, change the title and change the behaviour of the fuzzy finder.
### Change the directory to store the saved state
```lua
resurrect.change_state_save_dir("/some/other/directory")
```

## State files
State files are json files, which will be decoded into lua tables. This can be used to create your own layout files which can then be loaded. Here is an example of a json file:
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
                  "height":50,
                  "index":0,
                  "is_active":true,
                  "is_zoomed":false,
                  "left":0,
                  "pixel_height":1000,
                  "pixel_width":1910,
                  "process":"/bin/bash",
                  "text":"Some text",
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

## Augmenting the command palette

If you would like to add entries in your Wezterm command palette for renaming and switching workspaces:
```lua
local workspace_switcher = wezterm.plugin.require 'https://github.com/MLFlexer/smart_workspace_switcher.wezterm'

wezterm.on('augment-command-palette', function(window, pane)
  local workspace_state = resurrect.workspace_state
  return {
    {
      brief = 'Window | Workspace: Switch Workspace',
      icon = 'md_briefcase_arrow_up_down',
      action = workspace_switcher.switch_workspace(),
    },
    {
      brief = 'Window | Workspace: Rename Workspace',
      icon = 'md_briefcase_edit',
      action = wezterm.action.PromptInputLine {
        description = 'Enter new name for workspace',
        action = wezterm.action_callback(function(window, pane, line)
          if line then
            wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
            resurrect.save_state(workspace_state.get_workspace_state())
          end
        end),
      },
    },
  }
end)
```

## FAQ
### Pane CWD is not correct on Windows
If you pane CWD is incorrect then it might be a problem with the shell integration and OSC 7. See [Wezterm documentation](https://wezfurlong.org/wezterm/shell-integration.html).

## Contributions
Suggestions, Issues and PRs are welcome! The features currently implemented are the ones I use the most, but your workflow might differ. As such, if you have any proposals on how to improve the plugin please feel free to make an issue or even better a PR!

### Technical details
Restoring of the panes are done via. the `pane_tree` file, which has functions to work on a binary-like-tree of the panes. Each node in the pane_tree represents a possible split pane. If the pane has a `bottom` and/or `right` child, then the pane is split. If you have any questions to the implementation, then I suggest you read the code or open an issue and I will try to clarify. Improvements to this section is also very much welcome.


## Disclaimer
If you don't setup encryption then the state of your terminal is saved as plaintext json files. Please be aware that the plugin will by default write the output of the shell among other things, which could contain secrets or other vulnerable data. If you do not want to store this as plaintext, then please use the provided implementation for encrypting with [age](https://github.com/FiloSottile/age) or see [encryption docs](/encryption.md) for other ways to encrypt your state.

