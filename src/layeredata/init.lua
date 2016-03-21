local Coromake = require "coroutine.make"
local Uuid     = require "uuid"

Uuid.seed ()

local Layer = setmetatable ({}, {
  __tostring = function () return "Layer" end
})
local Proxy = setmetatable ({}, {
  __tostring = function () return "Proxy" end
})
local Reference = setmetatable ({}, {
  __tostring = function () return "Reference" end
})
local Key = setmetatable ({
  __tostring = function (self) return "-" .. self.name .. "-" end
}, {
  __tostring = function () return "Key" end
})

local IgnoreKeys   = { __mode = "k" }
local IgnoreValues = { __mode = "v" }

local Read_Only = {
  __index    = assert,
  __newindex = assert,
}

local Cache = {
  __mode = "k",
}

function Cache.__index (cache, key)
  local result = setmetatable ({}, IgnoreKeys)
  cache [key] = result
  return result
end

Reference.memo = setmetatable ({}, IgnoreValues)

Layer.key = setmetatable ({
  checks   = setmetatable ({ name = "checks"   }, Key),
  defaults = setmetatable ({ name = "defaults" }, Key),
  labels   = setmetatable ({ name = "labels"   }, Key),
  messages = setmetatable ({ name = "messages" }, Key),
  meta     = setmetatable ({ name = "meta"     }, Key),
  refines  = setmetatable ({ name = "refines"  }, Key),
}, Read_Only)

Layer.tag = setmetatable ({
  null      = {},
  computing = {},
}, Read_Only)

Layer.coroutine = Coromake ()

Layer.loaded = setmetatable ({}, { __mode = "v" })

function Layer.new (t)
  assert (t == nil or type (t) == "table")
  t      = t or {}
  t.name = t.name or Uuid ()
  t.data = t.data or {}
  local layer = setmetatable ({
    __name      = t.name,
    __data      = Layer.import (t.data),
    __root      = false,
    __proxies   = setmetatable ({}, IgnoreValues),
    __indent    = {},
    __observers = {},
  }, Layer)
  local proxy = Proxy.__new (layer)
  layer.__root = proxy
  Layer.loaded [t.name] = proxy
  return proxy
end

function Layer.require (name)
  if Layer.loaded [name] then
    return Layer.loaded [name]
  else
    return require (name) (Layer)
  end
end

local Observer = {}

function Observer.enable (observer)
  observer.layer.__observers [observer] = true
  return observer
end

function Observer.disable (observer)
  observer.layer.__observers [observer] = nil
  return observer
end

function Layer.observe (proxy, f)
  assert (getmetatable (proxy) == Proxy)
  assert (type (f) == "function" or (getmetatable (f) and getmetatable (f).__call))
  local layer = proxy.__layer
  local result = setmetatable ({
    layer   = layer,
    handler = f,
  }, Observer)
  return result:enable ()
end

function Layer.clear_caches (proxy)
  assert (proxy == nil or getmetatable (proxy) == Proxy)
  Layer.caches = {
    index   = setmetatable ({}, IgnoreKeys),
    pairs   = setmetatable ({}, IgnoreKeys),
    ipairs  = setmetatable ({}, IgnoreKeys),
    len     = setmetatable ({}, IgnoreKeys),
    check   = setmetatable ({}, IgnoreKeys),
    perform = {
      noiterate_noresolve = setmetatable ({}, Cache),
      noiterate_resolve   = setmetatable ({}, Cache),
    },
  }
end

