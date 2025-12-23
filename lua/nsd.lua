if _G.NetworkSessionDebug and _G.NetworkSessionDebug.__alive then
	return
end

local N = _G.NetworkSessionDebug or {}
_G.NetworkSessionDebug = N

N.__alive = true
N.version = "0.2.0"

N.state = N.state or {
	enabled = true,
	mode = "compact"
}

N._hooks = N._hooks or {
	session = false
}

N._ui = N._ui or {
	ready = false,
	last_try_t = 0,
	panel = nil,
	card = nil,
	shadow = nil,
	bg = nil,
	header = nil,
	accent = nil,
	border = nil,
	title = nil,
	lines = nil,
	last_w = 0,
	last_h = 0,
	last_scale = 0
}

N._hud = N._hud or {
	edit = { next_t = 0, last_save_t = 0 }
}

N._perf = N._perf or { acc = 0, frames = 0, fps = 0 }

N._events = N._events or {
	buf = {},
	head = 1,
	size = 0,
	cap = 24,
	last_sig = nil,
	last_t = 0
}

N._peers = N._peers or {
	meta = {},
	samples = {},
	last_sample_t = 0,
	sample_interval = 0.25
}

N._cfg = N._cfg or {
	max_peers_compact = 5,
	max_events_verbose = 8,
	max_rows_verbose = 16,
	ping_warn = 160,
	ping_bad = 240,
	jitter_warn = 25,
	jitter_bad = 45,
	queue_warn = 60,
	queue_bad = 120
}

local function _alive(o)
	return o and alive and alive(o)
end

local function _now()
	local tm = _G.TimerManager and TimerManager:wall()
	if tm and tm.time then
		return tm:time()
	end
	if _G.Application and Application.time then
		return Application:time()
	end
	return os.clock()
end

local function _clamp(x, a, b)
	if x == nil then
		return a
	end
	if x < a then
		return a
	end
	if x > b then
		return b
	end
	return x
end

local function _as_num(v)
	return type(v) == "number" and v or tonumber(v)
end

function N:_sanitize_hud_settings()
	self._settings = self._settings or {}
	local s = self._settings
	s.hud_x = _clamp(_as_num(s.hud_x) or 0.96, 0, 1)
	s.hud_y = _clamp(_as_num(s.hud_y) or 0.18, 0, 1)
	s.hud_scale = _clamp(_as_num(s.hud_scale) or 1.0, 0.5, 2.0)
	s.hud_alpha = _clamp(_as_num(s.hud_alpha) or 1.0, 0.2, 1.0)
	local a = tostring(s.hud_anchor or "top_right")
	if a ~= "top_left" and a ~= "top_right" and a ~= "bottom_left" and a ~= "bottom_right" and a ~= "center" then
		a = "top_right"
	end
	s.hud_anchor = a
	s.hud_edit_mode = not not s.hud_edit_mode
end

function N:set_hud_edit_mode(on, no_save)
	self._settings = self._settings or {}
	local v = not not on
	if self._settings.hud_edit_mode == v then
		return
	end
	self._settings.hud_edit_mode = v
	if not v and not no_save and type(self.save_settings) == "function" then
		self:save_settings()
	end
end

function N:toggle_hud_edit_mode()
	self._settings = self._settings or {}
	local on = not self._settings.hud_edit_mode
	self:set_hud_edit_mode(on, false)
	if type(self._push_event) == "function" then
		self:_push_event("hud", "HUD edit mode: " .. (on and "ON" or "OFF"), on and "warn" or "info")
	end
end

function N:reset_hud_layout(no_save)
	self._settings = self._settings or {}
	self._settings.hud_x = 0.96
	self._settings.hud_y = 0.18
	self._settings.hud_scale = 1.0
	self._settings.hud_alpha = 1.0
	self._settings.hud_anchor = "top_right"
	self._settings.hud_edit_mode = false
	self:_sanitize_hud_settings()
	if not no_save and type(self.save_settings) == "function" then
		self:save_settings()
	end
end

function N:_hud_metrics(scale)
	local s = _clamp(_as_num(scale) or 1.0, 0.5, 2.0)
	local pad = math.max(6, math.floor(10 * s + 0.5))
	local header_h = math.max(20, math.floor(34 * s + 0.5))
	local accent_h = math.max(1, math.floor(2 * s + 0.5))
	local title_y = math.max(2, math.floor(6 * s + 0.5))
	local title_h = math.max(18, math.floor(24 * s + 0.5))
	local y0 = header_h + accent_h + math.max(6, math.floor(8 * s + 0.5))
	local line_h = math.max(12, math.floor(16 * s + 0.5))
	local shadow_off = math.max(1, math.floor(2 * s + 0.5))
	return s, pad, header_h, accent_h, title_y, title_h, y0, line_h, shadow_off
end

function N:_hud_layout_params()
	self:_sanitize_hud_settings()
	local s = self._settings or {}
	return s.hud_x, s.hud_y, s.hud_scale, s.hud_alpha, s.hud_anchor, s.hud_edit_mode
end

