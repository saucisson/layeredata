require 'busted.runner'()

local assert   = require "luassert"

--[==[
describe ("issue #1", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local layer = Layer.new { name = "layer" }
    layer.__labels__ = { root }
    layer.x = {
      __refines__ = {
        Layer.reference "root".x.y,
      },
      y = {
        z = 1,
      },
    }
    assert.are.equal (layer.x.z, 1)
    assert.is_nil    (layer.x.a)
  end)
end)
--]==]

describe ("issue #2", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local layer = Layer.new { name = "layer" }
    layer.x = {
      __labels__ = { x = true },
      y = Layer.reference "x",
    }
    assert.are.equal (layer.x, layer.x.y)
    assert (Layer.dump (layer):match "y")
  end)
end)

describe ("issue #3", function ()
  it ("is updated and fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local back  = Layer.new { name = "back" }
    local front = Layer.new { name = "front" }
    front.__refines__ = { back }
    back.x    = {}
    front.x.y = true
    assert.is_true (front.x.y)
  end)
end)

describe ("issue #4", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local layer = Layer.new { name = "layer" }
    layer.a = {
      __labels__ = { a = true },
      b = Layer.reference "a".c,
      c = 1,
    }
    assert.are.equal (layer.a.b, layer.a.c)
    assert.are.equal (layer.a.b, 1)
  end)
end)

describe ("issue #5", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local layer = Layer.new { name = "layer" }
    layer.x = {
      __labels__ = { x = true },
      a = {},
      b = {
        c = Layer.reference "x".a,
      },
    }
    assert.are.equal (layer.x.b.c, layer.x.a)
  end)
end)

describe ("issue #6", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local layer = Layer.new { name = "layer" }
    layer.a = {
      z = 1,
    }
    layer.x = {
      __default__ = {
        __refines__ = { layer.a },
      },
      b = {}
    }
    assert.are.equal (layer.x.b.z, layer.a.z)
    assert.are.equal (layer.x.b.z, 1)
  end)
end)

describe ("issue #7", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local layer = Layer.new { name = "layer" }
    layer.x = {
      __labels__ = { x = true },
      a = {
        z = 1,
      },
      b = Layer.reference "x".a,
    }
    assert (Layer.dump (layer):match [[b%s*=%s*"x%s*->%s*%[a%]"]])
    assert (Layer.dump (layer, true):match [[b%s*=%s*{]])
  end)
end)

describe ("issue #8", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local layer = Layer.new { name = "mylayer" }
    layer.__labels__ = { mylayer = true }
    layer.root = {
      x = { 1 }
    }
    layer.root.a = {
      __refines__ = { Layer.reference "mylayer".root },
    }
    assert.are.equal (Layer.size (layer.root.a.x), 1)
  end)
end)

describe ("issue #9", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local layer = Layer.new { name = "layer" }
    layer.a = {
      __checks__ = {
        function (proxy)
          if proxy.final and not proxy.value then
            return "id", "message"
          end
        end
      },
    }
    layer.b = {
      final = true,
      value = 3,
      __refines__ = {
        Layer.reference (false).a
      },
    }
    layer.c = {
      final = true,
      __refines__ = {
        Layer.reference (false).a
      },
    }
    assert.is_nil     (layer.a.__messages__)
    assert.is_nil     (layer.b.__messages__)
    assert.is_not_nil (layer.c.__messages__)
  end)
end)

describe ("issue #10", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local a = Layer.new { name = "a" }
    local b = Layer.new { name = "b" }
    local c = Layer.new { name = "c" }
    a.__labels__ = { a = true }
    a.x = {
      value = 1,
    }
    b.__refines__ = { a }
    b.y = {
      __refines__ = { Layer.reference "a".x }
    }
    c.__refines__ = { b }
    c.z = {
      __refines__ = { Layer.reference "a".y }
    }
    local d = Layer.flatten (c)
    assert.are.equal (d.x.value, d.y.value)
    assert.are.equal (d.y.value, d.z.value)
    assert.are.equal (d.z.value, 1)
    assert.are.equal (d.z.value, c.z.value)
    assert.are.equal (c.z.value, b.y.value)
    assert.are.equal (b.y.value, a.x.value)
  end)
end)

describe ("issue #11", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local layer = Layer.new { name = "layer" }
    layer.a = {
      __labels__ = { a = true },
      x = {
        z = {
          value = 1,
        },
      },
      y = {
        __refines__ = { Layer.reference "a".x }
      }
    }
    local flat = Layer.flatten (layer)
    assert.are.equal (flat.a.y.z.value, layer.a.x.z.value)
    assert.are.equal (flat.a.x.z.value, 1)
  end)
end)

describe ("issue #12", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local layer = Layer.new { name = "layer" }
    layer.a = {
      __labels__ = { a = true },
      x = {
        z = {
          value = 1,
        },
      },
      y = {
        __refines__ = { Layer.reference "a".x }
      }
    }
    assert.has.no.error (function ()
      Layer.toyaml (layer)
    end)
  end)
end)

