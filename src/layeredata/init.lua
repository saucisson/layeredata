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

-- local IgnoreNone   = {}
local IgnoreKeys   = { __mode = "k"  }
local IgnoreValues = { __mode = "v"  }
local IgnoreAll    = { __mode = "kv" }

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

-- ----------------------------------------------------------------------
-- ## Layers
-- ----------------------------------------------------------------------

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

Layer.coroutine  = Coromake ()
Layer.hidden     = setmetatable ({}, IgnoreKeys  )
Layer.loaded     = setmetatable ({}, IgnoreValues)
Layer.children   = setmetatable ({}, IgnoreKeys  )
Layer.references = setmetatable ({}, IgnoreKeys  )

function Layer.new (t)
  assert (t == nil or type (t) == "table")
  local layer = setmetatable ({}, Layer)
  Layer.hidden [layer] = {
    name      = t and t.name or Uuid (),
    data      = {},
    observers = {},
  }
  local proxy = Proxy    .new (layer)
  local ref   = Reference.new (proxy)
  Layer.hidden [layer].proxy = proxy
  return proxy, ref
end

function Layer.__tostring (layer)
  assert (getmetatable (layer) == Layer)
  return "layer:" .. tostring (Layer.hidden [layer].name)
end

function Layer.require (name)
  local loaded = Layer.loaded [name]
  if loaded then
    return loaded, Reference.new (loaded)
  else
    local layer, ref = Layer.new {
      name = name,
    }
    require (name) (Layer, layer, ref)
    Layer.loaded [name] = layer
    return layer, ref
  end
end

function Layer.clear ()
  Layer.caches = {
    index  = setmetatable ({}, IgnoreKeys),
    pairs  = setmetatable ({}, IgnoreKeys),
    ipairs = setmetatable ({}, IgnoreKeys),
    len    = setmetatable ({}, IgnoreKeys),
    check  = setmetatable ({}, IgnoreKeys),
    labels = setmetatable ({}, IgnoreKeys),
    exists = setmetatable ({}, IgnoreKeys),
  }
end

