local N = _G.NetworkSessionDebug or {}
_G.NetworkSessionDebug = N

local NSD_MOD_PATH = ModPath

N._settings = N._settings or {
	enabled = true,
	show_lobby_line = true,
	show_ingame_card = true,
	hud_x = 0.96,
	hud_y = 0.18,
	hud_scale = 1.0,
	hud_alpha = 1.0,
	hud_anchor = "top_right",
	hud_edit_mode = false,
	verbose = false,
	sample_interval = 0.25,
	ping_warn = 160,
	ping_bad = 240,
	jitter_warn = 25,
	jitter_bad = 45,
	queue_warn = 60,
	queue_bad = 120
}

local function _log_line(msg)
	local line = "[NetworkSessionDebug] " .. tostring(msg)
	if _G.log then
		log(line)
	elseif _G.BLT and BLT.Log then
		BLT:Log(line)
	end
end

local function _bool_from_item(item)
	return item and item:value() == "on"
end

local function _num_from_item(item)
	local v = item and item:value()
	return type(v) == "number" and v or tonumber(v)
end

local function _str_from_item(item)
	local v = item and item:value()
	if v == nil then
		return nil
	end
	return tostring(v)
end

function N:_settings_path()
	local base = _G.SavePath or ""
	return base .. "network_session_debug.json"
end

function N:load_settings()
	local path = self:_settings_path()
	local f = io.open(path, "r")
	if not f then
		return
	end
	local raw = f:read("*all")
	f:close()
	local ok, data = pcall(json.decode, raw)
	if ok and type(data) == "table" then
		for k, v in pairs(data) do
			if self._settings[k] ~= nil then
				self._settings[k] = v
			end
		end
	end
end

function N:save_settings()
	local path = self:_settings_path()
	local raw = json.encode(self._settings)
	local f = io.open(path, "w+")
	if not f then
		return
	end
	f:write(raw)
	f:close()
end

function N:apply_settings()
	self.state = self.state or {}
	self.state.enabled = not not self._settings.enabled
	self.state.mode = self._settings.verbose and "verbose" or "compact"
	self._peers = self._peers or {}
	self._peers.sample_interval = tonumber(self._settings.sample_interval) or 0.25
	self._cfg = self._cfg or {}
	self._cfg.ping_warn = tonumber(self._settings.ping_warn) or 160
	self._cfg.ping_bad = tonumber(self._settings.ping_bad) or 240
	self._cfg.jitter_warn = tonumber(self._settings.jitter_warn) or 25
	self._cfg.jitter_bad = tonumber(self._settings.jitter_bad) or 45
	self._cfg.queue_warn = tonumber(self._settings.queue_warn) or 60
	self._cfg.queue_bad = tonumber(self._settings.queue_bad) or 120
	if type(self._sanitize_hud_settings) == "function" then
		self:_sanitize_hud_settings()
	end
end

Hooks:Add("MenuManagerInitialize", "NSD.Menu.Init", function(menu_manager)
	N:load_settings()
	N:apply_settings()

	MenuCallbackHandler.nsd_toggle_enabled = function(this, item)
		N._settings.enabled = _bool_from_item(item)
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_toggle_lobby_line = function(this, item)
		N._settings.show_lobby_line = _bool_from_item(item)
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_toggle_ingame_card = function(this, item)
		N._settings.show_ingame_card = _bool_from_item(item)
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_set_hud_x = function(this, item)
		N._settings.hud_x = _num_from_item(item) or N._settings.hud_x
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_set_hud_y = function(this, item)
		N._settings.hud_y = _num_from_item(item) or N._settings.hud_y
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_set_hud_scale = function(this, item)
		N._settings.hud_scale = _num_from_item(item) or N._settings.hud_scale
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_set_hud_alpha = function(this, item)
		N._settings.hud_alpha = _num_from_item(item) or N._settings.hud_alpha
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_set_hud_anchor = function(this, item)
		N._settings.hud_anchor = _str_from_item(item) or N._settings.hud_anchor
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_toggle_hud_edit_mode = function(this, item)
		if type(N.set_hud_edit_mode) == "function" then
			N:set_hud_edit_mode(_bool_from_item(item), true)
		else
			N._settings.hud_edit_mode = _bool_from_item(item)
		end
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_toggle_verbose = function(this, item)
		N._settings.verbose = _bool_from_item(item)
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_set_sample_interval = function(this, item)
		N._settings.sample_interval = _num_from_item(item) or N._settings.sample_interval
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_set_ping_warn = function(this, item)
		N._settings.ping_warn = _num_from_item(item) or N._settings.ping_warn
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_set_ping_bad = function(this, item)
		N._settings.ping_bad = _num_from_item(item) or N._settings.ping_bad
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_set_jitter_warn = function(this, item)
		N._settings.jitter_warn = _num_from_item(item) or N._settings.jitter_warn
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_set_jitter_bad = function(this, item)
		N._settings.jitter_bad = _num_from_item(item) or N._settings.jitter_bad
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_set_queue_warn = function(this, item)
		N._settings.queue_warn = _num_from_item(item) or N._settings.queue_warn
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_set_queue_bad = function(this, item)
		N._settings.queue_bad = _num_from_item(item) or N._settings.queue_bad
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_reset_hud_layout = function(this)
		if type(N.reset_hud_layout) == "function" then
			N:reset_hud_layout(true)
		else
			N._settings.hud_x = 0.96
			N._settings.hud_y = 0.18
			N._settings.hud_scale = 1.0
			N._settings.hud_alpha = 1.0
			N._settings.hud_anchor = "top_right"
			N._settings.hud_edit_mode = false
		end
		N:apply_settings()
	end
	MenuCallbackHandler.nsd_save = function(this)
		N:save_settings()
	end

	local p1 = NSD_MOD_PATH .. "menu/options.json"
	local p2 = NSD_MOD_PATH .. "menu/options_blt_settings.json"
	_log_line("menu init | ModPath=" .. tostring(NSD_MOD_PATH))
	_log_line("menu json | " .. tostring(p1))
	_log_line("menu json | " .. tostring(p2))
	local ok1, err1 = pcall(function()
		MenuHelper:LoadFromJsonFile(p1, N, N._settings)
	end)
	if not ok1 then
		_log_line("menu inject failed (blt_options): " .. tostring(err1))
	else
		_log_line("menu injected (blt_options)")
	end
	local ok2, err2 = pcall(function()
		MenuHelper:LoadFromJsonFile(p2, N, N._settings)
	end)
	if not ok2 then
		_log_line("menu inject failed (blt_settings): " .. tostring(err2))
	else
		_log_line("menu injected (blt_settings)")
	end
end)