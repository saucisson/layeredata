local coromake = require "coroutine.make"
local c3       = require "c3"
local serpent  = require "serpent"

local Layer              = {}
local Proxy              = {}
local IgnoreKeys         = {}
IgnoreKeys.__mode        = "k"
local IgnoreValues       = {}
IgnoreValues.__mode      = "v"

Proxy.keys = {
  depends = "__depends__",
  refines = "__refines__",
  value   = "__value__",
  special = nil,
}

local function totypedstring (x)
  return serpent.line (x, {
    indent   = "  ",
    comment  = false,
    sortkeys = true,
    compact  = false,
  })
end

local pack   = table.pack   or function (...) return { ... } end
local unpack = table.unpack or unpack

function Layer.__new (t)
  assert (type (t) == "table")
  local layer = setmetatable ({
    __name    = t.name,
    __data    = Layer.import (t.data),
    __root    = false,
    __proxies = setmetatable ({}, IgnoreValues),
  }, Layer)
  local proxy = Proxy.__new (layer)
  layer.__root = proxy
  return proxy
end

function Layer.import (data)
  if type (data) ~= "table" then
    return data
  elseif getmetatable (data) == Proxy then
    return data
  elseif data.__proxy then
    return Proxy.__new (data)
  else
    local updates = {}
    for key, value in pairs (data) do
      if type (key  ) == "table" then
        updates [key] = Layer.import (key  )
      end
      if type (value) == "table" then
        data    [key] = Layer.import (value)
      end
    end
    for old_key, new_key in pairs (updates) do
      data [old_key], data [new_key] = nil, data [old_key]
    end
    return data
  end
end

function Layer.__tostring (layer)
  assert (getmetatable (layer) == Layer)
  return "layer:" .. totypedstring (layer.__name)
end

local default_proxies = setmetatable ({}, IgnoreValues)

function Proxy.__new (t)
  if getmetatable (t) == Layer then
    return setmetatable ({
      __keys   = {},
      __layer  = t,
      __memo   = t.__proxies,
      __parent = false,
    }, Proxy)
  elseif t.__proxy then
    return setmetatable ({
      __keys   = t,
      __layer  = false,
      __memo   = default_proxies,
      __parent = false,
    }, Proxy)
  else
    assert (false)
  end
end

Proxy.placeholder = setmetatable ({
  __keys   = {},
  __layer  = false,
  __memo   = default_proxies,
  __parent = false,
}, Proxy)

function Proxy.__serialize (proxy)
  assert (getmetatable (proxy) == Proxy)
  return {
    __proxy = true,
    __layer = proxy.__layer
          and proxy.__layer.__name
           or false,
    unpack (proxy.__keys),
  }
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

