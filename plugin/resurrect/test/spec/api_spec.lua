-- Tests for shell/api.lua
-- Verifies that WezTerm API data extraction is correctly centralized

local mux = require("mux")
local fixtures = require("pane_layouts")

-- Import module under test
local shell_api = require("resurrect.shell.api")

--------------------------------------------------------------------------------
-- Setup / Teardown
--------------------------------------------------------------------------------

describe("Shell API", function()
	before(function()
		mux.reset()
		wezterm._test.reset()
		wezterm._test.set_mux(mux)
	end)

	---------------------------------------------------------------------------
	-- extract_pane Tests
	---------------------------------------------------------------------------

	describe("extract_pane", function()
		it("extracts cwd from pane", function()
			local workspace = mux.workspace("test"):window("win"):tab("tab"):pane(fixtures.single_pane.panes[1]):build()

			mux.set_active(workspace)

			local tab = workspace.windows[1]:tabs()[1]
			local pane = tab:active_pane()

			local raw = shell_api.extract_pane(pane, 1000)

			expect(raw.cwd).to.equal("/home/user")
		end)

		it("extracts domain name", function()
			local workspace = mux.workspace("test"):window("win"):tab("tab"):pane(fixtures.single_pane.panes[1]):build()

			mux.set_active(workspace)

			local tab = workspace.windows[1]:tabs()[1]
			local pane = tab:active_pane()

			local raw = shell_api.extract_pane(pane, 1000)

			expect(raw.domain).to.equal("local")
		end)

		it("extracts is_spawnable for local domain", function()
			local workspace = mux.workspace("test"):window("win"):tab("tab"):pane(fixtures.single_pane.panes[1]):build()

			mux.set_active(workspace)

			local tab = workspace.windows[1]:tabs()[1]
			local pane = tab:active_pane()

			local raw = shell_api.extract_pane(pane, 1000)

			expect(raw.is_spawnable).to.equal(true)
		end)

		it("handles empty cwd", function()
			local workspace = mux.workspace("test"):window("win"):tab("tab"):pane(fixtures.empty_cwd.panes[1]):build()

			mux.set_active(workspace)

			local tab = workspace.windows[1]:tabs()[1]
			local pane = tab:active_pane()

			local raw = shell_api.extract_pane(pane, 1000)

			expect(raw.cwd).to.equal("")
		end)

		it("extracts alt_screen_active status", function()
			local workspace =
				mux.workspace("test"):window("win"):tab("tab"):pane(fixtures.with_alt_screen.panes[1]):build()

			mux.set_active(workspace)

			local tab = workspace.windows[1]:tabs()[1]
			local pane = tab:active_pane()

			local raw = shell_api.extract_pane(pane, 1000)

			expect(raw.alt_screen_active).to.equal(true)
		end)

		it("extracts process info when alt screen active", function()
			local workspace =
				mux.workspace("test"):window("win"):tab("tab"):pane(fixtures.with_alt_screen.panes[1]):build()

			mux.set_active(workspace)

			local tab = workspace.windows[1]:tabs()[1]
			local pane = tab:active_pane()

			local raw = shell_api.extract_pane(pane, 1000)

			expect(raw.process).to.exist()
			expect(raw.process.name).to.equal("vim")
		end)

		it("extracts scrollback text when not in alt screen", function()
			local workspace =
				mux.workspace("test"):window("win"):tab("tab"):pane(fixtures.with_scrollback.panes[1]):build()

			mux.set_active(workspace)

			local tab = workspace.windows[1]:tabs()[1]
			local pane = tab:active_pane()

			local raw = shell_api.extract_pane(pane, 1000)

			expect(raw.text).to.exist()
			expect(raw.text:find("ls")).to.exist()
		end)

		it("marks non-spawnable domains", function()
			-- Set up a non-spawnable domain
			mux.set_domain_spawnable("SSH:broken", false)

			local workspace = mux.workspace("test")
				:window("win")
				:tab("tab")
				:pane({ left = 0, top = 0, width = 160, height = 48, cwd = "/remote", domain = "SSH:broken" })
				:build()

			mux.set_active(workspace)

			local tab = workspace.windows[1]:tabs()[1]
			local pane = tab:active_pane()

			local raw = shell_api.extract_pane(pane, 1000)

			expect(raw.is_spawnable).to.equal(false)
		end)
	end)

	---------------------------------------------------------------------------
	-- extract_panes Tests
	---------------------------------------------------------------------------

	describe("extract_panes", function()
		it("extracts all panes with geometry", function()
			local workspace = mux.workspace("test")
				:window("win")
				:tab("tab")
				:pane(fixtures.hsplit.panes[1])
				:hsplit(fixtures.hsplit.panes[2])
				:build()

			mux.set_active(workspace)

			local tab = workspace.windows[1]:tabs()[1]
			local panes_info = tab:panes_with_info()

			local raw_panes = shell_api.extract_panes(panes_info, 1000)

			expect(#raw_panes).to.equal(2)
		end)

		it("preserves geometry from PaneInformation", function()
			local workspace = mux.workspace("test")
				:window("win")
				:tab("tab")
				:pane(fixtures.hsplit.panes[1])
				:hsplit(fixtures.hsplit.panes[2])
				:build()

			mux.set_active(workspace)

			local tab = workspace.windows[1]:tabs()[1]
			local panes_info = tab:panes_with_info()

			local raw_panes = shell_api.extract_panes(panes_info, 1000)

			-- First pane should be at left=0
			expect(raw_panes[1].left).to.equal(0)
			expect(raw_panes[1].width).to.equal(80)

			-- Second pane should be to the right
			expect(raw_panes[2].left).to.equal(81)
		end)

		it("preserves is_active from PaneInformation", function()
			local workspace = mux.workspace("test")
				:window("win")
				:tab("tab")
				:pane(fixtures.hsplit.panes[1])
				:hsplit(fixtures.hsplit.panes[2])
				:build()

			mux.set_active(workspace)

			local tab = workspace.windows[1]:tabs()[1]
			local panes_info = tab:panes_with_info()

			local raw_panes = shell_api.extract_panes(panes_info, 1000)

			-- First pane is active in fixture
			expect(raw_panes[1].is_active).to.equal(true)
		end)

		it("preserves is_zoomed from PaneInformation", function()
			local workspace = mux.workspace("test"):window("win"):tab("tab"):pane(fixtures.zoomed_pane.panes[1]):build()

			mux.set_active(workspace)

			local tab = workspace.windows[1]:tabs()[1]
			local panes_info = tab:panes_with_info()

			local raw_panes = shell_api.extract_panes(panes_info, 1000)

			expect(raw_panes[1].is_zoomed).to.equal(true)
		end)
	end)

	---------------------------------------------------------------------------
	-- extract_tab Tests
	---------------------------------------------------------------------------

	describe("extract_tab", function()
		it("extracts tab title", function()
			local workspace =
				mux.workspace("test"):window("win"):tab("my-tab"):pane(fixtures.single_pane.panes[1]):build()

			mux.set_active(workspace)

			local tab = workspace.windows[1]:tabs()[1]

			local raw_tab = shell_api.extract_tab(tab, 1000)

			expect(raw_tab.title).to.equal("my-tab")
		end)

		it("extracts all panes in tab", function()
			local workspace = mux.workspace("test")
				:window("win")
				:tab("tab")
				:pane(fixtures.ide_layout.panes[1])
				:hsplit(fixtures.ide_layout.panes[2])
				:vsplit(fixtures.ide_layout.panes[3])
				:build()

			mux.set_active(workspace)

			local tab = workspace.windows[1]:tabs()[1]

			local raw_tab = shell_api.extract_tab(tab, 1000)

			expect(#raw_tab.panes).to.equal(3)
		end)

		it("detects zoomed state from any pane", function()
			local workspace = mux.workspace("test")
				:window("win")
				:tab("tab")
				:pane(fixtures.zoomed_pane.panes[1])
				:hsplit(fixtures.zoomed_pane.panes[2])
				:build()

			mux.set_active(workspace)

			local tab = workspace.windows[1]:tabs()[1]

			local raw_tab = shell_api.extract_tab(tab, 1000)

			expect(raw_tab.is_zoomed).to.equal(true)
		end)
	end)

	---------------------------------------------------------------------------
	-- extract_window Tests
	---------------------------------------------------------------------------

	describe("extract_window", function()
		it("extracts window title", function()
			local workspace =
				mux.workspace("test"):window("my-window"):tab("tab"):pane(fixtures.single_pane.panes[1]):build()

			mux.set_active(workspace)

			local window = workspace.windows[1]

			local raw_window = shell_api.extract_window(window, 1000)

			expect(raw_window.title).to.equal("my-window")
		end)

		it("extracts all tabs", function()
			local workspace = mux.workspace("test")
				:window("win")
				:tab("tab1")
				:pane(fixtures.single_pane.panes[1])
				:tab("tab2")
				:pane(fixtures.single_pane.panes[1])
				:build()

			mux.set_active(workspace)

			local window = workspace.windows[1]

			local raw_window = shell_api.extract_window(window, 1000)

			expect(#raw_window.tabs).to.equal(2)
		end)

		it("marks active tab", function()
			local workspace = mux.workspace("test")
				:window("win")
				:tab("tab1")
				:pane(fixtures.single_pane.panes[1])
				:tab("tab2")
				:pane(fixtures.single_pane.panes[1])
				:build()

			mux.set_active(workspace)

			local window = workspace.windows[1]

			local raw_window = shell_api.extract_window(window, 1000)

			-- First tab is active by default
			expect(raw_window.tabs[1].is_active).to.equal(true)
		end)

		it("extracts window size", function()
			local workspace = mux.workspace("test"):window("win"):tab("tab"):pane(fixtures.single_pane.panes[1]):build()

			mux.set_active(workspace)

			local window = workspace.windows[1]

			local raw_window = shell_api.extract_window(window, 1000)

			expect(raw_window.size).to.exist()
			expect(raw_window.size.cols).to.exist()
			expect(raw_window.size.rows).to.exist()
		end)
	end)

	---------------------------------------------------------------------------
	-- warn_not_spawnable Tests
	---------------------------------------------------------------------------

	describe("warn_not_spawnable", function()
		it("emits resurrect.error event", function()
			wezterm._test.clear_emitted_events()

			shell_api.warn_not_spawnable("SSH:broken")

			local events = wezterm._test.get_emitted_events()
			local found = false
			for _, event in ipairs(events) do
				if event.name == "resurrect.error" then
					found = true
					expect(event.args[1]:find("SSH:broken")).to.exist()
				end
			end
			expect(found).to.equal(true)
		end)

		it("logs warning", function()
			wezterm._test.clear_logs()

			shell_api.warn_not_spawnable("SSH:broken")

			local logs = wezterm._test.get_logs()
			local found = false
			for _, log in ipairs(logs) do
				if log.level == "warn" and log.message:find("SSH:broken") then
					found = true
				end
			end
			expect(found).to.equal(true)
		end)
	end)

	---------------------------------------------------------------------------
	-- Multi-domain Tests
	---------------------------------------------------------------------------

	describe("multi-domain scenarios", function()
		it("handles mixed local and SSH domains", function()
			local workspace = mux.workspace("test")
				:window("win")
				:tab("tab")
				:pane(fixtures.multi_domain.panes[1])
				:hsplit(fixtures.multi_domain.panes[2])
				:build()

			mux.set_active(workspace)

			local tab = workspace.windows[1]:tabs()[1]
			local panes_info = tab:panes_with_info()

			local raw_panes = shell_api.extract_panes(panes_info, 1000)

			expect(raw_panes[1].domain).to.equal("local")
			expect(raw_panes[2].domain).to.equal("SSH:server")
		end)
	end)
end)
