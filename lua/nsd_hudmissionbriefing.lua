local N = _G.NetworkSessionDebug or {}
_G.NetworkSessionDebug = N

if N._hooks and N._hooks.mission_briefing then
	return
end
N._hooks = N._hooks or {}
N._hooks.mission_briefing = true

local function _alive(o)
	return o and alive and alive(o)
end

local function _ensure_slot_line(slot_panel)
	if not _alive(slot_panel) then
		return nil
	end
	local line = slot_panel:child("nsd_net")
	if _alive(line) then
		return line
	end
	local name = slot_panel:child("name")
	local font = name and name:font() or (tweak_data and tweak_data.menu and tweak_data.menu.pd2_small_font) or "fonts/font_small_mf"
	local fs = name and name:font_size() or (tweak_data and tweak_data.menu and tweak_data.menu.pd2_small_font_size) or 14
	local line_fs = math.max(10, math.floor(fs * 0.78 + 0.5))
	line = slot_panel:text({
		name = "nsd_net",
		vertical = "center",
		align = "left",
		blend_mode = "add",
		layer = 3,
		x = name and name:x() or 0,
		y = fs - 2,
		w = slot_panel:w(),
		h = line_fs + 2,
		text = "",
		font = font,
		font_size = line_fs,
		color = tweak_data.screen_colors and tweak_data.screen_colors.text and tweak_data.screen_colors.text:with_alpha(0.6) or Color.white:with_alpha(0.6)
	})
	return line
end

local function _relayout_briefing(self)
	if not (self and _alive(self._ready_slot_panel)) then
		return
	end
	if self._nsd_relayout_done then
		return
	end
	self._nsd_relayout_done = true

	local first = self._ready_slot_panel:child("slot_1")
	if not _alive(first) then
		return
	end
	local name = first:child("name")
	if not _alive(name) then
		return
	end
	local fs = name:font_size()
	local step = fs * 2
	local top_pad = 10

	for i = 1, tweak_data.max_players do
		local slot = self._ready_slot_panel:child("slot_" .. tostring(i))
		if _alive(slot) then
			slot:set_y(top_pad + (i - 1) * step)
			slot:set_h(step)
			_ensure_slot_line(slot)
		end
	end

	local new_h = top_pad + tweak_data.max_players * step + top_pad
	local bottom = self._ready_slot_panel:bottom()
	self._ready_slot_panel:set_h(new_h)
	self._ready_slot_panel:set_bottom(bottom)

	for _, c in ipairs(self._ready_slot_panel:children() or {}) do
		local nm = c:name()
		if type(nm) == "string" and nm:find("BoxGuiObject", 1, true) then
			self._ready_slot_panel:remove(c)
		end
	end

	BoxGuiObject:new(self._ready_slot_panel, { sides = { 1, 1, 1, 1 } })
end

Hooks:PostHook(HUDMissionBriefing, "init", "NSD.HUDBriefing.Init", function(self, hud, workspace)
	_relayout_briefing(self)
	if N and type(N._log) == "function" and not N._briefing_logged then
		N._briefing_logged = true
		N:_log("briefing patched (lobby lines ready)")
	end
end)