function Proxy.__index (proxy, key)
  assert (getmetatable (proxy) == Proxy)
  if key == Proxy.keys.special or key == Proxy.keys.value then
    return Proxy.value (proxy)
  end
  local proxies = proxy.__memo
  local found   = proxies [key]
  if found then
    return found
  end
  local nkeys
  if #proxy.__keys < 100 then
    nkeys = pack (unpack (proxy.__keys))
  else
    nkeys = {}
    for i = 1, #proxy.__keys do
      nkeys [i] = proxy.__keys [i]
    end
  end
  nkeys [#nkeys+1] = key
  local result = setmetatable ({
    __layer  = proxy.__layer,
    __keys   = nkeys,
    __memo   = setmetatable ({}, IgnoreValues),
    __parent = proxy,
  }, Proxy)
  proxies [key] = result
  return result
end

function Proxy.__newindex (proxy, key, value)
  assert (getmetatable (proxy) == Proxy)
  assert (type (key) ~= "table" or getmetatable (key) == Proxy)
  local layer = proxy.__layer
  proxy = Proxy.dereference (proxy)
  key   = Layer.import (key  )
  value = Layer.import (value)
  if type (layer.__data) ~= "table"
  or getmetatable (layer.__data) == Proxy then
    layer.__data = {
      [Proxy.keys.value] = layer.__data,
    }
  end
  local current = layer.__data
  local keys    = proxy.__keys
  for i = 1, #keys do
    local ikey = keys [i]
    if type (current [ikey]) ~= "table"
    or getmetatable (current [ikey]) == Proxy then
      current [ikey] = {
        [Proxy.keys.value] = current [ikey],
      }
    end
    current = current [ikey]
  end
  if key == Proxy.keys.special then
    current [Proxy.keys.value] = value
  else
    current [key] = value
  end
end

function Proxy.replacewith (proxy, x)
  assert (getmetatable (proxy) == Proxy)
  local layer = proxy.__layer
  proxy = Proxy.dereference (proxy)
  x     = Layer.import (x)
  if type (layer.__data) ~= "table" then
    layer.__data = {
      [Proxy.keys.value] = layer.__data,
    }
  end
  local keys    = proxy.__keys
  if #keys == 0 then
    layer.__data = x
  else
    local current = layer.__data
    for i = 1, #keys-1 do
      if type (current [keys [i]]) ~= "table" then
        current [keys [i]] = {
          [Proxy.keys.value] = current [keys [i]],
        }
      end
      current = current [keys [i]]
    end
    current [keys [#keys]] = x
  end
end

function Proxy.export (proxy)
  assert (getmetatable (proxy) == Proxy)
  local layer    = proxy.__layer
  local keys     = proxy.__keys
  local current  = layer.__data
  for i = 1, #keys do
    if type (current) ~= "table" then
      return nil
    end
    current = current [keys [i]]
  end
  return current
end

function Proxy.__call (proxy, n)
  assert (getmetatable (proxy) == Proxy)
  assert (n == nil or type (n) == "number")
  for _ = 1, n or 1 do
    proxy = proxy.__dereference
  end
  return proxy
end

function Proxy.is_reference (proxy)
  assert (getmetatable (proxy) == Proxy)
  local target = Proxy.value (proxy)
  return getmetatable (target) == Proxy
end

function Proxy.instantiate (proxy, layer)
  assert (getmetatable (proxy) == Proxy)
  local keys   = proxy.__keys
  local result = layer
  for i = 1, #keys do
    result = result [keys [i]]
  end
  return result
end

function Proxy.dereference (proxy)
  assert (getmetatable (proxy) == Proxy)
  local root = proxy.__layer.__root
  repeat
    local current = root
    local keys    = proxy.__keys
    local changed = false
    for i = 1, #keys do
      local key = keys [i]
      if key == "__dereference" then
        local p = Proxy.value (current)
        if getmetatable (p) ~= Proxy then
          error "not a reference"
        end
        changed = true
        proxy   = root
        for j = 1, #p.__keys do
          proxy = proxy [p.__keys [j]]
        end
        for j = i+1, #keys do
          proxy = proxy [keys [j]]
        end
        break
      else
        current = current [key]
      end
    end
  until not changed
  return proxy
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

function Proxy.__lt (lhs, rhs)
  assert (getmetatable (lhs) == Proxy)
  assert (getmetatable (rhs) == Proxy)
  lhs = Proxy.instantiate (lhs, rhs.__layer.__root)
  lhs = Proxy.dereference (lhs)
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
    if type (proxy.__layer.__data) == "table" then
      return proxy.__layer.__data [Proxy.keys.depends]
    end
  end,
}

Proxy.refines = c3.new {
  cache      = false,
  superclass = function (proxy)
    assert (getmetatable (proxy) == Proxy)
    proxy = Proxy.dereference (proxy)
    proxy = proxy [Proxy.keys.refines]
    local result  = {}
    for i = 1, Proxy.size (proxy) do
      local p = proxy [i] [Proxy.keys.special]
      assert (getmetatable (p) == Proxy)
      p = Proxy.instantiate (p, proxy.__layer.__root)
      p = Proxy.dereference (p)
      result [i] = p
    end
    return result
  end,
}

function Proxy.apply (p)
  assert (getmetatable (p) == Proxy)
  local coroutine = coromake ()
  local seen      = {}
  local noback    = {}
  local layer     = p.__layer.__root
  local function perform (proxy)
    assert (getmetatable (proxy) == Proxy)
    proxy = Proxy.instantiate (proxy, layer)
    proxy = Proxy.dereference (proxy)
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
        local key = keys [j]
        if type (current) ~= "table"
        or getmetatable (current) == Proxy then
          current = nil
          break
        end
        current = current [key]
      end
      if current ~= nil then
        coroutine.yield (proxy, current)
      end
    end
    -- 2. Do not search in parents within special keys:
    local special = {}
    for _, k in pairs (Proxy.keys) do
      special [k] = true
    end
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
            refined = refined [keys [k]]
          end
          perform (refined)
          noback [refines [j]] = back
        end
      end
      current = current.__parent
    end
  end
  return coroutine.wrap (function ()
    perform (p)
  end)
end

function Proxy.__len (proxy)
  assert (getmetatable (proxy) == Proxy)
  local result    = {}
  for _, t in Proxy.apply (proxy) do
    if  type (t) == "table"
    and getmetatable (t) ~= Proxy then
      for k in pairs (t) do
        if type (k) == "number" then
          result [k] = true
        end
      end
    end
  end
  return #result
end

Proxy.size = Proxy.__len

function Proxy.__ipairs (proxy)
  assert (getmetatable (proxy) == Proxy)
  local coroutine = coromake ()
  return coroutine.wrap (function ()
    for i = 1, math.huge do
      local p = proxy [i]
      if not Proxy.exists (p) then
        break
      end
      coroutine.yield (i, p)
    end
  end)
end

Proxy.ipairs = Proxy.__ipairs

function Proxy.__pairs (proxy)
  assert (getmetatable (proxy) == Proxy)
  local coroutine = coromake ()
  local seen      = {}
  local special   = {}
  for _, k in pairs (Proxy.keys) do
    special [k] = true
  end
  return coroutine.wrap (function ()
    for _, t in Proxy.apply (proxy) do
      if  type (t) == "table"
      and getmetatable (t) ~= Proxy then
        for k in pairs (t) do
          if  not seen [k]
          and not special [k] then
            seen [k] = true
            coroutine.yield (k, proxy [k])
          end
        end
      end
    end
  end)
end

Proxy.pairs = Proxy.__pairs

function Proxy.value (proxy)
  assert (getmetatable (proxy) == Proxy)
  for _, t in Proxy.apply (proxy) do
    if getmetatable (t) == Proxy then
      return Proxy.instantiate (t, proxy.__layer.__root)
    elseif type (t) ~= "table" then
      return t
    elseif t [Proxy.keys.value] then
      return t [Proxy.keys.value]
    end
  end
end

function Proxy.exists (proxy)
  assert (getmetatable (proxy) == Proxy)
  return Proxy.apply (proxy) (proxy) ~= nil
end

Proxy.new = Layer.__new

function Proxy.flatten (proxy)
  assert (getmetatable (proxy) == Proxy)
  local special   = {}
  for _, k in pairs (Proxy.keys) do
    special [k] = true
  end
  local equivalents = {}
  local seen        = {}
  local layer       = proxy.__layer.__root
  local function f (p)
    if getmetatable (p) ~= Proxy then
      return p
    end
    p = Proxy.instantiate (p, layer)
    p = Proxy.dereference (p)
    local result = {}
    if equivalents [p] then
      result = equivalents [p]
    else
      equivalents [p] = result
    end
    for pp, t in Proxy.apply (p) do
      if not seen [pp] then
        if  type (t) == "table"
        and getmetatable (t) ~= Proxy then
          local keys     = {}
          local previous = seen [pp]
          seen [pp] = true
          for k in pairs (t) do
            if  not keys    [k]
            and not special [k] then
              result [f (k)] = f (p [k])
              keys [k] = true
            end
          end
          seen [pp] = previous
        end
      end
    end
    result.__value__ = p.__value__
    local only_value = result.__value__ ~= nil
    for k in pairs (result) do
      only_value = only_value and k == "__value__"
    end
    if only_value then
      result = result.__value__
    end
    return result
  end
  local function g (t)
    if type (t) == "table" then
      for k, v in pairs (t) do
        if getmetatable (v) == Proxy then
          t [k] = equivalents [v]
        end
      end
    end
    return t
  end
  return g (f (proxy))
end

return Proxy
