local NSD = _G.NetworkSessionDebug or {}
_G.NetworkSessionDebug = NSD

NSD._hooks = NSD._hooks or {}
if NSD._hooks.session then
	return
end
NSD._hooks.session = true

local function _safe_call(fn, ...)
	if type(fn) ~= "function" then
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok and type(NSD._log) == "function" then
		NSD:_log("NSD hook error: " .. tostring(err))
	end
end

if not (_G.Hooks and _G.BaseNetworkSession) then
	return
end

Hooks:PostHook(BaseNetworkSession, "add_peer", "NSD.Session.AddPeer", function(self, name, rpc, in_lobby, loading, synched, id)
	local peer = id and self:peer(id) or nil
	_safe_call(NSD._on_peer_added, NSD, self, peer, id, name, rpc, in_lobby, loading, synched)
end)

Hooks:PostHook(BaseNetworkSession, "remove_peer", "NSD.Session.RemovePeer", function(self, peer, peer_id, reason)
	_safe_call(NSD._on_peer_removed, NSD, self, peer, peer_id, reason)
end)

Hooks:PostHook(BaseNetworkSession, "on_peer_left", "NSD.Session.PeerLeft", function(self, peer, peer_id)
	_safe_call(NSD._on_peer_left, NSD, self, peer, peer_id)
end)

Hooks:PostHook(BaseNetworkSession, "on_peer_lost", "NSD.Session.PeerLost", function(self, peer, peer_id)
	_safe_call(NSD._on_peer_lost, NSD, self, peer, peer_id)
end)

Hooks:PostHook(BaseNetworkSession, "on_peer_kicked", "NSD.Session.PeerKicked", function(self, peer, peer_id, message_id)
	_safe_call(NSD._on_peer_kicked, NSD, self, peer, peer_id, message_id)
end)

Hooks:PostHook(BaseNetworkSession, "on_peer_loading", "NSD.Session.PeerLoading", function(self, peer, state)
	_safe_call(NSD._on_peer_loading, NSD, self, peer, state)
end)

Hooks:PostHook(BaseNetworkSession, "on_peer_sync_complete", "NSD.Session.PeerSyncComplete", function(self, peer, peer_id)
	_safe_call(NSD._on_peer_sync_complete, NSD, self, peer, peer_id)
end)