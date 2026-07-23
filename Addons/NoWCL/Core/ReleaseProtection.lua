local _, _bamichfzbo = ...
local _rsxjinkxzd = {
failures = {},
format = "nowcl-rule-ir-v1",
}
_bamichfzbo.ReleaseProtection = _rsxjinkxzd
local _fmibnbwsjl = 2147483647
local _pdsjuspzfq = "="
local function _yqyvmdrpoc(self, moduleName, reason)
moduleName = tostring(moduleName or "rules")
reason = tostring(reason or "unknown")
if not self.failures[moduleName] then self.failures[moduleName] = reason end
_bamichfzbo.ruleProtectionFailed = true
return nil, reason
end
local function _bbcbegpssd(payload, alphabet)
if type(payload) ~= "string" or type(alphabet) ~= "string" or #alphabet ~= 64 then
return nil, "invalid-container"
end
local index = {}
for i = 1, 64 do index[alphabet:byte(i)] = i - 1 end
local out = {}
local position = 1
while position <= #payload do
local a = index[payload:byte(position)]
local b = index[payload:byte(position + 1)]
local cbyte = payload:byte(position + 2)
local dbyte = payload:byte(position + 3)
if a == nil or b == nil then return nil, "invalid-base64" end
local c, d
if cbyte ~= string.byte(_pdsjuspzfq) then c = index[cbyte] end
if dbyte ~= string.byte(_pdsjuspzfq) then d = index[dbyte] end
if cbyte and cbyte ~= string.byte(_pdsjuspzfq) and c == nil then return nil, "invalid-base64" end
if dbyte and dbyte ~= string.byte(_pdsjuspzfq) and d == nil then return nil, "invalid-base64" end
local value = a * 262144 + b * 4096 + (c or 0) * 64 + (d or 0)
out[#out + 1] = string.char(math.floor(value / 65536) % 256)
if c ~= nil then out[#out + 1] = string.char(math.floor(value / 256) % 256) end
if d ~= nil then out[#out + 1] = string.char(value % 256) end
position = position + 4
end
return table.concat(out)
end
local function _dctjmwhqrf(parts)
if type(parts) ~= "table" then return nil end
local first = tonumber(parts[1])
local second = tonumber(parts[2])
local third = tonumber(parts[3])
if not first or not second or not third then return nil end
local key = (first * 97 + second * 193 + third * 389) % _fmibnbwsjl
return key > 0 and key or 1
end
local function _roerymibnf(ciphertext, key)
local state = key
local hash = 7
local plain = {}
for i = 1, #ciphertext do
state = (state * 48271) % _fmibnbwsjl
local value = (ciphertext:byte(i) - ((state + i * 31) % 256)) % 256
plain[i] = string.char(value)
hash = (hash * 131 + value) % _fmibnbwsjl
end
return table.concat(plain), hash
end
function _rsxjinkxzd:DecodeRuleBlob(moduleName, payload, alphabet, keyParts, expected)
local ciphertext, decodeError = _bbcbegpssd(payload, alphabet)
if not ciphertext then return _yqyvmdrpoc(self, moduleName, decodeError) end
local key = _dctjmwhqrf(keyParts)
if not key then return _yqyvmdrpoc(self, moduleName, "invalid-key") end
local source, hash = _roerymibnf(ciphertext, key)
if ((hash * 7 + key) % _fmibnbwsjl) ~= tonumber(expected) then
return _yqyvmdrpoc(self, moduleName, "integrity-mismatch")
end
local compiler = loadstring or load
if not compiler then return _yqyvmdrpoc(self, moduleName, "compiler-unavailable") end
local chunk, compileError = compiler(source, "@NoWCL:" .. tostring(moduleName or "rules"))
if not chunk then return _yqyvmdrpoc(self, moduleName, "compile:" .. tostring(compileError)) end
local ok, decoded = pcall(chunk)
source, ciphertext = nil, nil
if not ok then return _yqyvmdrpoc(self, moduleName, "execute:" .. tostring(decoded)) end
if type(decoded) ~= "table" then return _yqyvmdrpoc(self, moduleName, "invalid-result") end
return decoded
end
function _rsxjinkxzd:IsHealthy()
return next(self.failures) == nil
end
function _rsxjinkxzd:ReportFailures()
if self._reported or self:IsHealthy() then return self:IsHealthy() end
self._reported = true
local modules = {}
for moduleName in pairs(self.failures) do modules[#modules + 1] = moduleName end
table.sort(modules)
local message = "|cffff3333发布规则完整性校验失败|r：已停用受影响的 WCL 规则（"
.. table.concat(modules, "、") .. "），请重新安装完整发布包。"
if _bamichfzbo.Print then _bamichfzbo:Print(message)
elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(message) end
return false
end
