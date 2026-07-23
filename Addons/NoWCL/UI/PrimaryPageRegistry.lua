local _, NoWCL = ...
local R = { pages = {}, ordered = {}, hosts = setmetatable({}, { __mode = "k" }) }
NoWCL.PrimaryPages = R
local RESERVED = { audit = true, settings = true, azeroth = true }
local function rebuildOrder(self)
self.ordered = {}
for _, page in pairs(self.pages) do self.ordered[#self.ordered + 1] = page end
table.sort(self.ordered, function(a, b)
local ao, bo = tonumber(a.order) or 100, tonumber(b.order) or 100
if ao ~= bo then return ao < bo end
return a.id < b.id
end)
end
function R:Register(descriptor)
if type(descriptor) ~= "table" or type(descriptor.id) ~= "string"
or not descriptor.id:match("^[%w_%-]+$") or RESERVED[descriptor.id]
or type(descriptor.label) ~= "string" or type(descriptor.Create) ~= "function" then
return false, "invalid_descriptor"
end
if self.pages[descriptor.id] then return false, "duplicate_id" end
self.pages[descriptor.id] = descriptor
rebuildOrder(self)
for callback in pairs(self.hosts) do callback("added", descriptor) end
return true
end
function R:Unregister(id)
local page = self.pages[id]
if not page then return false end
self.pages[id] = nil
rebuildOrder(self)
for callback in pairs(self.hosts) do callback("removed", page) end
return true
end
function R:Get(id)
return self.pages[id]
end
function R:GetAll()
local out = {}
for i, page in ipairs(self.ordered) do out[i] = page end
return out
end
function R:AttachHost(callback)
if type(callback) ~= "function" then return false end
self.hosts[callback] = true
for _, page in ipairs(self.ordered) do callback("added", page) end
return true
end
function R:DetachHost(callback)
self.hosts[callback] = nil
end
function NoWCL:RegisterPrimaryPage(descriptor)
return R:Register(descriptor)
end
function NoWCL:UnregisterPrimaryPage(id)
return R:Unregister(id)
end