describe ("issue #13", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local layer = Layer.new { name = "layer" }
    layer.a = {
      __labels__ = { a = true },
      x = { value = 1 },
      collection = {
        __default__ = {
          __refines__ = {
            Layer.reference "a".x,
          }
        },
        e = {},
      }
    }
    assert.are.equal (layer.a.collection.e.value, layer.a.x.value)
    assert.are.equal (layer.a.collection.e.value, 1)
  end)
end)

describe ("issue #14", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local layer = Layer.new { name = "layer" }
    layer.a = {
      __labels__ = { a = true },
      x = { value = 1 },
      y = {
        __refines__ = {
          Layer.reference "a".x,
        }
      },
      z = {
        __refines__ = {
          Layer.reference (false).a.x,
        }
      },
    }
    assert.are.equal (layer.a.y.value, layer.a.z.value)
    assert.are.equal (layer.a.y.value, layer.a.x.value)
    assert.are.equal (layer.a.x.value, 1)
  end)
end)

describe ("issue #15", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local layer = Layer.new { name = "layer" }
    layer.a = {
      __labels__ = { a = true },
      [Layer.reference "a"] = 1,
    }
    assert.are.equal (layer.a [Layer.reference "a"], 1)
  end)
end)

describe ("issue #16", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local a     = Layer.new { name = "a" }
    local b     = Layer.new { name = "b" }
    b.__refines__ = { a }
    a.x = {
      value = 1,
    }
    b.y = {
      __refines__ = {
        Layer.reference (false).x,
      }
    }
    assert.are.equal (b.y.value, a.x.value)
    assert.are.equal (a.x.value, 1)
  end)
end)

describe ("issue #17", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" ({
      checks   = "CHECKS",
      default  = "DEFAULT",
      label    = "LABEL",
      messages = "MESSAGES",
      refines  = "REFINES",
    }, false)
    local a     = Layer.new { name = "a" }
    local b     = Layer.new { name = "b" }
    b.REFINES = { a }
    a.x = {
      value = 1,
    }
    b.y = {
      REFINES = {
        Layer.reference (false).x,
      }
    }
    assert.are.equal (b.y.value, a.x.value)
    assert.are.equal (a.x.value, 1)
  end)
end)

describe ("issue #18", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local layer = Layer.new { layer = "layer" }
    layer.a = {
      __labels__ = { a = true },
      x = { value = 1 },
      y = Layer.reference "a".x,
    }
    assert.are.equal (layer.a.y.value, layer.a.x.value)
    assert.are.equal (layer.a.y.value, 1)
  end)
end)

describe ("issue #19", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" ({}, false)
    local layer = Layer.new { name = "record" }
    local model = Layer.new { name = "record instance" }
    local _     = Layer.reference "record_model"
    local root  = Layer.reference (false)

    layer.__meta__ = {
      record = {
        __labels__ = { record = true },
        __meta__ = {
          __tags__ = {},
        },
        __checks__ = {
          check_tags = function (proxy)
            local message = ""
            local tags = proxy.__meta__.__tags__
            for tag, value in Layer.pairs(tags) do
              if( value["__value_type__"]      ~= nil or
                  value["__value_container__"] ~= nil ) then
                if (proxy[tag] == nil) then
                  message = message .. "Key '" .. tostring(tag) .. "' is missing. "
                elseif (value["__value_type__"] ~= nil and
                        type(proxy[tag]) ~= type(value["__value_type__"])) then
                  message = message .. "Type of " .. tostring(tag) .. "'s value is wrong. "
                elseif(value["__value_container__"] ~= nil) then
                  for k, v in Layer.pairs(value["__value_container__"]) do
                    print(k, v)
                  end
                end
              end
            end
            if (message ~= "") then
              return "check_tags", message
            end
          end,
        },
      },
    }
    model.__refines__ = {
      layer,
    }
    model.model = {
      __labels__ = { record_model = true },
      __refines__ = {
        root.__meta__.record,
      },
      __meta__ = {
        __tags__ = {
          name = { __value_type__ = "string" },
        },
      },
      name = "model",
    }
    local r = Layer.dump (Layer.flatten (model))
  end)
end)

describe ("issue #20", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local layer = Layer.new { layer = "layer" }
    layer.a = {
      x = 1,
      y = 2,
      __meta__    = { z = 3 },
      __default__ = { v = 0 },
    }
    local res = {}
    for k, v in Layer.pairs (layer.a) do
      res [k] = v
    end
    assert.are.equal (res.x, 1)
    assert.are.equal (res.y, 2)
    assert.is_nil    (res.__meta__)
    assert.are.equal (layer.a.__meta__.z, 3)
    assert.is_nil    (layer.a.__meta__.v)
  end)
end)

describe ("issue #22", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata.make" (nil, false)
    local layer = Layer.new { layer = "layer" }
    layer.a = {
      x = 1,
      y = 2,
      __meta__    = { z = 3 },
      __default__ = { v = 0 },
    }
    local flattened = Layer.flatten (layer)
    assert.are.equal (flattened.a.__meta__.z, 3)
  end)
end)
