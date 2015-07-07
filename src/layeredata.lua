-- Examples
-- ========
--
--    > Layer = require "layeredata"
--    > a = Layer.new { name = "a" }
--    > b = Layer.new { name = "b" }
--    > a.x = 1
--    > a.y = 2
--    > b.__depends__ = { a }
--    > b.x = 3
--    > b.z = 4
--    > = a.x, a.y, a.z
--    1, 2, nil
--    > = b.x, b.y, b.z
--    3, 2, 4

local coromake = require "coroutine.make"
local c3       = require "c3"
local serpent  = require "serpent"

local Layer              = setmetatable ({}, {
  __tostring = function () return "Layer" end
})
local Proxy              = setmetatable ({}, {
  __tostring = function () return "Proxy" end
})
local Reference          = setmetatable ({}, {
  __tostring = function () return "Reference" end
})
local IgnoreKeys         = {}
IgnoreKeys.__mode        = "k"
local IgnoreValues       = {}
IgnoreValues.__mode      = "v"

-- How to apply __checks__?
-- 1. apply on modified object its __checks__,
-- 2. apply on parents,
-- 3. applied on references and their parents

Proxy.keys = {
  depends  = "__depends__",
  refines  = "__refines__",
  checks   = "__checks__",
  referred = "__referred__",
}
Proxy.specials = {
  default = "__default__",
  label   = "__label__",
  meta    = "__meta__",
}

local function totypedstring (x)
  return tostring (x)
end

local function keys_of (...)
  local special = {}
  for _, keys in ipairs { ... } do
    for _, k in pairs (keys) do
      special [k] = true
    end
  end
  return special
end

local unpack = table.unpack or unpack

function Layer.__new (t)
  assert (type (t) == "table")
  local layer = setmetatable ({
    __name    = t.name,
    __data    = Layer.import (t.data or {}),
    __root    = false,
    __proxies = setmetatable ({}, IgnoreValues),
    __caches  = {
      index  = setmetatable ({}, IgnoreKeys),
      pairs  = setmetatable ({}, IgnoreKeys),
      ipairs = setmetatable ({}, IgnoreKeys),
      len    = setmetatable ({}, IgnoreKeys),
    },
  }, Layer)
  local proxy = Proxy.__new (layer)
  layer.__root = proxy
  return proxy
end

function Layer.clear_caches ()
  Layer.caches = {
    index  = setmetatable ({}, IgnoreKeys),
    pairs  = setmetatable ({}, IgnoreKeys),
    ipairs = setmetatable ({}, IgnoreKeys),
    len    = setmetatable ({}, IgnoreKeys),
  }
end

-- Each layer contains a map:
-- referenced -> { reference = true, ... }

function Layer.import (data, ref, seen)
  if not ref then
    ref = Reference.new (false)
  end
  if not seen then
    seen = {}
  end
  if seen [data] then
    return seen [data]
  end
  local result
  if type (data) ~= "table" then
    return data
  elseif getmetatable (data) == Proxy then
    if #data.__keys == 0 then
      result = data
    else
      local reference = Reference.new (false)
      local keys      = data.__keys
      for i = 1, #keys do
        reference = reference [keys [i]]
      end
      result = reference
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
    seen [data] = ref
    local updates = {}
    for key, value in pairs (data) do
      if type (key  ) == "table" then
        updates [key] = Layer.import (key, ref, seen)
      end
      if type (value) == "table" then
        data    [key] = Layer.import (value, ref [key], seen)
      end
    end
    for old_key, new_key in pairs (updates) do
      data [old_key], data [new_key] = nil, data [old_key]
    end
    result = data
  end
  if not seen [data] then
    seen [data] = result
  end
  return result
end

function Layer.__tostring (layer)
  assert (getmetatable (layer) == Layer)
  return "layer:" .. totypedstring (layer.__name)
end

function Proxy.__new (t)
  assert (getmetatable (t) == Layer)
  return setmetatable ({
    __keys      = {},
    __layer     = t,
    __memo      = t.__proxies,
    __parent    = false,
    __writeable = true,
  }, Proxy)
