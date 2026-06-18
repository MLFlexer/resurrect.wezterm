local function is_windows()
  return package.config:sub(1, 1) == "\\"
end

-- Minimal wezterm stub.
local wezterm_stub = {
  target_triple = is_windows() and "x86_64-pc-windows-msvc" or "x86_64-unknown-linux-gnu",
  emit = function() end,
}
_G.wezterm = wezterm_stub
package.preload["wezterm"] = function()
  return wezterm_stub
end

-- Stub file_io and capture the path passed to load_json so we can assert
-- on what get_file_path (a local function) actually produced.
local last_load_path
package.preload["resurrect.file_io"] = function()
  return {
    load_json = function(path)
      last_load_path = path
      return {}
    end,
    write_state = function() end,
    write_file = function() end,
  }
end

local search_paths = {
  -- repo root
  "./plugin/?.lua",
  "./plugin/?/init.lua",
  "./plugin/?/?.lua",
  -- when cwd is plugin/resurrect
  "../../plugin/?.lua",
  "../../plugin/?/init.lua",
  "../../plugin/?/?.lua",
}

package.path = table.concat(search_paths, ";") .. ";" .. package.path

local state_manager = require("resurrect.state_manager")

local sep = is_windows() and "\\" or "/"
local base = is_windows()
  and ((os.getenv("TEMP") or os.getenv("TMP") or "C:\\Temp") .. "\\resurrect_sm_test")
  or "/tmp/resurrect_sm_test"

-- get_file_path is a local function and cannot be called directly.
-- These tests exercise it via load_state(), which passes its return value
-- straight to file_io.load_json() with no intervening transformation.
describe("state_manager path construction (via load_state)", function()
  before_each(function()
    last_load_path = nil
    state_manager.save_state_dir = base
  end)

  it("separates save_state_dir and type with a path separator", function()
    state_manager.load_state("myworkspace", "workspace")
    assert.equals(base .. sep .. "workspace" .. sep .. "myworkspace.json", last_load_path)
  end)

  it("replaces path separator characters in file names with +", function()
    state_manager.load_state("foo" .. sep .. "bar", "workspace")
    assert.equals(base .. sep .. "workspace" .. sep .. "foo+bar.json", last_load_path)
  end)

  it("replaces reserved characters : [ ] ? / in file names with +", function()
    state_manager.load_state("name:with[reserved]chars?and/slashes", "window")
    assert.equals(
      base .. sep .. "window" .. sep .. "name+with+reserved+chars+and+slashes.json",
      last_load_path
    )
  end)
end)