function N:_apply_hud_layout()
	local ui = self._ui
	if not (ui.ready and _alive(ui.panel) and _alive(ui.card)) then
		return
	end
	local x, y, scale, alpha, anchor, edit = self:_hud_layout_params()
	ui.card:set_alpha(alpha)
	local _, _, _, _, _, _, _, _, shadow_off = self:_hud_metrics(scale)
	if _alive(ui.shadow) then
		ui.shadow:set_x(shadow_off)
		ui.shadow:set_y(shadow_off)
	end
	local pw = ui.panel:w()
	local ph = ui.panel:h()
	local px = x * pw
	local py = y * ph
	local c = ui.card
	if anchor == "top_left" then
		c:set_x(px)
		c:set_y(py)
	elseif anchor == "top_right" then
		c:set_right(px)
		c:set_y(py)
	elseif anchor == "bottom_left" then
		c:set_x(px)
		c:set_bottom(py)
	elseif anchor == "bottom_right" then
		c:set_right(px)
		c:set_bottom(py)
	else
		c:set_center_x(px)
		c:set_center_y(py)
	end
	local cx = _clamp(c:x(), 0, math.max(0, pw - c:w()))
	local cy = _clamp(c:y(), 0, math.max(0, ph - c:h()))
	c:set_x(cx)
	c:set_y(cy)
	if _alive(ui.accent) then
		local theme = self:_theme()
		ui.accent:set_color(edit and theme.warn or theme.accent)
	end
end

function N:_hud_edit_update(now)
	local _, _, scale, _, _, edit = self:_hud_layout_params()
	if not edit then
		return
	end
	local kb = nil
	if Input and type(Input.keyboard) == "function" then
		local ok, v = pcall(function()
			return Input:keyboard()
		end)
		if ok then
			kb = v
		end
	end
	if not kb then
		return
	end
	local t = now or _now()
	local ed = self._hud and self._hud.edit or nil
	if not ed then
		self._hud = self._hud or {}
		self._hud.edit = { next_t = 0, last_save_t = 0 }
		ed = self._hud.edit
	end
	if t < (ed.next_t or 0) then
		return
	end

	local shift = kb:down(Idstring("left shift")) or kb:down(Idstring("right shift"))
	local ctrl = kb:down(Idstring("left ctrl")) or kb:down(Idstring("right ctrl"))

	local dx = 0
	local dy = 0
	local ds = 0
	local da = 0

	if ctrl then
		local sstep = shift and 0.05 or 0.01
		local astep = shift and 0.10 or 0.02
		if kb:down(Idstring("up")) then ds = ds + sstep end
		if kb:down(Idstring("down")) then ds = ds - sstep end
		if kb:down(Idstring("right")) then da = da + astep end
		if kb:down(Idstring("left")) then da = da - astep end
	else
		local ui = self._ui
		local pw = (ui and ui.ready and _alive(ui.panel) and ui.panel:w()) or 1920
		local ph = (ui and ui.ready and _alive(ui.panel) and ui.panel:h()) or 1080
		local base_px = shift and 18 or 6
		local pstep_x = base_px / math.max(1, pw)
		local pstep_y = base_px / math.max(1, ph)
		if kb:down(Idstring("left")) then dx = dx - pstep_x end
		if kb:down(Idstring("right")) then dx = dx + pstep_x end
		if kb:down(Idstring("up")) then dy = dy - pstep_y end
		if kb:down(Idstring("down")) then dy = dy + pstep_y end
	end

	if dx == 0 and dy == 0 and ds == 0 and da == 0 then
		return
	end

	self._settings.hud_x = _clamp((_as_num(self._settings.hud_x) or 0.96) + dx, 0, 1)
	self._settings.hud_y = _clamp((_as_num(self._settings.hud_y) or 0.18) + dy, 0, 1)
	self._settings.hud_scale = _clamp((_as_num(self._settings.hud_scale) or 1.0) + ds, 0.5, 2.0)
	self._settings.hud_alpha = _clamp((_as_num(self._settings.hud_alpha) or 1.0) + da, 0.2, 1.0)
	ed.next_t = t + (shift and 0.02 or 0.03)
	if t - (ed.last_save_t or 0) > 0.75 and type(self.save_settings) == "function" then
		self:save_settings()
		ed.last_save_t = t
	end
	self:_apply_hud_layout()
	self._ui.last_scale = 0
end

local function _lerp(a, b, t)
	return a + (b - a) * t
end

local function _color_rgba(a, r, g, b)
	return Color(a, r / 255, g / 255, b / 255)
end

local function _fmt_ms(v)
	if type(v) ~= "number" then
		return "n/a"
	end
	return tostring(math.floor(v + 0.5)) .. "ms"
end

local function _fmt_int(v)
	if type(v) ~= "number" then
		return "n/a"
	end
	return tostring(math.floor(v + 0.5))
end

local function _fmt_pct(v)
	if type(v) ~= "number" then
		return "n/a"
	end
	return tostring(math.floor(v * 100 + 0.5)) .. "%"
end

function N:_log(msg)
	local line = "[NetworkSessionDebug] " .. tostring(msg)
	if _G.log then
		log(line)
	elseif _G.BLT and BLT.Log then
		BLT:Log(line)
	elseif _G.Application and Application.debug then
		Application:debug(line)
	end
end

if not N._boot_logged then
	N._boot_logged = true
	N:_log("loaded v" .. tostring(N.version) .. " | menusetup/gamesetup")
