-- Pull in the wezterm API
local wezterm = require("wezterm")
local act = wezterm.action
-- local mux = wezterm.mux
-- This will hold the configuration.
local config = wezterm.config_builder()
-- local gpus = wezterm.gui.enumerate_gpus()
-- config.webgpu_preferred_adapter = gpus[1]
-- config.front_end = "WebGpu"

config.front_end = "OpenGL"
config.max_fps = 144
config.default_cursor_style = "BlinkingBlock"
config.animation_fps = 1
config.cursor_blink_rate = 500
config.term = "xterm-256color" -- Set the terminal type

-- IBM VGA 8x16 sin suavizado; Hack queda de respaldo para los iconos de Nerd Font
config.font = wezterm.font_with_fallback({ "PxPlus IBM VGA 8x16", "Hack Nerd Font Mono" })
config.freetype_load_target = "Mono"
config.freetype_render_target = "Mono"
-- config.font = wezterm.font("Hack Nerd Font Mono")
-- config.font = wezterm.font("Monocraft Nerd Font")
-- config.font = wezterm.font("FiraCode Nerd Font Mono")
-- config.font = wezterm.font("JetBrains Mono Regular")
-- config.cell_width = 0.9
-- config.font = wezterm.font("Menlo Regular")
-- config.font = wezterm.font("Hasklig")
-- config.font = wezterm.font("Monoid Retina")
-- config.font = wezterm.font("InputMonoNarrow")
-- config.font = wezterm.font("mononoki Regular")
-- config.font = wezterm.font("Iosevka")
-- config.font = wezterm.font("M+ 1m")
-- config.font = wezterm.font("Hack Regular")
-- config.cell_width = 0.9
config.window_background_opacity = 1.0
config.prefer_egl = true
-- 12 pt = 16 px por celda (tamaño nativo de la fuente); 24 es el otro tamaño nítido
config.font_size = 12.0

config.window_padding = {
	left = 8,
	right = 8,
	top = 8,
	bottom = 8,
}

-- tabs
-- Siempre visible: sin borde, la barra de pestañas es de donde se arrastra la ventana
config.hide_tab_bar_if_only_one_tab = false
-- Barra alta con pestañas tipo Windows Terminal (la retro mide una sola celda)
config.use_fancy_tab_bar = true
-- config.tab_bar_at_bottom = true

-- config.inactive_pane_hsb = {
-- 	saturation = 0.0,
-- 	brightness = 1.0,
-- }

-- This is where you actually apply your config choices
--

-- color scheme toggling
wezterm.on("toggle-colorscheme", function(window, pane)
	local overrides = window:get_config_overrides() or {}
	if overrides.color_scheme == "Zenburn" then
		overrides.color_scheme = "Athanor"
	else
		overrides.color_scheme = "Zenburn"
	end
	window:set_config_overrides(overrides)
end)

-- Pestañas estilo navegador. Dentro de vim/nvim las teclas pasan de largo al editor.
local function in_editor(pane)
	local name = (pane:get_foreground_process_name() or ""):lower()
	return name:find("vim") ~= nil
end

local function browser_key(key, mods, fn)
	return {
		key = key,
		mods = mods,
		action = wezterm.action_callback(function(window, pane)
			if in_editor(pane) then
				window:perform_action(act.SendKey({ key = key, mods = mods }), pane)
			else
				fn(window, pane)
			end
		end),
	}
end

-- Carpetas de las pestañas cerradas, una por línea (GLOBAL sobrevive a las recargas del config)
local function close_tab(window, pane)
	local cwd = pane:get_current_working_dir()
	if cwd then
		local path = (cwd.file_path or tostring(cwd)):gsub("^/(%a:)", "%1")
		wezterm.GLOBAL.closed_tabs = (wezterm.GLOBAL.closed_tabs or "") .. path .. "\n"
	end
	window:perform_action(act.CloseCurrentTab({ confirm = true }), pane)
end

local function reopen_tab(window, pane)
	local closed = wezterm.GLOBAL.closed_tabs or ""
	local rest, last = closed:match("^(.-)([^\n]+)\n$")
	if not last then
		return
	end
	wezterm.GLOBAL.closed_tabs = rest
	window:perform_action(act.SpawnCommandInNewTab({ cwd = last }), pane)
end