end

function Proxy.__serialize (proxy)
  assert (getmetatable (proxy) == Proxy)
  return {
    __proxy = true,
    __layer = proxy.__layer.__name,
    unpack (proxy.__keys),
  }
end

function Proxy.dump (proxy, serialize)
  assert (getmetatable (proxy) == Proxy)
  local Layer_serialize     = Layer    .__serialize
  local Proxy_serialize     = Proxy    .__serialize
  local Reference_serialize = Reference.__serialize
  if not serialize then
    Layer    .__serialize = nil
    Proxy    .__serialize = nil
    Reference.__serialize = nil
  end
  local result = serpent.dump (Proxy.export (proxy), {
    indent   = "  ",
    comment  = false,
    sortkeys = true,
    compact  = false,
  })
  if not serialize then
    Layer    .__serialize = Layer_serialize
    Proxy    .__serialize = Proxy_serialize
    Reference.__serialize = Reference_serialize
  end
  return result
end

function Proxy.__tostring (proxy)
  assert (getmetatable (proxy) == Proxy)
  local result = {}
  result [1] = proxy.__layer
           and "<" .. totypedstring (proxy.__layer.__name) .. ">"
            or "<anonymous layer>"
  local keys = proxy.__keys
  for i = 1, #keys do
    result [i+1] = "[" .. totypedstring (keys [i]) .. "]"
  end
  return table.concat (result, " ")
end