end

function N:_push_event(kind, text, severity)
	local t = _now()
	local sev = severity or "info"
	local msg = tostring(text or "")
	local sig = tostring(kind or "?") .. "|" .. msg .. "|" .. tostring(sev)
	if self._events.last_sig == sig and t - (self._events.last_t or 0) < 0.5 then
		return
	end
	self._events.last_sig = sig
	self._events.last_t = t
	local e = { t = t, kind = tostring(kind or "?"), sev = sev, text = msg }
	local buf = self._events.buf
	local idx = self._events.head
	buf[idx] = e
	self._events.head = (idx % self._events.cap) + 1
	self._events.size = math.min(self._events.size + 1, self._events.cap)
end

function N:_iter_events(max_count)
	local out = {}
	local n = math.min(self._events.size, max_count or self._events.size)
	local head = self._events.head
	for i = 1, n do
		local idx = head - i
		if idx <= 0 then
			idx = idx + self._events.cap
		end
		out[#out + 1] = self._events.buf[idx]
	end
	return out
end

function N:_update_fps(dt)
	local p = self._perf
	p.acc = p.acc + (dt or 0)
	p.frames = p.frames + 1
	if p.acc >= 0.5 then
		p.fps = math.floor(p.frames / p.acc + 0.5)
		p.acc = 0
		p.frames = 0
	end
end

function N:_theme()
	return {
		bg = _color_rgba(0.42, 0, 0, 0),
		shadow = _color_rgba(0.25, 0, 0, 0),
		border = _color_rgba(0.75, 0, 0, 0),
		header = _color_rgba(0.55, 12, 22, 40),
		accent = _color_rgba(1, 60, 160, 255),
		title = _color_rgba(1, 230, 240, 255),
		text = _color_rgba(1, 235, 235, 235),
		muted = _color_rgba(1, 170, 180, 195),
		warn = _color_rgba(1, 255, 190, 80),
		bad = _color_rgba(1, 255, 90, 90),
		good = _color_rgba(1, 120, 255, 170)
	}
end

function N:_ensure_ui(t)
	if not self.state.enabled or not (self._settings == nil or self._settings.show_ingame_card) then
		if self._ui.ready and _alive(self._ui.panel) then
			self._ui.panel:set_visible(false)
		end
		return false
	end

	local ui = self._ui
	if ui.ready and _alive(ui.panel) and _alive(ui.card) then
		ui.panel:set_visible(true)
		return true
	end

	local now = t or _now()
	if now - (ui.last_try_t or 0) < 0.5 then
		return false
	end
	ui.last_try_t = now

	if not (_G.managers and managers.hud and managers.hud.script and _G.PlayerBase) then
		return false
	end

	local hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2)
	if not hud or not hud.panel then
		return false
	end

	local root = hud.panel
	local existing = root:child("nsd_panel")
	if _alive(existing) then
		local card = existing:child("nsd_card")
		if not _alive(card) then
			root:remove(existing)
		else
			ui.panel = existing
			ui.card = card
			ui.shadow = card:child("nsd_shadow")
			ui.bg = card:child("nsd_bg")
			ui.header = card:child("nsd_header")
			ui.accent = card:child("nsd_accent")
			ui.title = card:child("nsd_title")
			ui.border = {
				t = card:child("nsd_border_t"),
				b = card:child("nsd_border_b"),
				l = card:child("nsd_border_l"),
				r = card:child("nsd_border_r")
			}
			ui.lines = ui.lines or {}
			ui.ready = _alive(ui.bg) and _alive(ui.header) and _alive(ui.title) and _alive(ui.accent)
			return ui.ready
		end
	end

	local panel = root:panel({
		name = "nsd_panel",
		layer = 9998,
		x = 0,
		y = 0,
		w = root:w(),
		h = root:h(),
		visible = true
	})

	local card = panel:panel({
		name = "nsd_card",
		layer = 9998,
		w = 520,
		h = 240,
		x = 0,
		y = 0,
		visible = true
	})

	local theme = self:_theme()

	card:rect({ name = "nsd_shadow", layer = -2, x = 2, y = 2, w = card:w(), h = card:h(), color = theme.shadow })
	card:rect({ name = "nsd_bg", layer = -1, x = 0, y = 0, w = card:w(), h = card:h(), color = theme.bg })

	card:rect({ name = "nsd_border_t", layer = 4, x = 0, y = 0, w = card:w(), h = 1, color = theme.border })
	card:rect({ name = "nsd_border_b", layer = 4, x = 0, y = card:h() - 1, w = card:w(), h = 1, color = theme.border })
	card:rect({ name = "nsd_border_l", layer = 4, x = 0, y = 0, w = 1, h = card:h(), color = theme.border })
	card:rect({ name = "nsd_border_r", layer = 4, x = card:w() - 1, y = 0, w = 1, h = card:h(), color = theme.border })

	card:rect({ name = "nsd_header", layer = 1, x = 0, y = 0, w = card:w(), h = 34, color = theme.header })
	card:rect({ name = "nsd_accent", layer = 2, x = 0, y = 34, w = card:w(), h = 2, color = theme.accent })

	card:text({
		name = "nsd_title",
		layer = 3,
		x = 10,
		y = 6,
		w = card:w() - 20,
		h = 24,
		text = "Network Session Debug",
		font = tweak_data and tweak_data.menu and tweak_data.menu.pd2_large_font or "fonts/font_large_mf",
		font_size = 18,
		color = theme.title,
		align = "left",
		vertical = "center"
	})

	ui.panel = panel
	ui.card = card
	ui.shadow = card:child("nsd_shadow")
	ui.bg = card:child("nsd_bg")
	ui.header = card:child("nsd_header")
	ui.accent = card:child("nsd_accent")
	ui.title = card:child("nsd_title")
	ui.border = {
		t = card:child("nsd_border_t"),
		b = card:child("nsd_border_b"),
		l = card:child("nsd_border_l"),
		r = card:child("nsd_border_r")
	}
	ui.lines = ui.lines or {}
	ui.ready = true

	return true
