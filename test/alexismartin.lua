local Layer = require "layeredata"
local Serpent = require "serpent"

local function dump (x)
  return Serpent.dump (x, {
    indent   = "  ",
    comment  = false,
    sortkeys = true,
    compact  = false,
  })
end

local Proxy  = require "layeredata"
local layer1 = Proxy.new { name = "layer1" }
local layer2 = Proxy.new { name = "layer2" }
local _      = Proxy.placeholder

layer1.type1 = {
  type1_type = {
    set_type = {},
    set = {
      object_1 = {
        [Layer.key.refines] = {
          _.type1.type1_type.set_type,
        },
      },
    }
  },
}

layer2.__depends__ = {
  layer1,
}
layer2.type2 = {
  [Layer.key.refines] = {
    _.type1.type1_type
  },
  set = {
    object_2 = {
      [Layer.key.refines] = {
        _.type1.type1_type.set_type,
      },
    },
  },
}

print ("layer1", dump (Proxy.export (layer1)))
print ("layer2", dump (Proxy.export (layer2)))

do
  local set = layer2.type2.set
  print ("set", set)
  for k, p in Proxy.pairs (set) do
    print (k, p)
  end
end

print ("flattened layer1", dump (Proxy.flatten (layer1)))
print ("flattened layer2", dump (Proxy.flatten (layer2)))
