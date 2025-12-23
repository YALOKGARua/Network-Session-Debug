Hooks:Add("LocalizationManagerPostInit", "NSD.Localization", function(loc)
	loc:add_localized_strings({
		nsd_options_title = "Network Session Debug",
		nsd_options_desc = "Configure Network Session Debug."
	})
end)