end

function N:_update_lobby_lines(session, t)
	if not (self.state.enabled and self._settings and self._settings.show_lobby_line) then
		return
	end
	if not (_G.managers and managers.hud and managers.hud._hud_mission_briefing) then
		return
	end
	local hb = managers.hud._hud_mission_briefing
	if not (hb and alive(hb._ready_slot_panel)) then
		return
	end
	local all = type(session.all_peers) == "function" and session:all_peers() or {}
	for peer_id = 1, tweak_data.max_players do
		local slot = hb._ready_slot_panel:child("slot_" .. tostring(peer_id))
		if alive(slot) then
			local line = slot:child("nsd_net")
			if alive(line) then
				local peer = all[peer_id]
				if peer then
					self:_update_peer_sample(session, peer_id, peer, t)
					local s = self._peers.samples[peer_id] or {}
					local ping = type(s.ema_ping) == "number" and s.ema_ping or s.ping_ms
					local jit = s.ema_jitter
					local qrel = s.queue_rel
					local qun = s.queue_unrel
					local flags = s.flags or "-"
					local sev = self:_severity_for(ping, jit, s.queue_total)
					local theme = self:_theme()
					local c = theme.muted
					if sev == "warn" then c = theme.warn end
					if sev == "bad" then c = theme.bad end
					line:set_color(c:with_alpha(0.75))
					if type(qrel) == "number" or type(qun) == "number" then
						line:set_text(string.format("ping %s  jit %s  q %s/%s  %s", _fmt_ms(ping), _fmt_ms(jit), _fmt_int(qrel), _fmt_int(qun), tostring(flags)))
					else
						line:set_text(string.format("ping %s  jit %s  q %s  %s", _fmt_ms(ping), _fmt_ms(jit), _fmt_int(s.queue_total), tostring(flags)))
					end
					line:set_visible(true)
				else
					line:set_text("")
					line:set_visible(false)
				end
			end
		end
	end
end

function N:_set_card_size(w, h, scale)
	local ui = self._ui
	if not (ui.ready and _alive(ui.card)) then
		return
	end
	scale = _as_num(scale) or (self._settings and _as_num(self._settings.hud_scale)) or 1.0
	local s, pad, header_h, accent_h, title_y, title_h, _, _, shadow_off = self:_hud_metrics(scale)
	w = math.floor(w + 0.5)
	h = math.floor(h + 0.5)
	if w == ui.last_w and h == ui.last_h and ui.last_scale == s then
		return
	end
	ui.last_w = w
	ui.last_h = h
	ui.last_scale = s
	ui.card:set_w(w)
	ui.card:set_h(h)
	if _alive(ui.shadow) then
		ui.shadow:set_x(shadow_off)
		ui.shadow:set_y(shadow_off)
		ui.shadow:set_w(w)
		ui.shadow:set_h(h)
	end
	if _alive(ui.bg) then
		ui.bg:set_w(w)
		ui.bg:set_h(h)
	end
	if ui.border then
		if _alive(ui.border.t) then ui.border.t:set_w(w) end
		if _alive(ui.border.b) then ui.border.b:set_w(w); ui.border.b:set_y(h - 1) end
		if _alive(ui.border.l) then ui.border.l:set_h(h) end
		if _alive(ui.border.r) then ui.border.r:set_x(w - 1); ui.border.r:set_h(h) end
	end
	if _alive(ui.header) then
		ui.header:set_w(w)
		ui.header:set_h(header_h)
	end
	if _alive(ui.accent) then
		ui.accent:set_w(w)
		ui.accent:set_y(header_h)
		ui.accent:set_h(accent_h)
	end
	if _alive(ui.title) then
		ui.title:set_x(pad)
		ui.title:set_y(title_y)
		ui.title:set_w(w - pad * 2)
		ui.title:set_h(title_h)
		ui.title:set_font_size(math.max(12, math.floor(18 * s + 0.5)))
	end
end