-- keymaps
config.keys = {
	browser_key("t", "CTRL", function(window, pane)
		window:perform_action(act.SpawnTab("CurrentPaneDomain"), pane)
	end),
	browser_key("w", "CTRL", close_tab),
	{ key = "T", mods = "CTRL|SHIFT", action = wezterm.action_callback(reopen_tab) },
	{
		key = "E",
		mods = "CTRL|SHIFT|ALT",
		action = wezterm.action.EmitEvent("toggle-colorscheme"),
	},
	{
		key = "h",
		mods = "CTRL|SHIFT|ALT",
		action = wezterm.action.SplitPane({
			direction = "Right",
			size = { Percent = 50 },
		}),
	},
	{
		key = "v",
		mods = "CTRL|SHIFT|ALT",
		action = wezterm.action.SplitPane({
			direction = "Down",
			size = { Percent = 50 },
		}),
	},
	{
		key = "U",
		mods = "CTRL|SHIFT",
		action = act.AdjustPaneSize({ "Left", 5 }),
	},
	{
		key = "I",
		mods = "CTRL|SHIFT",
		action = act.AdjustPaneSize({ "Down", 5 }),
	},
	{
		key = "O",
		mods = "CTRL|SHIFT",
		action = act.AdjustPaneSize({ "Up", 5 }),
	},
	{
		key = "P",
		mods = "CTRL|SHIFT",
		action = act.AdjustPaneSize({ "Right", 5 }),
	},
	{ key = "9", mods = "CTRL", action = act.PaneSelect },
	{ key = "L", mods = "CTRL", action = act.ShowDebugOverlay },
	{
		key = "O",
		mods = "CTRL|ALT",
		-- toggling opacity
		action = wezterm.action_callback(function(window, _)
			local overrides = window:get_config_overrides() or {}
			if overrides.window_background_opacity == 1.0 then
				overrides.window_background_opacity = 0.9
			else
				overrides.window_background_opacity = 1.0
			end
			window:set_config_overrides(overrides)
		end),
	},
}

-- For example, changing the color scheme:
-- Srcery (https://srcery.sh)
config.color_schemes = {
	["Athanor"] = {
		background = "#1C1B19",
		foreground = "#FCE8C3",
		cursor_bg = "#FBB829",
		cursor_border = "#FBB829",
		cursor_fg = "#1C1B19",
		selection_bg = "#918175",
		selection_fg = "#1C1B19",
		ansi = { "#1C1B19", "#EF2F27", "#519F50", "#FBB829", "#2C78BF", "#E02C6D", "#0AAEB3", "#BAA67F" },
		brights = { "#918175", "#F75341", "#98BC37", "#FED06E", "#68A8E4", "#FF5C8F", "#2BE4D0", "#FCE8C3" },
	},
}
config.color_scheme = "Athanor"
config.colors = {
	tab_bar = {
		background = "#1C1B19",
		-- background = "rgba(0, 0, 0, 0%)",
		active_tab = {
			bg_color = "#1C1B19",
			fg_color = "#FBB829",
			intensity = "Normal",
			underline = "None",
			italic = false,
			strikethrough = false,
		},
		inactive_tab_edge = "#121110",
		inactive_tab = {
			bg_color = "#121110",
			fg_color = "#918175",
			intensity = "Normal",
			underline = "None",
			italic = false,
			strikethrough = false,
		},

		new_tab = {
			-- bg_color = "rgba(59, 34, 76, 50%)",
			bg_color = "#121110",
			fg_color = "#BAA67F",
		},
	},
}

config.window_frame = {
	-- El alto de la barra sale del tamaño de esta fuente
	font = wezterm.font_with_fallback({ "PxPlus IBM VGA 8x16", "Hack Nerd Font Mono" }),
	font_size = 16.0,
	-- Un tono más oscuro que la terminal; la pestaña activa toma el color del fondo
	active_titlebar_bg = "#121110",
	inactive_titlebar_bg = "#121110",
	-- active_titlebar_bg = "#181616",
}

-- config.window_decorations = "INTEGRATED_BUTTONS | RESIZE"
-- Sin barra de título; minimizar, maximizar y cerrar van dentro de la barra de pestañas
config.window_decorations = "INTEGRATED_BUTTONS | RESIZE"
config.integrated_title_button_color = "#BAA67F"
-- Splash al abrir: grabado al azar + reloj + hora planetaria (se saltea si la ventana es chica)
-- Lo lanza el perfil de pwsh ($PROFILE) cuando TERM_PROGRAM es WezTerm, junto con oh-my-posh.
config.default_prog = { "pwsh.exe", "-NoLogo" }
-- config.default_prog = { "powershell.exe", "-NoLogo" }
config.initial_cols = 128
config.initial_rows = 46
-- config.window_background_image = "C:/dev/misc/berk.png"
-- config.window_background_image_hsb = {
-- 	brightness = 0.1,
-- }

-- wezterm.on("gui-startup", function(cmd)
-- 	local args = {}
-- 	if cmd then
-- 		args = cmd.args
-- 	end
--
-- 	local tab, pane, window = mux.spawn_window(cmd or {})
-- 	-- window:gui_window():maximize()
-- 	-- window:gui_window():set_position(0, 0)
-- end)

-- Arrastrar la ventana desde cualquier parte con Ctrl+Shift+clic izquierdo
config.mouse_bindings = {
	{
		event = { Drag = { streak = 1, button = "Left" } },
		mods = "CTRL|SHIFT",
		action = act.StartWindowDrag,
	},
}

-- and finally, return the configuration to wezterm
return config