function Proxy.sub (proxy, key)
  assert (getmetatable (proxy) == Proxy)
  local proxies = proxy.__memo
  local found   = proxies [key]
  if not found then
    local nkeys = {}
    for i = 1, #proxy.__keys do
      nkeys [i] = proxy.__keys [i]
    end
    nkeys [#nkeys+1] = key
    found = setmetatable ({
      __layer     = proxy.__layer,
      __keys      = nkeys,
      __memo      = setmetatable ({}, IgnoreValues),
      __parent    = proxy,
      __writeable = proxy.__writeable,
    }, Proxy)
    proxies [key] = found
  end
  return found
end

function Proxy.__index (proxy, key)
  assert (getmetatable (proxy) == Proxy)
  proxy = Proxy.sub (proxy, key)
  local cache = Layer.caches.index
  if cache [proxy] ~= nil then
    return cache [proxy]
  end
  local _, c = Proxy.apply (proxy) (proxy)
  local result
  if getmetatable (c) == Proxy or type (c) ~= "table" then
    result = c
  else
    result = proxy
  end
  cache [proxy] = result
  return result
end

function Proxy.__newindex (proxy, key, value)
  assert (getmetatable (proxy) == Proxy)
  assert (proxy.__writeable)
  assert (type (key) ~= "table" or getmetatable (key) == Proxy)
  local layer = proxy.__layer
  local cache = proxy.__layer.__caches.index
  proxy = Proxy.sub (proxy, key)
  cache [proxy] = nil
  key   = Layer.import (key  )
  value = Layer.import (value)
  local current = layer.__data
  local keys    = proxy.__keys
  for i = 1, #keys-1 do
    local k = keys [i]
    if current [k] == nil then
      current [k] = {}
    end
    assert (type (current [k]) == "table" and getmetatable (current [k]) ~= Reference)
    current = current [k]
  end
  current [key] = value
  Layer.clear_caches (proxy)
  -- FIXME: run checks
end

function Proxy.replacewith (proxy, value)
  assert (getmetatable (proxy) == Proxy)
  Layer.clear_caches (proxy)
  value = Layer.import (value)
  local layer = proxy.__layer
  local keys  = proxy.__keys
  if #keys == 0 then
    assert (type (value) == "table")
    layer.__data = value
  else
    local current = layer.__data
    for i = 1, #keys-1 do
      current = current [keys [i]]
      assert (type (current) == "table" and getmetatable (current) ~= Reference)
    end
    current [keys [#keys]] = value
  end
end

function Proxy.export (proxy)
  assert (getmetatable (proxy) == Proxy)
  local layer    = proxy.__layer
  local keys     = proxy.__keys
  local current  = layer.__data
  for i = 1, #keys do
    current = current [keys [i]]
    assert (type (current) == "table" and getmetatable (current) ~= Reference)
  end
  return current
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

function Proxy.get (proxy, no_resolve)
  assert (getmetatable (proxy) == Proxy)
  local _, r = Proxy.apply (proxy, no_resolve) ()
  return r
end

function Proxy.__lt (lhs, rhs)
  assert (getmetatable (lhs) == Proxy)
  assert (getmetatable (rhs) == Proxy)
  local parents = Proxy.refines (rhs)
  for i = 1, #parents-1 do -- last parent is self
    if parents [i] == lhs then
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

Proxy.depends = c3.new {
  cache      = false,
  superclass = function (proxy)
    assert (getmetatable (proxy) == Proxy)
    return proxy.__layer.__data [Proxy.keys.depends]
  end,
}

Proxy.refines = c3.new {
  cache      = false,
  superclass = function (proxy)
    assert (getmetatable (proxy) == Proxy)
    local result  = {}
    local refines = proxy [Proxy.keys.refines]
    if not refines then
      return result
    end
    for i = 1, Proxy.size (refines) do
      assert (getmetatable (refines [i]) == Proxy)
      result [i] = refines [i]
    end
    return result
  end,
}

function Proxy.apply (p, no_resolve)
  assert (getmetatable (p) == Proxy)
  local coroutine = coromake ()
  local seen      = {}
  local noback    = {}
  local function perform (proxy)
    assert (getmetatable (proxy) == Proxy)
    if seen [proxy] then
      return nil
    end
    seen [proxy] = true
    local keys   = proxy.__keys
    -- 1. Search in all layers:
    local layers  = Proxy.depends (proxy.__layer.__root)
    for i = #layers, 1, -1 do
      local current = layers [i].__layer.__data
      for j = 1, #keys do
        current = current [keys [j]]
        if getmetatable (current) == Reference then
          if not (j == #keys and no_resolve) then
            local referenced = Reference.resolve (current, proxy)
            if not referenced then
              current = nil
              break
            end
            for k = j+1, #keys do
              referenced = Proxy.sub (referenced, keys [k])
            end
            return perform (referenced)
          end
        end
        if j ~= #keys and type (current) ~= "table" then
          current = nil
          break
        end
      end
      if current ~= nil then
        coroutine.yield (proxy, current)
      end
    end
    -- 2. Do not search in parents within special keys:
    local special = keys_of (Proxy.keys, Proxy.specials)
    for i = 1, #keys do
      local key = keys [i]
      if special [key] then
        return
      end
    end
    -- 3. Search in parents:
    local current = proxy
    for i = #keys, 0, -1 do
      local refines = Proxy.refines (current)
      for j = #refines-1, 1, -1 do
        local refined = refines [j]
        if not noback [refines [j]] then
          local back = noback [refines [j]]
          noback [refines [j]] = true
          for k = i+1, #keys do
            refined = Proxy.sub (refined, keys [k])
          end
          perform (refined)
          noback [refines [j]] = back
        end
      end
      current = current.__parent
    end
    -- 4. Search default:
    current = proxy.__parent
    for i = #keys-2, 0, -1 do
      current = current.__parent
      local c = Proxy.sub (current, Proxy.specials.default)
      for j = i+2, #keys do
        c = Proxy.sub (c, keys [j])
      end
      perform (c)
    end
  end
  return coroutine.wrap (function ()
    perform (p)
  end)
end

function Proxy.__len (proxy)
  assert (getmetatable (proxy) == Proxy)
  local cache = Layer.caches.len
  if cache [proxy] then
    return cache [proxy]
  end
  local result = {}
  for _, t in Proxy.apply (proxy) do
    if type (t) == "table" and getmetatable (t) ~= Reference then
      for k in pairs (t) do
        if type (k) == "number" and proxy [k] ~= nil then
          result [k] = true
        end
      end
    end
  end
  cache [proxy] = #result
  return #result
end

Proxy.size = Proxy.__len

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
  local coroutine = coromake ()
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

Proxy.ipairs = Proxy.__ipairs

function Proxy.__pairs (proxy, except)
  assert (getmetatable (proxy) == Proxy)
  local cache = Layer.caches.ipairs
  if cache [proxy] then
    return coroutine.wrap (function ()
      for k, v in pairs (cache [proxy]) do
        coroutine.yield (k, v)
      end
    end)
  end
  local coroutine = coromake ()
  except = except or keys_of (Proxy.keys, Proxy.specials)
  return coroutine.wrap (function ()
    local cached = {}
    for p, t in Proxy.apply (proxy) do
      if p == proxy then
        if type (t) == "table" then
          for k in pairs (t) do
            if cached [k] == nil and except [k] == nil and proxy [k] ~= nil then
              cached [k] = proxy [k]
              coroutine.yield (k, proxy [k])
            end
          end
        end
      else
        for k in Proxy.__pairs (p, except) do
          if cached [k] == nil then
            cached [k] = proxy [k]
            coroutine.yield (k, proxy [k])
          end
        end
      end
    end
    cache [proxy] = cached
  end)
end

Proxy.pairs = Proxy.__pairs

Proxy.new = Layer.__new

function Proxy.flatten (proxy)
  assert (getmetatable (proxy) == Proxy)
--  local special     = special_keys ()
  local equivalents = {}
  local function f (p)
    if getmetatable (p) ~= Proxy then
      return p
    elseif equivalents [p] then
      return equivalents [p]
    end
    local result = {}
    equivalents [p] = result
    for k in Proxy.__pairs (p, {}) do
      local r = Proxy.get (Proxy.sub (p, k), true)
      if getmetatable (r) == Reference then
        result [f (k)] = r
      else
        result [f (k)] = f (p [k])
      end
    end
    return result
  end
  return Layer.__new {
    name = "flattened:" .. tostring (proxy.__layer.__name),
    data = f (proxy),
  }
end

Reference.memo = setmetatable ({}, IgnoreValues)

function Reference.new (from)
  from = from or false
  local found = Reference.memo [from]
  if found then
    return found
  end
  local result = setmetatable ({
    __from   = from,
    __keys   = {},
    __memo   = setmetatable ({}, IgnoreValues),
    __parent = false,
  }, Reference)
  Reference.memo [from] = result
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
  if not reference.__from then -- absolute
    local current = proxy.__layer.__root
    local keys    = reference.__keys
    for i = 1, #keys do
      current = Proxy.sub (current, keys [i])
    end
    return current
  else -- relative
    local special = keys_of (Proxy.keys)
    local current = proxy.__layer.__root
    for i = 1, #proxy.__keys-1 do
      local key = proxy.__keys [i]
      if special [key] then
        break
      end
      current = current [key]
    end
    while current do
      if current [Proxy.specials.label] == reference.__from then
        local rkeys = reference.__keys
        for i = 1, #rkeys do
          current = Proxy.sub (current, rkeys [i])
        end
        return current
      end
      current = current.__parent
    end
    return nil
  end
end

function Reference.__serialize (reference)
  assert (getmetatable (reference) == Reference)
  return {
    __reference = true,
    from        = reference.__from,
    unpack (reference.__keys),
  }
end

function Reference.__tostring (reference)
  assert (getmetatable (reference) == Reference)
  local result = {}
  result [1] = tostring (reference.__from)
  result [2] = "->"
  local keys = reference.__keys
  for i = 1, #keys do
    result [i+2] = "[" .. totypedstring (keys [i]) .. "]"
  end
  return table.concat (result, " ")
end

Proxy.reference = Reference.new

Proxy.clear_caches = Layer.clear_caches

Layer.clear_caches ()

return Proxy