function N:_set_line(i, text, color, size)
	local ui = self._ui
	if not (ui.ready and _alive(ui.card)) then
		return
	end
	ui.lines = ui.lines or {}
	local line = ui.lines[i]
	local _, _, scale = self:_hud_layout_params()
	local s, pad, header_h, accent_h, _, _, y0, line_h = self:_hud_metrics(scale)
	local max_w = ui.card:w() - pad * 2
	local theme = self:_theme()
	if not _alive(line) then
		line = ui.card:text({
			name = "nsd_line_" .. tostring(i),
			layer = 3,
			x = pad,
			y = y0 + (i - 1) * line_h,
			w = max_w,
			h = line_h,
			text = "",
			font = tweak_data and tweak_data.menu and tweak_data.menu.pd2_small_font or "fonts/font_small_mf",
			font_size = math.max(10, math.floor((size or 13) * s + 0.5)),
			color = color or theme.text,
			align = "left",
			vertical = "center"
		})
		ui.lines[i] = line
	end
	line:set_text(text or "")
	line:set_color(color or theme.text)
	line:set_font_size(math.max(10, math.floor((size or 13) * s + 0.5)))
	line:set_y(y0 + (i - 1) * line_h)
	line:set_w(max_w)
	line:set_visible(true)
end

function N:_hide_lines(from_idx)
	local ui = self._ui
	if not (ui.ready and ui.lines) then
		return
	end
	for i = from_idx, #ui.lines do
		local o = ui.lines[i]
		if _alive(o) then
			o:set_visible(false)
		end
	end
end

function N:_extract_ping_ms(qos)
	if type(qos) ~= "table" then
		return nil
	end
	local v = qos.ping
	if type(v) == "number" then
		return v
	end
	local best = nil
	for k, val in pairs(qos) do
		if type(val) == "number" then
			local key = tostring(k):lower()
			if key:find("ping", 1, true) or key:find("rtt", 1, true) or key:find("lat", 1, true) then
				best = val
				break
			end
		end
	end
	return best
end

function N:_extract_qos_table(peer)
	if not peer or type(peer.qos) ~= "function" then
		return nil
	end
	local ok, qos = pcall(peer.qos, peer)
	if not ok then
		return nil
	end
	return qos
end

function N:_extract_send_queue(peer)
	if not (_G.Network and type(Network.get_connection_send_status) == "function") then
		return nil
	end
	if not peer or type(peer.rpc) ~= "function" then
		return nil
	end
	local rpc = peer:rpc()
	if not rpc then
		return nil
	end
	local ok, st = pcall(Network.get_connection_send_status, Network, rpc)
	if not ok or type(st) ~= "table" then
		return nil
	end
	local total = 0
	for _, amount in pairs(st) do
		if type(amount) == "number" then
			total = total + amount
		end
	end
	return {
		total = total,
		reliable = type(st.reliable) == "number" and st.reliable or nil,
		unreliable = type(st.unreliable) == "number" and st.unreliable or nil
	}
end

function N:_get_session()
	if not (_G.managers and managers.network and managers.network.session) then
		return nil
	end
	local ok, s = pcall(managers.network.session, managers.network)
	if ok then
		return s
	end
	return nil
end

function N:_peer_label(peer, peer_id)
	if not peer then
		return string.format("#%s ?", tostring(peer_id or "?"))
	end
	local id = (type(peer.id) == "function" and peer:id()) or peer_id or "?"
	local name = (type(peer.name) == "function" and peer:name()) or "?"
	return string.format("#%s %s", tostring(id), tostring(name))
end