function Layer.import (data, within, seen, in_key)
  if not seen then
    seen = {}
  end
  if getmetatable (data) == Key then
    return data
  end
  if seen [data] then
    return seen [data]
  end
  local result
  if type (data) ~= "table" then
    return data
  elseif getmetatable (data) == Proxy then
    if within and not in_key and data.__layer == within.__layer then
      local root = within
      while root.__parent do
        root = root.__parent
      end
      result = Reference.new (root)
      for _, key in ipairs (data.__keys) do
        result = result [key]
      end
    else
      result = data
    end
  elseif getmetatable (data) == Reference then
    result = data
  elseif data.__proxy then
    assert (#data == 0)
    result = Proxy.layerof (data.__layer)
  elseif data.__reference then
    local reference = Reference.new (data.__from)
    for i = 1, #data do
      reference = reference [data [i]]
    end
    result = reference
  else
    result = {}
    seen [data] = result
    local updates = {}
    for key, value in pairs (data) do
      if type (key  ) == "table" then
        updates [key] = Layer.import (key, within, seen, true)
      end
      if type (value) == "table" then
        result  [key] = Layer.import (value, within, seen)
      else
        result [key] = value
      end
    end
    for old_key, new_key in pairs (updates) do
      if old_key ~= new_key then
        result [new_key] = result [old_key]
        result [old_key] = nil
      end
    end
  end
  if not seen [data] then
    seen [data] = result
  end
  return result
end

function Layer.__tostring (layer)
  assert (getmetatable (layer) == Layer)
  return "layer:" .. tostring (layer.__name)
end

function Proxy.__new (t)
  assert (getmetatable (t) == Layer)
  return setmetatable ({
    __keys   = {},
    __layer  = t,
    __memo   = t.__proxies,
    __parent = false,
    __cache  = true,
  }, Proxy)
end

function Proxy.__tostring (proxy)
  assert (getmetatable (proxy) == Proxy)
  local result = {}
  result [1] = proxy.__layer
           and "<" .. tostring (proxy.__layer.__name) .. ">"
            or "<anonymous layer>"
  local keys = proxy.__keys
  for i = 1, #keys do
    result [i+1] = "[" .. tostring (keys [i]) .. "]"
  end
  return table.concat (result, " ")
end

function Layer.decode (string, layers)
  layers = layers or {}
  local loaded = assert (loadstring (string))
  local func   = assert (loaded ())
  return func (Proxy, layers)
end

function Layer.encode (proxy)
  assert (getmetatable (proxy) == Proxy)
  local key_name = {}
  for k, v in pairs (Layer.key) do
    key_name [v] = k
  end
  local function convert (x, is_key, indent)
    indent = indent or ""
    if getmetatable (x) == Key then
      return is_key
         and indent .. "[" .. key_name [x] .. "]"
          or key_name [x]
    elseif getmetatable (x) == Reference then
      assert (not is_key)
      local result = "Layer.reference ("
        .. (x.__from and string.format ("%q", x.__from) or tostring (x.__from))
        .. ")"
      for _, y in ipairs (x.__keys) do
        result = result .. " [" .. convert (y) .. "]"
      end
      return result
    elseif getmetatable (x) == Proxy then
      assert (not is_key)
      local result = "Layer.require " .. string.format ("%q", x.__layer.__name)
      for _, y in ipairs (x.__keys) do
        result = result .. " [" .. convert (y) .. "]"
      end
      return result
    elseif type (x) == "table" then
      assert (not is_key)
      local subresults = {}
      local seen       = {}
      local nindent    = indent .. "  "
      for k, v in pairs (x) do
        if getmetatable (k) == Key then
          subresults [#subresults+1] = convert (k, true, nindent) .. " = " .. convert (v, false, nindent)
          seen [k] = true
        end
      end
      for k, v in ipairs (x) do
        subresults [#subresults+1] = nindent .. convert (v, false, nindent)
        seen [k] = true
      end
      for _, oftype in ipairs { "number", "boolean", "string" } do
        for k, v in pairs (x) do
          if type (k) == oftype and not seen [k] then
            subresults [#subresults+1] = convert (k, true, nindent) .. " = " .. convert (v, false, nindent)
            seen [k] = true
          end
        end
      end
      for k, v in pairs (x) do
        if getmetatable (k) == Proxy then
          subresults [#subresults+1] = nindent .. "[" .. convert (k, false, nindent) .. "] = " .. convert (v, false, nindent)
          seen [k] = true
        end
      end
      for k in pairs (x) do
        assert (seen [k])
      end
      return "{\n" .. table.concat (subresults, ",\n") .. "\n" .. indent .. "}"
    elseif type (x) == "string" then
      return is_key
         and indent .. (x:match "^[_%a][_%w]*$" and x or "[" .. string.format ("%q", x) .. "]")
          or string.format ("%q", x)
    elseif type (x) == "number" then
      return is_key
         and indent .. "[" .. tostring (x) .. "]"
          or tostring (x)
    elseif type (x) == "boolean" then
      return is_key
         and indent .. "[" .. tostring (x) .. "]"
          or tostring (x)
    elseif type (x) == "function" then
      assert (not is_key)
      return indent .. string.format ("%q", string.dump (x))
    else
      assert (false)
    end
  end
  local result = [[
return function (Layer)
{{{LOCALS}}}
  return Layer.new {
    name = {{{NAME}}},
    data = {{{BODY}}},
  }
end
  ]]
  local locals    = {}
  local localsize = 0
  local keys      = {}
  for key in pairs (Layer.key) do
    localsize = math.max (localsize, #key)
    keys [#keys+1] = key
  end
  table.sort (keys)
  for _, key in ipairs (keys) do
    local pad = ""
    for _ = #key+1, localsize do
      pad = pad .. " "
    end
    locals [#locals+1] = "  local " .. key .. pad .. " = Layer.key." .. key
  end
  result = result:gsub ("{{{NAME}}}"  , string.format ("%q", proxy.__layer.__name))
  result = result:gsub ("{{{LOCALS}}}", table.concat (locals, "\n"))
  local body = convert (Proxy.rawget (proxy), false, "    "):gsub ("%%", "%%%%")
  result = result:gsub ("{{{BODY}}}"  , body)
  return result
end

function Layer.dump (proxy)
  assert (getmetatable (proxy) == Proxy)
  local function convert (x, is_key)
    if getmetatable (x) == Key then
      assert (false)
    elseif getmetatable (x) == Reference then
      assert (not is_key)
      local result = "@" .. x.__from
      for _, y in ipairs (x.__keys) do
        result = result .. " / " .. tostring (convert (y))
      end
      return result
    elseif type (x) == "table" then
      assert (not is_key)
      local subresults = {}
      for k, v in pairs (x) do
        if getmetatable (k) ~= Key then
          subresults [convert (k, true)] = convert (v)
        end
      end
      return subresults
    elseif type (x) == "string" then
      return x
    elseif type (x) == "number" then
      return x
    elseif type (x) == "boolean" then
      return x
    elseif type (x) == "function" then
      assert (not is_key)
      local info = debug.getinfo (x)
      assert (info and info.what == "Lua")
      return info.source ..
               " [" .. tostring (info.linedefined) ..
               ".." .. tostring (info.lastlinedefined) ..
                "]"
    else
      assert (false)
    end
  end
  return convert (Proxy.rawget (proxy))
end

function Proxy.sub (proxy, key)
  assert (getmetatable (proxy) == Proxy)
  assert (key ~= nil)
  local proxies = proxy.__memo
  local found   = proxies [key]
  if not found then
    local cache = true
    local nkeys = {}
    for i = 1, #proxy.__keys do
      nkeys [i] = proxy.__keys [i]
      cache = cache and nkeys [i] ~= Layer.key.messages
    end
    nkeys [#nkeys+1] = key
    cache = cache and key ~= Layer.key.messages
    found = setmetatable ({
      __layer     = proxy.__layer,
      __keys      = nkeys,
      __memo      = setmetatable ({}, IgnoreValues),
      __parent    = proxy,
      __cache     = cache,
    }, Proxy)
    proxies [key] = found
  end
  return found
end

function Proxy.check (proxy)
  assert (getmetatable (proxy) == Proxy)
  local cache = Layer.caches.check
  if cache [proxy] then
    return
  end
  cache [proxy] = true
  for _, key in ipairs (proxy.__keys) do
    if getmetatable (key) == Key then
      return
    end
  end
  local checks = proxy [Layer.key.checks]
  if not checks then
    return
  end
  local messages = Proxy.rawget (Proxy.sub (proxy, Layer.key.messages)) or {}
  for _, f in Proxy.__pairs (checks) do
    assert (type (f) == "function")
    local co = Layer.coroutine.wrap (function ()
      return f (proxy)
    end)
    for id, data in co do
      messages [id] = data or {}
    end
  end
  if next (messages) then
    proxy [Layer.key.messages] = messages
  else
    proxy [Layer.key.messages] = nil
  end
end

function Proxy.__index (proxy, key)
  assert (getmetatable (proxy) == Proxy)
  proxy = Proxy.sub (proxy, key)
  local cproxy = proxy
  if proxy.__cache then
    local cache  = Layer.caches.index
    local cached = cache [proxy]
    if cached == Layer.tag.null then
      return nil
    elseif cached == Layer.tag.computing then
      return nil
    elseif cached ~= nil then
      return cached
    end
    cache [proxy] = Layer.tag.computing
  end
  local result
  local _, value = Proxy.equivalents (proxy) ()
  if getmetatable (value) == Reference then
    result = Reference.resolve (value, proxy)
  elseif getmetatable (value) == Proxy then
    result = value
  elseif type (value) == "table" then
    result = proxy
  else
    result = value
  end
  if proxy.__cache then
    local cache = Layer.caches.index
    if result == nil then
      cache [cproxy] = Layer.tag.null
    else
      cache [cproxy] = result
    end
  end
  if getmetatable (result) == Proxy then
    Proxy.check (result)
  end
  return result
end

function Proxy.rawget (proxy)
  assert (getmetatable (proxy) == Proxy)
  local current = proxy.__layer.__data
  local keys    = proxy.__keys
  for _, key in ipairs (keys) do
    current = type (current) == "table"
          and getmetatable (current) ~= Proxy
          and getmetatable (current) ~= Reference
          and current [key]
           or nil
  end
  return current
end

function Proxy.__newindex (proxy, key, value)
  assert (getmetatable (proxy) == Proxy)
  assert ( type (key) ~= "table"
        or getmetatable (key) == Proxy
        or getmetatable (key) == Reference
        or getmetatable (key) == Key)
  key   = Layer.import (key  , proxy)
  value = Layer.import (value, proxy)
  local current = proxy.__layer.__data
  local keys    = proxy.__keys
  for i = 1, #keys do
    local k = keys [i]
    if current [k] == nil then
      current [k] = {}
    end
    current = current [k]
  end
  current [key] = value
  if proxy.__cache then
    Layer.clear_caches (proxy)
  end
  for observer in pairs (proxy.__layer.__observers) do
    observer (proxy)
  end
end

function Proxy.replacewith (proxy, value)
  assert (getmetatable (proxy) == Proxy)
  Layer.clear_caches (proxy)
  local layer = proxy.__layer
  local keys  = proxy.__keys
  if #keys == 0 then
    assert (type (value) == "table")
    layer.__data = Layer.import (value, proxy)
  else
    local current = layer.__data
    for i = 1, #keys-1 do
      current = current [keys [i]]
      assert (type (current) == "table" and getmetatable (current) ~= Reference)
    end
    current [keys [#keys]] = {}
    current [keys [#keys]] = Layer.import (value, proxy)
  end
end

function Proxy.is_prefix (lhs, rhs)
  assert (getmetatable (lhs) == Proxy)
  assert (getmetatable (rhs) == Proxy)
  if #lhs.__keys > #rhs.__keys then
    return false
  end
  for i = 1, #lhs.__keys do
    if lhs.__keys [i] ~= rhs.__keys [i] then
      return false
    end
  end
  return true
end

function Proxy.has_meta (proxy)
  assert (getmetatable (proxy) == Proxy)
  for i = 1, #proxy.__keys do
    if proxy.__keys [i] == Layer.key.meta then
      return true
    end
  end
  return false
end

function Proxy.is_reference (proxy)
  assert (getmetatable (proxy) == Proxy)
  local _, value = Proxy.equivalents (proxy) ()
  return getmetatable (value) == Reference
end

function Proxy.equivalents (proxy, options)
  assert (getmetatable (proxy) == Proxy)
  assert (options == nil or type (options) == "table")
  options = options or {}
  local coroutine = Coromake ()
  local function iterate (where, current)
    local n    = #current.__keys - #where.__keys
    local raw  = Proxy.rawget (where)
    local keys = current.__keys
    if (options.all or raw ~= nil) and n == 0 then
      coroutine.yield (where, raw)
    end
    local restricted_proxy = proxy
    for _ = 1, n+1 do
      restricted_proxy = getmetatable (restricted_proxy) == Proxy
                     and restricted_proxy.__parent
                      or restricted_proxy
    end
    local search = {}
    local search_parent = true
    for _, key in ipairs (where.__keys) do
      if key == Layer.key.defaults
      or key == Layer.key.refines then
        search_parent = false
      end
    end
    if search_parent then
      local refines = type (raw) == "table"
                  and getmetatable (raw) ~= Proxy
                  and getmetatable (raw) ~= Reference
                  and raw [Layer.key.refines]
      for _, x in ipairs (refines or {}) do
        search [#search+1] = x
      end
    end
    local search_default = true
    for _, key in ipairs (where.__keys) do
      if key == Layer.key.messages
      or key == Layer.key.defaults
      or key == Layer.key.refines then
        search_default = false
      end
    end
    if search_default then
      local parent   = where.__parent
      local key      = where.__keys [#where.__keys]
      local rawp     = getmetatable (key) ~= Key
                   and where
                   and parent
                   and Proxy.rawget (parent)
      local defaults = type (rawp) == "table"
                   and rawp [Layer.key.defaults]
      for _, x in ipairs (defaults or {}) do
        search [#search+1] = x
      end
    end
    for i = #search, 1, -1 do
      local x = search [i]
      while x and getmetatable (x) == Reference do
        x = Reference.resolve (x, restricted_proxy)
      end
      if getmetatable (x) == Proxy then
        for j = #keys-n+1, #keys do
          x = Proxy.sub (x, keys [j])
        end
        iterate (x, x)
      end
    end
    if where.__parent then
      iterate (where.__parent, current)
    end
  end
  return coroutine.wrap (function ()
    iterate (proxy, proxy)
  end)
end

function Proxy.__lt (lhs, rhs)
  assert (getmetatable (lhs) == Proxy)
  assert (getmetatable (rhs) == Proxy)
  for p in Proxy.equivalents (rhs, { all = true }) do
    if getmetatable (p) == Proxy and p == lhs then
      return true
    end
  end
  return false
end

function Proxy.__le (lhs, rhs)
  if lhs == rhs then
    return true
  else
    return Proxy.__lt (lhs, rhs)
  end
end

function Proxy.__mod (proxy, n)
  assert (getmetatable (proxy) == Proxy)
  assert (type (n) == "number")
  if n >= 0 then
    assert (n <= #proxy.__keys)
    local result = Proxy.__new (proxy.__layer)
    for i = 1, n do
      result = Proxy.sub (result, proxy.__keys [i])
    end
    return result
  elseif n < 0 then
    assert (n <= #proxy.__keys)
    local result = Proxy.__new (proxy.__layer)
    for i = 1, #proxy.__keys + n do
      result = Proxy.sub (result, proxy.__keys [i])
    end
    return result
  end
end

function Proxy.__len (proxy)
  assert (getmetatable (proxy) == Proxy)
  local cache = Layer.caches.len
  if cache [proxy] then
    return cache [proxy]
  end
  for i = 1, math.huge do
    local result = proxy [i]
    if result == nil then
      cache [proxy] = i-1
      return i-1
    end
  end
  assert (false)
end

function Proxy.__ipairs (proxy)
  assert (getmetatable (proxy) == Proxy)
  local cache = Layer.caches.ipairs
  if cache [proxy] then
    return coroutine.wrap (function ()
      for i, v in ipairs (cache [proxy]) do
        coroutine.yield (i, v)
      end
    end)
  end
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    local cached = {}
    for i = 1, math.huge do
      local result = proxy [i]
      if result == nil then
        break
      end
      cached [i] = result
      coroutine.yield (i, result)
    end
    cache [proxy] = cached
  end)
end

function Proxy.__pairs (proxy)
  assert (getmetatable (proxy) == Proxy)
  local coroutine = Coromake ()
  local cache = Layer.caches.pairs
  if cache [proxy] then
    return coroutine.wrap (function ()
      for k, v in pairs (cache [proxy]) do
        coroutine.yield (k, v)
      end
    end)
  end
  return coroutine.wrap (function ()
    local cached = {}
    for p, current in Proxy.equivalents (proxy) do
      while getmetatable (current) == Reference do
        current = Reference.resolve (current, proxy)
      end
      if getmetatable (current) == Proxy then
        for k in Proxy.__pairs (current) do
          if  cached [k] == nil and current [k] ~= nil
          and getmetatable (k) ~= Layer.Key then
            cached [k] = current [k]
            coroutine.yield (k, current [k])
          end
        end
      elseif type (current) == "table" then
        for k in pairs (current) do
          if  cached [k] == nil and p [k] ~= nil
          and getmetatable (k) ~= Layer.Key then
            cached [k] = p [k]
            coroutine.yield (k, cached [k])
          end
        end
      end
    end
    cache [proxy] = cached
  end)
end

function Reference.new (target)
  assert (getmetatable (target) == Proxy)
  local memo = Reference.memo [target]
  if memo then
    return memo
  end
  local label  = Uuid ()
  Proxy.sub (target, Layer.key.labels) [label] = true
  local result = setmetatable ({
    __from   = label,
    __keys   = {},
    __memo   = setmetatable ({}, IgnoreValues),
    __parent = false,
  }, Reference)
  Reference.memo [target] = result
  return result
end

function Reference.__index (reference, key)
  assert (getmetatable (reference) == Reference)
  local references = reference.__memo
  local found      = references [key]
  if not found then
    local nkeys = {}
    for i = 1, #reference.__keys do
      nkeys [i] = reference.__keys [i]
    end
    nkeys [#nkeys+1] = key
    found = setmetatable ({
      __from   = reference.__from,
      __keys   = nkeys,
      __memo   = setmetatable ({}, IgnoreValues),
      __parent = reference,
    }, Reference)
    references [key] = found
  end
  return found
end

function Reference.resolve (reference, proxy)
  assert (getmetatable (reference) == Reference)
  assert (getmetatable (proxy    ) == Proxy    )
  for i = 1, #proxy.__keys do
    local key = proxy.__keys [i]
    if getmetatable (key) == Key then
      for _ = #proxy.__keys, i, -1 do
        proxy = proxy.__parent
      end
      break
    end
  end
  local current = proxy
  while current do
    local labels = current
    labels = Proxy.sub (labels, Layer.key.labels)
    labels = Proxy.sub (labels, reference.__from)
    if Proxy.equivalents (labels) () then
      break
    end
    current = current.__parent
  end
  if not current then
    return nil
  end
  local rkeys = reference.__keys
  for i = 1, #rkeys do
    while getmetatable (current) == Reference do
      current = Reference.resolve (current, proxy)
    end
    if getmetatable (current) ~= Proxy then
      return nil
    end
    current = current [rkeys [i]]
  end
  return current
end

function Reference.__tostring (reference)
  assert (getmetatable (reference) == Reference)
  local result = {}
  result [1] = tostring (reference.__from)
  result [2] = "->"
  local keys = reference.__keys
  for i = 1, #keys do
    result [i+2] = "[" .. tostring (keys [i]) .. "]"
  end
  return table.concat (result, " ")
end

Layer.Proxy     = Proxy
Layer.Reference = Reference
Layer.Key       = Key
Layer.reference = Reference.new

-- Lua 5.1 compatibility:
Layer.len    = Proxy.__len
Layer.pairs  = Proxy.__pairs
Layer.ipairs = Proxy.__ipairs

Layer.clear_caches ()

return Layer