function Layer.dump (layer)
  assert (getmetatable (layer) == Layer
       or getmetatable (layer) == Proxy and #Layer.hidden [layer].keys == 0)
  if getmetatable (layer) == Proxy then
    layer = Layer.hidden [layer].layer
  end
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
      local reference = Layer.hidden [x]
      local result = "Layer.reference ("
        .. (reference.from and string.format ("%q", reference.from) or tostring (reference.from))
        .. ")"
      for _, y in ipairs (reference.keys) do
        result = result .. " [" .. convert (y) .. "]"
      end
      return result
    elseif getmetatable (x) == Proxy then
      assert (not is_key)
      local proxy  = Layer.hidden [x]
      local result = "Layer.require " .. string.format ("%q", proxy.layer.name)
      for _, y in ipairs (proxy.keys) do
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
return function (Layer, layer, ref)
{{{LOCALS}}}
  Layer.Proxy.replacewith (layer, {{{BODY}}})
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
  result = result:gsub ("{{{NAME}}}"  , string.format ("%q", Layer.hidden [layer].name))
  result = result:gsub ("{{{LOCALS}}}", table.concat (locals, "\n"))
  local body = convert (Layer.hidden [layer].data, false, "    "):gsub ("%%", "%%%%")
  result = result:gsub ("{{{BODY}}}"  , body)
  return result
end

function Layer.merge (source, target)
  assert (getmetatable (source) == Layer)
  assert (getmetatable (target) == Layer)
  local function iterate (s, t)
    assert (type (s) == "table")
    assert (type (t) == "table")
    for k, v in pairs (s) do
      if k == Layer.key.checks
      or k == Layer.key.defaults
      or k == Layer.key.labels
      or k == Layer.key.messages
      or k == Layer.key.refines then
        t [k] = {}
        for kk, vv in pairs (v) do
          t [k] [kk] = vv
        end
      elseif getmetatable (v) == Reference
      or     getmetatable (v) == Proxy
      or     type (v) ~= "table"
      then
        t [k] = v
      elseif type (t [k]) == "table" then
        iterate (v, t [k])
      else
        t [k] = {}
        iterate (v, t [k])
      end
    end
  end
  iterate (Layer.hidden [source].data, Layer.hidden [target].data)
end

-- ----------------------------------------------------------------------
-- ## Observers
-- ----------------------------------------------------------------------

local Observer = {}
Observer.__index = Observer

function Layer.observe (proxy, f)
  assert (getmetatable (proxy) == Proxy)
  assert (type (f) == "function" or (getmetatable (f) and getmetatable (f).__call))
  local layer    = Layer.hidden [proxy].layer
  local observer = setmetatable ({}, Observer)
  Layer.hidden [observer] = {
    layer   = layer,
    handler = f,
  }
  return observer:enable ()
end

function Observer.enable (observer)
  assert (getmetatable (observer) == Observer)
  local layer = Layer.hidden [observer].layer
  layer.observers [observer] = true
  return observer
end

function Observer.disable (observer)
  assert (getmetatable (observer) == Observer)
  local layer = Layer.hidden [observer].layer
  layer.observers [observer] = nil
  return observer
end

-- ----------------------------------------------------------------------
-- ## Proxies
-- ----------------------------------------------------------------------

function Proxy.new (layer)
  assert (getmetatable (layer) == Layer)
  local proxy = setmetatable ({}, Proxy)
  Layer.hidden [proxy] = {
    layer  = layer,
    keys   = {},
    parent = false,
  }
  return proxy
end

function Proxy.__tostring (proxy)
  assert (getmetatable (proxy) == Proxy)
  local result = {}
  local hidden = Layer.hidden [proxy]
  local keys   = hidden.keys
  result [1]   = tostring (hidden.layer)
  for i = 1, #keys do
    result [i+1] = "[" .. tostring (keys [i]) .. "]"
  end
  return table.concat (result, " ")
end

function Proxy.child (proxy, key)
  assert (getmetatable (proxy) == Proxy)
  assert (key ~= nil)
  local found = Layer.children [proxy]
            and Layer.children [proxy] [key]
  if found then
    return found
  end
  local result = setmetatable ({}, Proxy)
  local hidden = Layer.hidden [proxy]
  local keys   = {}
  for i, k in ipairs (hidden.keys) do
    keys [i] = k
  end
  keys [#keys+1] = key
  Layer.hidden [result] = {
    layer  = hidden.layer,
    keys   = keys,
    parent = proxy,
  }
  Layer.children [proxy] = Layer.children [proxy]
                        or setmetatable ({}, IgnoreValues)
  Layer.children [proxy] [key] = result
  return result
end

function Proxy.check (proxy)
  assert (getmetatable (proxy) == Proxy)
  local cache = Layer.caches.check
  if cache [proxy] then
    return
  end
  cache [proxy] = true
  local hidden = Layer.hidden [proxy]
  for _, key in ipairs (hidden.keys) do
    if getmetatable (key) == Key then
      return
    end
  end
  local checks = proxy [Layer.key.checks]
  if not checks then
    return
  end
  local messages = Proxy.rawget (Proxy.child (proxy, Layer.key.messages)) or {}
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
  proxy = Proxy.child (proxy, key)
  local cache  = Layer.caches.index
  local cached = cache [proxy]
  if cached == Layer.tag.null
  or cached == Layer.tag.computing then
    return nil
  elseif cached ~= nil then
    return cached
  end
  cache [proxy] = Layer.tag.computing
  local result
  if Proxy.exists (proxy) then
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
  end
  if result == nil then
    cache [proxy] = Layer.tag.null
  else
    cache [proxy] = result
  end
  if getmetatable (result) == Proxy then
    Proxy.check (result)
  end
  return result
end

function Proxy.rawget (proxy)
  assert (getmetatable (proxy) == Proxy)
  local hidden  = Layer.hidden [proxy]
  local layer   = Layer.hidden [hidden.layer]
  local current = layer.data
  local keys    = hidden.keys
  for _, key in ipairs (keys) do
    if  type (current) == "table"
    and getmetatable (current) ~= Proxy
    and getmetatable (current) ~= Reference then
      current = current [key]
    else
      current = nil
    end
  end
  return current
end

function Proxy.__newindex (proxy, key, value)
  assert (getmetatable (proxy) == Proxy)
  assert ( type (key) ~= "table"
        or getmetatable (key) == Proxy
        or getmetatable (key) == Reference
        or getmetatable (key) == Key)
  local hidden  = Layer.hidden [proxy]
  local layer   = Layer.hidden [hidden.layer]
  local current = layer.data
  local keys    = hidden.keys
  local has_messages = key == Layer.key.messages
  for _, k in ipairs (keys) do
    if k == Layer.key.messages then
      has_messages = true
    end
    if current [k] == nil then
      current [k] = {}
    end
    current = current [k]
  end
  current [key] = value
  if not has_messages then
    Layer.clear (proxy)
  end
  for observer in pairs (layer.observers) do
    observer (proxy, key, value)
  end
end

function Proxy.replacewith (proxy, value)
  assert (getmetatable (proxy) == Proxy)
  Layer.clear (proxy)
  local hidden = Layer.hidden [proxy]
  local layer  = Layer.hidden [hidden.layer]
  local keys   = hidden.keys
  if #keys == 0 then
    layer.data = value
  else
    hidden.parent [keys [#keys]] = value
  end
end

function Proxy.has_meta (proxy)
  assert (getmetatable (proxy) == Proxy)
  local hidden = Layer.hidden [proxy]
  for _, key in ipairs (hidden.keys) do
    if key == Layer.key.meta then
      return true
    end
  end
  return false
end

function Proxy.exists (proxy)
  assert (getmetatable (proxy) == Proxy)
  local cache = Layer.caches.exists
  if cache [proxy] ~= nil then
    return cache [proxy]
  end
  local result = Proxy.equivalents (proxy, {
    exists = true,
  }) () ~= nil
  cache [proxy] = result
  return result
end

function Proxy.equivalents (proxy, options)
  assert (getmetatable (proxy) == Proxy)
  assert (options == nil or type (options) == "table")
  options = options or {}
  local seen      = {}
  local coroutine = Coromake ()
  local function iterate (where, current)
    if seen [current] and seen [current] [where] then
      return nil
    end
    seen [current] = seen [current] or {}
    seen [current] [where] = true
    local current_hidden = Layer.hidden [current]
    local where_hidden   = Layer.hidden [where]
    local raw  = Proxy.rawget (where)
    if (options.all or raw ~= nil) and current == where then
      coroutine.yield (where, raw)
    end
    local default_root = proxy
    for _ = #where_hidden.keys+1, #current_hidden.keys do
      default_root = getmetatable (default_root) == Proxy
                 and Layer.hidden [default_root].parent
                  or default_root
    end
    local parent_root    = Layer.hidden [default_root].parent
                        or default_root
    local search_parent  = true
    local search_default = true
    for _, key in ipairs (where_hidden.keys) do
      if key == Layer.key.messages
      or key == Layer.key.defaults
      or key == Layer.key.refines then
        search_parent  = false
        search_default = false
      end
    end
    if search_parent then
      local refines = type (raw) == "table"
                  and getmetatable (raw) ~= Proxy
                  and getmetatable (raw) ~= Reference
                  and raw [Layer.key.refines]
      for _, x in ipairs (refines or {}) do
        while x and getmetatable (x) == Reference do
          x = Reference.resolve (x, parent_root)
        end
        if getmetatable (x) == Proxy then
          for j = #where_hidden.keys+1, #current_hidden.keys do
            x = Proxy.child (x, current_hidden.keys [j])
          end
          iterate (x, x)
        end
      end
    end
    if options.exists and where == current_hidden.parent then
      search_default = false
    else
      search_default = search_default
                   and #where_hidden.keys < #current_hidden.keys
                   and getmetatable (current_hidden.keys [#where_hidden.keys+1]) ~= Key
                   and Proxy.exists (where)
    end
    if search_default then
      local rawp     = Proxy.rawget (where)
      local defaults = type (rawp) == "table"
                   and rawp [Layer.key.defaults]
      for _, x in ipairs (defaults or {}) do
        while x and getmetatable (x) == Reference do
          x = Reference.resolve (x, default_root)
        end
        if getmetatable (x) == Proxy then
          for j = #where_hidden.keys+2, #current_hidden.keys do
            x = Proxy.child (x, current_hidden.keys [j])
          end
          iterate (x, x)
        end
      end
    end
    if where_hidden.parent then
      iterate (where_hidden.parent, current)
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

function Proxy.project (proxy, what)
  assert (getmetatable (proxy) == Proxy)
  assert (getmetatable (what ) == Proxy)
  local lhs_proxy = Layer.hidden [proxy]
  local rhs_proxy = Layer.hidden [what]
  local rhs_layer = Layer.hidden [rhs_proxy.layer]
  local result    = rhs_layer.proxy
  for _, key in ipairs (lhs_proxy.keys) do
    result = Proxy.child (result, key)
  end
  return result
end

function Proxy.parent (proxy)
  assert (getmetatable (proxy) == Proxy)
  local hidden = Layer.hidden [proxy]
  return hidden.parent
end

function Proxy.__len (proxy)
  assert (getmetatable (proxy) == Proxy)
  local cache = Layer.caches.len
  if cache [proxy] then
    return cache [proxy]
  end
  for i = 1, math.huge do
    if not Proxy.exists (Proxy.child (proxy, i)) then
      cache [proxy] = i-1
      return i-1
    end
  end
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
      local result = Proxy.equivalents (Proxy.child (proxy, i)) ()
      if result == nil then
        break
      end
      result = proxy [i]
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
    for _, current in Proxy.equivalents (proxy) do
      while getmetatable (current) == Reference do
        current = Reference.resolve (current, proxy)
      end
      local iter
      if getmetatable (current) == Proxy then
        iter = Proxy.__pairs
      elseif type (current) == "table" then
        iter = pairs
      end
      if iter then
        for k in iter (current) do
          if  cached [k] == nil and current [k] ~= nil
          and getmetatable (k) ~= Layer.Key then
            cached [k] = proxy [k]
            coroutine.yield (k, proxy [k])
          end
        end
      end
    end
    cache [proxy] = cached
  end)
end

function Reference.new (target)
  local found = Layer.references [target]
  if found then
    return found
  end
  if type (target) == "string" then
    local result = setmetatable ({}, Reference)
    Layer.hidden [result] = {
      from = target,
      keys = {},
    }
    Layer.references [target] = result
    return result
  elseif getmetatable (target) == Proxy then
    local label = Uuid ()
    Proxy.child (target, Layer.key.labels) [label] = true
    local result = setmetatable ({}, Reference)
    Layer.hidden [result] = {
      from = label,
      keys = {},
    }
    Layer.references [target] = result
    return result
  else
    assert (false)
  end
end

function Reference.__tostring (reference)
  assert (getmetatable (reference) == Reference)
  local hidden = Layer.hidden [reference]
  local result = {}
  result [1] = tostring (hidden.from)
  result [2] = "->"
  for i, key in ipairs (hidden.keys) do
    result [i+2] = "[" .. tostring (key) .. "]"
  end
  return table.concat (result, " ")
end

function Reference.__index (reference, key)
  assert (getmetatable (reference) == Reference)
  local found = Layer.children [reference]
            and Layer.children [reference] [key]
  if found then
    return found
  end
  local hidden = Layer.hidden [reference]
  local keys = {}
  for i, k in ipairs (hidden.keys) do
    keys [i] = k
  end
  keys [#keys+1] = key
  local result = setmetatable ({}, Reference)
  Layer.hidden [result] = {
    parent = reference,
    from   = hidden.from,
    keys   = keys,
  }
  Layer.children [reference] = Layer.children [reference]
                            or setmetatable ({}, IgnoreValues)
  Layer.children [reference] [key] = result
  return result
end

function Reference.resolve (reference, proxy)
  assert (getmetatable (reference) == Reference)
  assert (getmetatable (proxy    ) == Proxy    )
  local cache  = Layer.caches.labels
  local cached = cache [proxy]
             and cache [proxy] [reference]
  if cached == Layer.tag.null or cached == Layer.tag.computing then
    return nil
  elseif cached then
    return cached
  end
  local ref_hidden = Layer.hidden [reference]
  local current = proxy
  do
    while current do
      local labels = current
      labels = Proxy.child (labels, Layer.key.labels)
      labels = Proxy.child (labels, ref_hidden.from)
      if Proxy.equivalents (labels) () then
        break
      end
      current = Layer.hidden [current].parent
    end
    if not current then
      cache [proxy] = cache [proxy] or setmetatable ({}, IgnoreAll)
      cache [proxy] [reference] = Layer.tag.null
      return nil
    end
  end
  for _, key in ipairs (ref_hidden.keys) do
    while getmetatable (current) == Reference do
      current = Reference.resolve (current, proxy)
    end
    if getmetatable (current) ~= Proxy then
      cache [proxy] = cache [proxy] or setmetatable ({}, IgnoreAll)
      cache [proxy] [reference] = Layer.tag.null
      return nil
    end
    current = current [key]
  end
  cache [proxy] = cache [proxy] or setmetatable ({}, IgnoreAll)
  cache [proxy] [reference] = current
  return current
end

Layer.Proxy     = Proxy
Layer.Reference = Reference
Layer.Key       = Key
Layer.reference = Reference.new

-- Lua 5.1 compatibility:
Layer.len    = Proxy.__len
Layer.pairs  = Proxy.__pairs
Layer.ipairs = Proxy.__ipairs

Layer.clear ()

return Layer