function N:_peer_state_flags(peer)
	local flags = {}
	if not peer then
		return "-"
	end
	if type(peer.is_host) == "function" and peer:is_host() then
		flags[#flags + 1] = "H"
	end
	if type(peer.loading) == "function" and peer:loading() then
		flags[#flags + 1] = "L"
	end
	if type(peer.synched) == "function" and peer:synched() then
		flags[#flags + 1] = "S"
	end
	if type(peer.ip_verified) == "function" and peer:ip_verified() then
		flags[#flags + 1] = "V"
	end
	if type(peer.is_modded) == "function" and peer:is_modded() then
		flags[#flags + 1] = "M"
	end
	if type(peer.is_vr) == "function" and peer:is_vr() then
		flags[#flags + 1] = "VR"
	end
	local st = type(peer.streaming_status) == "function" and peer:streaming_status() or nil
	if type(st) == "number" and st > 0 and st < 100 then
		flags[#flags + 1] = "D" .. tostring(math.floor(st + 0.5))
	end
	if #flags == 0 then
		return "-"
	end
	return table.concat(flags, "")
end

function N:_lag_score(ping_ms, jitter_ms, q_total)
	local cfg = self._cfg
	local p = type(ping_ms) == "number" and ping_ms or 0
	local j = type(jitter_ms) == "number" and jitter_ms or 0
	local q = type(q_total) == "number" and q_total or 0
	local pn = _clamp(p / cfg.ping_bad, 0, 2)
	local jn = _clamp(j / cfg.jitter_bad, 0, 2)
	local qn = _clamp(q / cfg.queue_bad, 0, 2)
	return pn * 1.1 + jn * 0.9 + qn * 0.7
end

function N:_severity_for(ping_ms, jitter_ms, q_total)
	local cfg = self._cfg
	local p = type(ping_ms) == "number" and ping_ms or 0
	local j = type(jitter_ms) == "number" and jitter_ms or 0
	local q = type(q_total) == "number" and q_total or 0
	if p >= cfg.ping_bad or j >= cfg.jitter_bad or q >= cfg.queue_bad then
		return "bad"
	end
	if p >= cfg.ping_warn or j >= cfg.jitter_warn or q >= cfg.queue_warn then
		return "warn"
	end
	return "ok"
end

function N:_update_peer_sample(session, peer_id, peer, t)
	if not peer_id then
		return
	end
	local meta = self._peers.meta[peer_id] or {}
	self._peers.meta[peer_id] = meta

	if meta.first_seen_t == nil then
		meta.first_seen_t = t
	end
	meta.last_seen_t = t

	local qos = self:_extract_qos_table(peer)
	local ping_ms = self:_extract_ping_ms(qos)

	local s = self._peers.samples[peer_id] or {}
	self._peers.samples[peer_id] = s

	local last_ping = s.ping_ms
	s.ping_ms = ping_ms

	if type(ping_ms) == "number" then
		local a = 0.18
		if type(s.ema_ping) ~= "number" then
			s.ema_ping = ping_ms
		else
			s.ema_ping = s.ema_ping + (ping_ms - s.ema_ping) * a
		end
		if type(last_ping) == "number" then
			local d = math.abs(ping_ms - last_ping)
			if type(s.ema_jitter) ~= "number" then
				s.ema_jitter = d
			else
				s.ema_jitter = s.ema_jitter + (d - s.ema_jitter) * 0.22
			end
		end
	end

	local q = self:_extract_send_queue(peer)
	s.queue_total = q and q.total or nil
	s.queue_rel = q and q.reliable or nil
	s.queue_unrel = q and q.unreliable or nil

	s.flags = self:_peer_state_flags(peer)
	s.name = type(peer.name) == "function" and peer:name() or s.name
	s.user_id = type(peer.user_id) == "function" and peer:user_id() or s.user_id
	s.account_type = type(peer.account_type_str) == "function" and peer:account_type_str() or s.account_type
	s.is_host = type(peer.is_host) == "function" and peer:is_host() or false
	s.stream = type(peer.streaming_status) == "function" and peer:streaming_status() or nil
	s.loading = type(peer.loading) == "function" and peer:loading() or nil
	s.synched = type(peer.synched) == "function" and peer:synched() or nil
	s.ip_verified = type(peer.ip_verified) == "function" and peer:ip_verified() or nil
end

function N:_collect(session, t)
	local peers = {}
	if not session or type(session.all_peers) ~= "function" then
		return peers
	end

	local ok, all = pcall(session.all_peers, session)
	if not ok or type(all) ~= "table" then
		return peers
	end

	for peer_id, peer in pairs(all) do
		peers[#peers + 1] = { id = peer_id, peer = peer }
	end

	return peers
end

function N:_sample(session, t)
	local items = self:_collect(session, t)
	for _, it in ipairs(items) do
		self:_update_peer_sample(session, it.id, it.peer, t)
	end
	self._peers.last_sample_t = t
end

function N:_rows(session, t)
	local theme = self:_theme()
	local rows = {}

	local session_ok = session and true or false
	local is_host = _G.Network and Network.is_server and Network:is_server() or false
	local mode = self.state.mode
	local peers_count = 0
	if session_ok and type(session.amount_of_players) == "function" then
		local ok, cnt = pcall(session.amount_of_players, session)
		if ok and type(cnt) == "number" then
			peers_count = cnt
		end
	end

	local header = string.format("Network Session Debug v%s | %s | peers %s | fps %s | %s", self.version, is_host and "host" or "client", tostring(peers_count), tostring(self._perf.fps or 0), mode)
	rows[#rows + 1] = { text = header, color = theme.title, size = 14 }

	if self._settings and self._settings.hud_edit_mode then
		local x, y, sc, a, anchor = self:_hud_layout_params()
		rows[#rows + 1] = { text = string.format("HUD EDIT  x=%.3f  y=%.3f  scale=%.2f  alpha=%.2f  anchor=%s", x, y, sc, a, tostring(anchor)), color = theme.warn, size = 12 }
		rows[#rows + 1] = { text = "Arrows move | Ctrl+Arrows scale/alpha | Shift fast | Toggle via BLT keybinds or options", color = theme.muted, size = 12 }
	end

	if not session_ok then
		rows[#rows + 1] = { text = "WAITING FOR NETWORK SESSION", color = theme.muted, size = 13 }
		return rows
	end

	local local_peer_id = nil
	if type(session.local_peer) == "function" then
		local ok, lp = pcall(session.local_peer, session)
		if ok and lp and type(lp.id) == "function" then
			local_peer_id = lp:id()
		end
	end

	local list = {}
	for peer_id, s in pairs(self._peers.samples) do
		local meta = self._peers.meta[peer_id] or {}
		local ping = type(s.ema_ping) == "number" and s.ema_ping or s.ping_ms
		local jitter = s.ema_jitter
		local q_total = s.queue_total
		local score = self:_lag_score(ping, jitter, q_total)
		local sev = self:_severity_for(ping, jitter, q_total)
		list[#list + 1] = {
			id = peer_id,
			name = s.name or "?",
			flags = s.flags or "-",
			ping = ping,
			jitter = jitter,
			q_total = q_total,
			q_rel = s.queue_rel,
			q_unrel = s.queue_unrel,
			user_id = s.user_id,
			account_type = s.account_type,
			first_seen_t = meta.first_seen_t,
			last_seen_t = meta.last_seen_t,
			stream = s.stream,
			sev = sev,
			score = score
		}
	end

	table.sort(list, function(a, b)
		if a.score == b.score then
			return tostring(a.name) < tostring(b.name)
		end
		return a.score > b.score
	end)

	local max_rows = mode == "compact" and self._cfg.max_peers_compact or self._cfg.max_rows_verbose
	local shown = 0
	for _, it in ipairs(list) do
		if shown >= max_rows then
			break
		end
		local clr = theme.text
		if it.sev == "warn" then
			clr = theme.warn
		elseif it.sev == "bad" then
			clr = theme.bad
		end
		if local_peer_id and it.id == local_peer_id then
			clr = theme.good
		end
		local age_s = (type(it.first_seen_t) == "number" and t - it.first_seen_t) or 0
		local age_txt = age_s > 0 and tostring(math.floor(age_s + 0.5)) .. "s" or "0s"
		local stream_txt = type(it.stream) == "number" and tostring(math.floor(it.stream + 0.5)) .. "%" or "-"
		local q_txt = (type(it.q_rel) == "number" or type(it.q_unrel) == "number") and (string.format("%s/%s", _fmt_int(it.q_rel), _fmt_int(it.q_unrel))) or _fmt_int(it.q_total)
		local line = string.format("%-2s %-18s %-6s ping %-6s jit %-6s q %-7s dropin %-4s age %-5s", tostring(it.id), tostring(it.name):sub(1, 18), tostring(it.flags), _fmt_ms(it.ping), _fmt_ms(it.jitter), tostring(q_txt), tostring(stream_txt), age_txt)
		rows[#rows + 1] = { text = line, color = clr, size = 13 }
		shown = shown + 1
	end

	if mode ~= "compact" then
		rows[#rows + 1] = { text = "EVENTS", color = theme.muted, size = 12 }
		local evs = self:_iter_events(self._cfg.max_events_verbose)
		for i = #evs, 1, -1 do
			local e = evs[i]
			local dt = t - (e.t or t)
			local ts = string.format("%5.1fs", dt)
			local c = theme.text
			if e.sev == "warn" then c = theme.warn end
			if e.sev == "bad" then c = theme.bad end
			rows[#rows + 1] = { text = string.format("%s %s", ts, tostring(e.text)), color = c, size = 12 }
		end
	end

	return rows
end

function N:_render(session, t)
	if not self:_ensure_ui(t) then
		return
	end

	local rows = self:_rows(session, t)
	local _, _, scale = self:_hud_layout_params()
	local s, _, _, _, _, _, y0, line_h = self:_hud_metrics(scale)
	local max_w = math.floor(520 * s + 0.5)
	local bottom_pad = math.max(8, math.floor(10 * s + 0.5))
	local card_h = y0 + math.max(#rows, 1) * line_h + bottom_pad
	card_h = _clamp(card_h, math.floor(90 * s + 0.5), math.floor(420 * s + 0.5))
	self:_set_card_size(max_w, card_h, s)

	local n = #rows
	for i = 1, n do
		local r = rows[i]
		self:_set_line(i, r.text, r.color, r.size)
	end
	self:_hide_lines(n + 1)
	self:_apply_hud_layout()
end

function N:update(t, dt)
	if not (_G.managers and managers.network) then
		return
	end
	self:_update_fps(dt)

	local now = t or _now()
	local session = self:_get_session()

	if self._settings and self._settings.hud_edit_mode then
		self:_hud_edit_update(now)
	end

	if session and now - (self._peers.last_sample_t or 0) >= (self._peers.sample_interval or 0.25) then
		self:_sample(session, now)
	end

	if session and self._settings and self._settings.show_lobby_line then
		self:_update_lobby_lines(session, now)
	end
	self:_render(session, now)
end

function N:toggle()
	self.state.enabled = not self.state.enabled
	if self._ui.ready and _alive(self._ui.panel) then
		self._ui.panel:set_visible(self.state.enabled)
	end
end

function N:toggle_mode()
	self.state.mode = self.state.mode == "compact" and "verbose" or "compact"
	self:_push_event("mode", "Mode: " .. tostring(self.state.mode), "info")
end

function N:_dump_qos(qos)
	if type(qos) ~= "table" then
		return "qos=n/a"
	end
	local parts = {}
	for k, v in pairs(qos) do
		parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
	end
	table.sort(parts)
	return table.concat(parts, " ")
end

function N:dump()
	local session = self:_get_session()
	if not session then
		self:_log("dump: no session")
		return
	end
	local is_host = _G.Network and Network.is_server and Network:is_server() or false
	self:_log("dump begin | host=" .. tostring(is_host))
	local peers = type(session.all_peers) == "function" and session:all_peers() or {}
	local ids = {}
	for id, _ in pairs(peers) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local peer = peers[id]
		local label = self:_peer_label(peer, id)
		local flags = self:_peer_state_flags(peer)
		local qos = self:_extract_qos_table(peer)
		local ping = self:_extract_ping_ms(qos)
		local q = self:_extract_send_queue(peer)
		local qtxt = q and string.format("q_total=%s q_rel=%s q_unrel=%s", tostring(q.total), tostring(q.reliable), tostring(q.unreliable)) or "q=n/a"
		local acct = peer and type(peer.account_type_str) == "function" and peer:account_type_str() or "n/a"
		local uid = peer and type(peer.user_id) == "function" and peer:user_id() or "n/a"
		local ip = peer and type(peer.ip) == "function" and peer:ip() or "n/a"
		local stream = peer and type(peer.streaming_status) == "function" and peer:streaming_status() or nil
		self:_log(string.format("%s flags=%s acct=%s uid=%s ip=%s stream=%s ping=%s %s %s", label, tostring(flags), tostring(acct), tostring(uid), tostring(ip), tostring(stream), tostring(ping), qtxt, self:_dump_qos(qos)))
	end
	self:_log("dump end")
	self:_push_event("dump", "Dump written to log", "info")
end

function N:_peer_event_prefix(session)
	local is_host = _G.Network and Network.is_server and Network:is_server() or false
	local cnt = 0
	if session and type(session.amount_of_players) == "function" then
		local ok, v = pcall(session.amount_of_players, session)
		if ok and type(v) == "number" then
			cnt = v
		end
	end
	return string.format("[host=%s peers=%s] ", tostring(is_host), tostring(cnt))
end

function N:_on_peer_added(session, peer, peer_id, name)
	local id = peer_id or (peer and type(peer.id) == "function" and peer:id()) or nil
	local nm = (peer and type(peer.name) == "function" and peer:name()) or name or "?"
	if id then
		self._peers.meta[id] = self._peers.meta[id] or {}
		self._peers.meta[id].first_seen_t = self._peers.meta[id].first_seen_t or _now()
	end
	self:_push_event("join", self:_peer_event_prefix(session) .. "JOIN " .. tostring(id) .. " " .. tostring(nm), "info")
end

function N:_on_peer_removed(session, peer, peer_id, reason)
	local id = peer_id or (peer and type(peer.id) == "function" and peer:id()) or nil
	local nm = (peer and type(peer.name) == "function" and peer:name()) or "?"
	local r = tostring(reason or "?")
	self:_push_event("leave", self:_peer_event_prefix(session) .. "LEAVE " .. tostring(id) .. " " .. tostring(nm) .. " (" .. r .. ")", r == "lost" and "warn" or "info")
	if id then
		self._peers.meta[id] = self._peers.meta[id] or {}
		self._peers.meta[id].last_removed_t = _now()
	end
end

function N:_on_peer_left(session, peer, peer_id)
	local id = peer_id or (peer and type(peer.id) == "function" and peer:id()) or nil
	local nm = (peer and type(peer.name) == "function" and peer:name()) or "?"
	self:_push_event("left", self:_peer_event_prefix(session) .. "LEFT " .. tostring(id) .. " " .. tostring(nm), "info")
end

function N:_on_peer_lost(session, peer, peer_id)
	local id = peer_id or (peer and type(peer.id) == "function" and peer:id()) or nil
	local nm = (peer and type(peer.name) == "function" and peer:name()) or "?"
	self:_push_event("lost", self:_peer_event_prefix(session) .. "LOST " .. tostring(id) .. " " .. tostring(nm), "warn")
end

function N:_on_peer_kicked(session, peer, peer_id, message_id)
	local id = peer_id or (peer and type(peer.id) == "function" and peer:id()) or nil
	local nm = (peer and type(peer.name) == "function" and peer:name()) or "?"
	self:_push_event("kick", self:_peer_event_prefix(session) .. "KICK " .. tostring(id) .. " " .. tostring(nm) .. " msg=" .. tostring(message_id), "bad")
end

function N:_on_peer_loading(session, peer, state)
	local id = peer and type(peer.id) == "function" and peer:id() or "?"
	local nm = peer and type(peer.name) == "function" and peer:name() or "?"
	local s = state and "loading" or "loaded"
	self:_push_event("load", self:_peer_event_prefix(session) .. "LOAD " .. tostring(id) .. " " .. tostring(nm) .. " -> " .. s, state and "info" or "good")
end

function N:_on_peer_sync_complete(session, peer, peer_id)
	local id = peer_id or (peer and type(peer.id) == "function" and peer:id()) or nil
	local nm = (peer and type(peer.name) == "function" and peer:name()) or "?"
	self:_push_event("sync", self:_peer_event_prefix(session) .. "SYNC " .. tostring(id) .. " " .. tostring(nm), "good")
end

Hooks:Add("GameSetupUpdate", "NetworkSessionDebug.Update", function(t, dt)
	if _G.NetworkSessionDebug and _G.NetworkSessionDebug.update then
		_G.NetworkSessionDebug:update(t, dt)
	end
end)

Hooks:Add("GameSetupPausedUpdate", "NetworkSessionDebug.PausedUpdate", function(t, dt)
	if _G.NetworkSessionDebug and _G.NetworkSessionDebug.update then
		_G.NetworkSessionDebug:update(t, dt)
	end
end)

Hooks:Add("MenuUpdate", "NetworkSessionDebug.MenuUpdate", function(t, dt)
	if _G.NetworkSessionDebug and _G.NetworkSessionDebug.update then
		_G.NetworkSessionDebug:update(t, dt)
	end
end)