local coromake = require "coroutine.make"
local c3       = require "c3"
local serpent  = require "serpent"
local yaml     = require "yaml"

return function (special_keys, debug)
  assert (special_keys == nil or type (special_keys) == "table")
  special_keys = special_keys or {}

  local Layer              = setmetatable ({}, {
    __tostring = function () return "Layer" end
  })
  local Proxy              = setmetatable ({}, {
    __tostring = function () return "Proxy" end
  })
  local Reference          = setmetatable ({}, {
    __tostring = function () return "Reference" end
  })
  local IgnoreKeys = {}
  if not debug then
    IgnoreKeys.__mode = "k"
  end
  local IgnoreValues = {}
  if not debug then
    IgnoreValues.__mode = "v"
  end

  Proxy.key = {
    checks   = special_keys.checks   or "__checks__",
    default  = special_keys.default  or "__default__",
    label    = special_keys.label    or "__label__",
    messages = special_keys.messages or "__messages__",
    refines  = special_keys.refines  or "__refines__",
  }

  Proxy.nocheck = {
    [Proxy.key.checks  ] = true,
    [Proxy.key.default ] = true,
    [Proxy.key.label   ] = true,
    [Proxy.key.messages] = true,
    [Proxy.key.refines ] = true,
  }

  Proxy.nodefault = {
    [Proxy.key.checks  ] = true,
    [Proxy.key.default ] = true,
    [Proxy.key.label   ] = true,
    [Proxy.key.messages] = true,
    [Proxy.key.refines ] = true,
  }

  Proxy.norefines = {
    [Proxy.key.checks  ] = true,
    [Proxy.key.label   ] = true,
    [Proxy.key.messages] = true,
    [Proxy.key.refines ] = true,
  }

  Proxy.noresolve = {
    [Proxy.key.checks  ] = true,
    [Proxy.key.default ] = true,
    [Proxy.key.label   ] = true,
    [Proxy.key.messages] = true,
    [Proxy.key.refines ] = true,
  }

  Proxy.tag = {
    null      = {},
    computing = {},
  }

  local unpack = table.unpack or unpack

  function Layer.__new (t)
    assert (type (t) == "table")
    local layer = setmetatable ({
      __name    = t.name,
      __data    = Layer.import (t.data or {}),
      __root    = false,
      __proxies = setmetatable ({}, IgnoreValues),
    }, Layer)
    local proxy = Proxy.__new (layer)
    layer.__root = proxy
    return proxy
  end

  function Layer.clear_caches (proxy)
    if debug then
      print ("Clear Caches:", proxy)
    end
    Proxy.refines:clear ()
    Layer.caches = {
      index  = setmetatable ({}, IgnoreKeys),
      pairs  = setmetatable ({}, IgnoreKeys),
      ipairs = setmetatable ({}, IgnoreKeys),
      len    = setmetatable ({}, IgnoreKeys),
      check  = setmetatable ({}, IgnoreKeys),
    }
  end

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
      return data
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
        local value = data [old_key]
        data [old_key] = nil
        data [new_key] = value
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

  function Proxy.__serialize (proxy)
    assert (getmetatable (proxy) == Proxy)
    return {
      __proxy = true,
      __layer = proxy.__layer.__name,
      unpack (proxy.__keys),
    }
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

  function Proxy.toyaml (proxy)
    assert (getmetatable (proxy) == Proxy)
    local dumped   = Proxy.dump (proxy, false)
    local ok, data = serpent.load (dumped, { safe = false })
    assert (ok)
    local bodies = {}
    local function get_body (t)
      if bodies [t] then
        return bodies [t]
      end
      local result = t
      local info = _G.debug.getinfo (t)
      if info and info.what == "Lua" then
        result = info.source ..
                 " [" .. tostring (info.linedefined) ..
                 ".." .. tostring (info.lastlinedefined) ..
                  "]"
      end
      bodies [t] = result
      return result
    end

    local function f (t)
      if type (t) == "function" then
        return get_body (t)
      elseif type (t) ~= "table" then
        return t
      end
      if #t == 1 then
        return t [1]
      end
      for k, v in pairs (t) do
        t [k] = f (v)
      end
      return t
    end
    return yaml.dump (f (data))
  end

  function Proxy.sub (proxy, key)
    assert (getmetatable (proxy) == Proxy)
    local proxies = proxy.__memo
    local found   = proxies [key]
    if not found then
      local cache = true
      local nkeys = {}
      for i = 1, #proxy.__keys do
        nkeys [i] = proxy.__keys [i]
        cache = cache and nkeys [i] ~= Proxy.key.messages
      end
      nkeys [#nkeys+1] = key
      cache = cache and key ~= Proxy.key.messages
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
    for i = 1, #proxy.__keys do
      local key = proxy.__keys [i]
      if Proxy.nocheck [key] then
        return
      end
    end
    local checks = proxy [Proxy.key.checks]
    if not checks then
      return
    end
    local messages = proxy [Proxy.key.messages]
    if not messages then
      proxy [Proxy.key.messages] = {}
      messages = proxy [Proxy.key.messages]
    end
    for _, f in Proxy.__pairs (checks) do
      assert (type (f) == "function")
      local id, message = f (proxy)
      if id ~= nil then
        messages [id] = message
      end
    end
    if Proxy.__pairs (messages) (messages) == nil then
      proxy [Proxy.key.messages] = nil
    end
  end

  local indent
  if debug then
    indent = ""
  end

  function Proxy.__index (proxy, key)
    assert (getmetatable (proxy) == Proxy)
    proxy = Proxy.sub (proxy, key)
    local cproxy = proxy
    if proxy.__cache then
      local cache  = Layer.caches.index
      local cached = cache [proxy]
      if cached == Proxy.tag.null then
        return nil
      elseif cached == Proxy.tag.computing then
        return nil
      elseif cached ~= nil then
        return cached
      end
      cache [proxy] = Proxy.tag.computing
    end
    if indent then
      print (">", indent .. tostring (proxy))
      indent = indent .. "  "
    end
    local result
    while true do
      local _, c = Proxy.apply { proxy = proxy, resolve = true, iterate = false, }
      if getmetatable (c) == Proxy then
        proxy = c
      elseif type (c) ~= "table" then
        result = c
        break
      else
        Proxy.check (proxy)
        result = proxy
        break
      end
    end
    if proxy.__cache then
      local cache = Layer.caches.index
      if result == nil then
        cache [cproxy] = Proxy.tag.null
      else
        cache [cproxy] = result
      end
    end
    if indent then
      indent = indent:sub (1, #indent-2)
--      print ("<", indent .. tostring (proxy) .. " = " .. tostring (result))
    end
    return result
  end

  function Proxy.__newindex (proxy, key, value)
    assert (getmetatable (proxy) == Proxy)
    assert (type (key) ~= "table" or getmetatable (key) == Proxy or getmetatable (key) == Reference)
    local layer = proxy.__layer
    proxy = Proxy.sub (proxy, key)
    key   = Layer.import (key  )
    value = Layer.import (value)
    local p, r = Proxy.apply { proxy = proxy, resolve = false, iterate = false, }
    if r == nil then
      p = proxy
    elseif getmetatable (r) == Reference and getmetatable (value) ~= Reference then
      p = Reference.resolve (r, proxy)
    end
    local current = layer.__data
    local keys    = p.__keys
    for i = 1, #keys-1 do
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

  function Proxy.is_reference (proxy)
    assert (getmetatable (proxy) == Proxy)
    local _, r = Proxy.apply { proxy = proxy, resolve = false, iterate = false, }
    return getmetatable (r) == Reference
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

  Proxy.refines = c3.new {
    superclass = function (proxy)
      assert (getmetatable (proxy) == Proxy)
      local result  = {}
      local refines = proxy [Proxy.key.refines]
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

--local count = 0

  function Proxy.apply (t)
    assert (getmetatable (t.proxy) == Proxy)
    local coroutine = t.iterate and coromake () or nil
    local resolve   = t.resolve ~= nil and t.resolve or not t.noresolve
    local seen      = {}
    local noback    = {}
    local function perform (proxy)
--      if count > 200 then
--        os.exit (1)
--      else
--        count = count+1
--      end
      assert (getmetatable (proxy) == Proxy)
      if seen [proxy] then
        return nil
      end
      seen [proxy] = true
      local keys   = proxy.__keys
      -- Search in current layer:
      do
        local current = proxy.__layer.__data
        for i = 1, #keys do
          current = current [keys [i]]
          if getmetatable (current) == Reference and resolve then
            assert (i == #keys)
            current = Reference.resolve (current, proxy)
            break
          elseif i ~= #keys and type (current) ~= "table" then
            current = nil
            break
          end
        end
        if current ~= nil then
          if coroutine then
            coroutine.yield (proxy, current)
          else
            return proxy, current
          end
        end
      end
      -- Search in refined:
      do
        local current = proxy.__layer.__root
        for i = 1, #keys do
          local key = keys [i]
          if Proxy.norefines [key] then
            break
          else
            current = Proxy.sub (current, key)
          end
        end
        while current do
          local refines = Proxy.refines (current)
          for i = #refines-1, 1, -1 do
            local refined = refines [i]
            if not noback [refines [i]] then
              noback [refines [i]] = true
              for j = #current.__keys+1, #keys do
                refined = Proxy.sub (refined, keys [j])
              end
              local p, c = perform (refined)
              if p and not coroutine then
                return p, c
              end
              noback [refines [i]] = nil
            end
          end
          current = current.__parent
        end
      end
      -- Search default:
      do
        local current = proxy.__layer.__root
        for i = 1, #keys do
          local key = keys [i]
          if Proxy.nodefault [key] then
            current = nil
            break
          else
            current = Proxy.sub (current, key)
          end
        end
        while current do
          local s = Proxy.sub (current, Proxy.key.default)
          for j = #current.__keys+2, #keys do
            s = Proxy.sub (s, keys [j])
          end
          local p, c = perform (s)
          if p and not coroutine then
            return p, c
          end
          current = current.__parent
        end
      end
    end
    if coroutine then
      return coroutine.wrap (function ()
        perform (t.proxy)
      end)
    else
      return perform (t.proxy)
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
    local cache = Layer.caches.pairs
    if cache [proxy] then
      return coroutine.wrap (function ()
        for k, v in pairs (cache [proxy]) do
          coroutine.yield (k, v)
        end
      end)
    end
    local coroutine = coromake ()
    return coroutine.wrap (function ()
      local cached = {}
      for p, t in Proxy.apply { proxy = proxy, resolve = true, iterate = true, } do
        if p == proxy then
          if type (t) == "table" then
            for k in pairs (t) do
              if cached [k] == nil and proxy [k] ~= nil then
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
        if k ~= Proxy.key.refines then
          local _, r = Proxy.apply { proxy = Proxy.sub (p, k), resolve = false, iterate = false }
          if getmetatable (r) == Reference then
            result [f (k)] = r
          else
            result [f (k)] = f (p [k])
          end
        end
      end
      return result
    end
    local result = f (proxy)
    return Layer.__new {
      name = "flattened:" .. tostring (proxy.__layer.__name),
      data = result,
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
      local current = proxy.__layer.__root
      for i = 1, #proxy.__keys-1 do
        local key = proxy.__keys [i]
        if Proxy.noresolve [key] or current [key] == nil then
          break
        end
        current = current [key]
      end
      while current do
        if current [Proxy.key.label] == reference.__from then
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
      result [i+2] = "[" .. tostring (keys [i]) .. "]"
    end
    return table.concat (result, " ")
  end

  Proxy.reference    = Reference.new
  Proxy.clear_caches = Layer.clear_caches
  Layer.clear_caches ()

  return Proxy
end
