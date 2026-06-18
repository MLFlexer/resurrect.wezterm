local function is_windows()
  return package.config:sub(1, 1) == "\\"
end

-- Minimal wezterm stub for utils.lua.
local wezterm_stub = {
  target_triple = is_windows() and "x86_64-pc-windows-msvc" or "x86_64-unknown-linux-gnu",
}
_G.wezterm = wezterm_stub
package.preload["wezterm"] = function()
  return wezterm_stub
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

local utils = require("resurrect.utils")

local sep = utils.is_windows and "\\" or "/"

-- Probe by writing a temp file inside the directory.
-- os.rename(dir, dir) can return nil on Windows for permission/lock reasons
-- even when the directory exists, giving a misleading false negative.
local function dir_exists(path)
  local probe = path .. sep .. ".probe"
  local f = io.open(probe, "w")
  if f then
    f:close()
    os.remove(probe)
    return true
  end
  return false
end

local function rmdir_recursive(path)
  if utils.is_windows then
    if not path:find('"') then
      os.execute('rmdir /s /q "' .. path .. '" >nul 2>&1')
    end
  else
    local quoted = "'" .. path:gsub("'", "'\\''") .. "'"
    os.execute("rm -rf " .. quoted)
  end
end

-- Returns a unique absolute temp path without creating it.
-- tostring({}) yields a unique table address within this process; combined with
-- os.time() it is extremely unlikely to collide across concurrent processes.
local function unique_tmp_base()
  local id = tostring(os.time()) .. "_" .. tostring({}):gsub("[^%w]", "")
  if utils.is_windows then
    local tmp_dir = os.getenv("TEMP") or os.getenv("TMP") or "C:\\Temp"
    return tmp_dir .. "\\_resurrect_test_" .. id
  else
    return "/tmp/_resurrect_test_" .. id
  end
end

describe("utils.ensure_folder_exists", function()
  local test_base
  local cleanup_extras  -- additional paths cleaned up by after_each

  before_each(function()
    test_base = unique_tmp_base()
    cleanup_extras = {}
  end)

  after_each(function()
    rmdir_recursive(test_base)
    for _, path in ipairs(cleanup_extras) do
      rmdir_recursive(path)
    end
  end)

  it("creates a nested directory structure", function()
    local nested = test_base .. sep .. "a" .. sep .. "b"
    assert.is_true(utils.ensure_folder_exists(nested))
    assert.is_true(dir_exists(test_base))
    assert.is_true(dir_exists(nested))
  end)

  -- The open-handle false-negative scenario (Windows only, triggered when
  -- WezTerm holds a handle to the directory) cannot be tested portably without
  -- monkey-patching io.open. The idempotency test below exercises the
  -- happy-path re-entry but not the open-handle scenario.
  it("is idempotent on an existing path", function()
    local nested = test_base .. sep .. "a" .. sep .. "b"
    assert.is_true(utils.ensure_folder_exists(nested))
    assert.is_true(utils.ensure_folder_exists(nested))
  end)

  it("handles directory names containing spaces", function()
    local spaced = test_base .. sep .. "dir with spaces" .. sep .. "nested dir"
    assert.is_true(utils.ensure_folder_exists(spaced))
    assert.is_true(dir_exists(spaced))
  end)

  it("returns false when a path component is a file, not a directory", function()
    assert.is_true(utils.ensure_folder_exists(test_base))
    local obstacle = test_base .. sep .. "obstacle.txt"
    local f = assert(io.open(obstacle, "w"))
    f:write("x")
    f:close()
    assert.is_false(utils.ensure_folder_exists(obstacle .. sep .. "child"))
  end)

  it("handles relative paths", function()
    local id = tostring({}):gsub("[^%w]", "")
    local rel_base = "_resurrect_rel_" .. id
    -- Register before asserting so after_each cleans up even on failure.
    -- This path lands in CWD rather than the temp root, so it cannot be
    -- covered by the test_base cleanup.
    table.insert(cleanup_extras, rel_base)
    local rel_nested = rel_base .. sep .. "a" .. sep .. "b"
    assert.is_true(utils.ensure_folder_exists(rel_nested))
    assert.is_true(dir_exists(rel_nested))
  end)

  -- Windows-only path form tests.
  -- UNC paths (\\server\share\...) are not tested: the server and share
  -- components cannot be created via mkdir, so a meaningful test would require
  -- a live network share or privileged loopback (\\localhost\c$\...) that is
  -- not suitable for a local or CI environment.
  if utils.is_windows then
    it("handles absolute paths with a drive letter", function()
      local drive = (os.getenv("TEMP") or "C:\\"):match("^(%a:)") or "C:"
      local abs_base = drive .. "\\_resurrect_abs_" .. tostring({}):gsub("[^%w]", "")
      table.insert(cleanup_extras, abs_base)
      local abs_nested = abs_base .. "\\x\\y"
      assert.is_true(utils.ensure_folder_exists(abs_nested))
      assert.is_true(dir_exists(abs_nested))
    end)

    it("normalises drive-relative paths (C:foo) to absolute from drive root", function()
      local drive = (os.getenv("TEMP") or "C:\\"):match("^(%a:)") or "C:"
      local id = tostring({}):gsub("[^%w]", "")
      local abs_base = drive .. "\\_resurrect_driverel_" .. id
      table.insert(cleanup_extras, abs_base)
      -- Pass the path without a separator after the drive letter.
      local driverel = drive .. "_resurrect_driverel_" .. id .. "\\sub"
      -- The function should normalise this to drive:\... and create it there.
      local expected = abs_base .. "\\sub"
      assert.is_true(utils.ensure_folder_exists(driverel))
      assert.is_true(dir_exists(expected))
    end)
  end
end)
