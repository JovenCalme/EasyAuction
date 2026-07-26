local addonName, ns = ...

ns = ns or {}
ns.BagValue = ns.BagValue or {}

local BagValue = ns.BagValue

BagValue.ADDON_NAME = addonName or "EasyAuction"
BagValue.Freshness = BagValue.Freshness or {
    FRESH = "fresh",
    STALE = "stale",
    UNKNOWN = "unknown",
    MISSING = "missing",
}

return BagValue
