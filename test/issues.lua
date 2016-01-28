require "busted.runner" ()

local assert = require "luassert"

--[==[
describe ("issue #1", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata"
    local layer = Layer.new { name = "layer" }
    layer[Layer.key.labels] = { root }
    layer.x = {
      [Layer.key.refines] = {
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
    local Layer  = require "layeredata"
    local labels = Layer.key.labels
    local layer  = Layer.new { name = "layer" }
    layer.x = {
      [labels] = { x = true },
      y = Layer.reference "x",
    }
    assert.are.equal (layer.x, layer.x.y)
    assert (Layer.encode (layer):match "y")
  end)
end)

describe ("issue #3", function ()
  it ("is updated and fixed", function ()
    local Layer   = require "layeredata"
    local refines = Layer.key.refines
    local back    = Layer.new { name = "back" }
    local front   = Layer.new { name = "front" }
    front [refines] = { back }
    back.x    = {}
    front.x.y = true
    assert.is_true (front.x.y)
  end)
end)

describe ("issue #4", function ()
  it ("is fixed", function ()
    local Layer  = require "layeredata"
    local labels = Layer.key.labels
    local layer  = Layer.new { name = "layer" }
    layer.a = {
      [labels] = { a = true },
      b = Layer.reference "a".c,
      c = 1,
    }
    assert.are.equal (layer.a.b, layer.a.c)
    assert.are.equal (layer.a.b, 1)
  end)
end)

describe ("issue #5", function ()
  it ("is fixed", function ()
    local Layer  = require "layeredata"
    local labels = Layer.key.labels
    local layer  = Layer.new { name = "layer" }
    layer.x = {
      [labels] = { x = true },
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
    local Layer   = require "layeredata"
    local default = Layer.key.default
    local refines = Layer.key.refines
    local layer   = Layer.new { name = "layer" }
    layer.a = {
      z = 1,
    }
    layer.x = {
      [default] = {
        [refines] = { layer.a },
      },
      b = {}
    }
    assert.are.equal (layer.x.b.z, layer.a.z)
    assert.are.equal (layer.x.b.z, 1)
  end)
end)

describe ("issue #7", function ()
  it ("is fixed", function ()
    local Layer  = require "layeredata"
    local labels = Layer.key.labels
    local layer  = Layer.new { name = "layer" }
    layer.x = {
      [labels] = { x = true },
      a = {
        z = 1,
      },
      b = Layer.reference "x".a,
    }
    assert (Layer.encode (layer):match "%[labels%]")
    assert.are_same (Layer.dump (layer), {
      x = {
        a = {
          z = 1,
        },
        b = [[@x / a]],
      }
    })
  end)
end)

describe ("issue #8", function ()
  it ("is fixed", function ()
    local Layer   = require "layeredata"
    local labels  = Layer.key.labels
    local refines = Layer.key.refines
    local layer   = Layer.new { name = "mylayer" }
    layer [labels] = { mylayer = true }
    layer.root = {
      x = { 1 }
    }
    layer.root.a = {
      [refines] = { Layer.reference "mylayer".root },
    }
    if #setmetatable ({}, { __len = function () return 1 end }) ~= 1 then
      assert.are.equal (Layer.len (layer.root.a.x), 1)
    else
      assert.are.equal (#layer.root.a.x, 1)
    end
  end)
end)

describe ("issue #9", function ()
  it ("is fixed", function ()
    local Layer    = require "layeredata"
    local checks   = Layer.key.checks
    local refines  = Layer.key.refines
    local messages = Layer.key.messages
    local layer    = Layer.new { name = "layer" }
    layer.a = {
      [checks] = {
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
      [refines] = {
        Layer.reference (false).a
      },
    }
    layer.c = {
      final = true,
      [refines] = {
        Layer.reference (false).a
      },
    }
    assert.is_nil     (layer.a [messages])
    assert.is_nil     (layer.b [messages])
    assert.is_not_nil (layer.c [messages])
  end)
end)

describe ("issue #10", function ()
  it ("is fixed", function ()
    local Layer   = require "layeredata"
    local labels  = Layer.key.labels
    local refines = Layer.key.refines
    local a = Layer.new { name = "a" }
    local b = Layer.new { name = "b" }
    local c = Layer.new { name = "c" }
    a [labels] = { a = true }
    a.x = {
      value = 1,
    }
    b [refines] = { a }
    b.y = {
      [refines] = { Layer.reference "a".x }
    }
    c [refines] = { b }
    c.z = {
      [refines] = { Layer.reference "a".y }
    }
    local d = Layer.flatten (c, { compact = true })
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
    local Layer   = require "layeredata"
    local labels  = Layer.key.labels
    local refines = Layer.key.refines
    local layer   = Layer.new { name = "layer" }
    layer.a = {
      [labels] = { a = true },
      x = {
        z = {
          value = 1,
        },
      },
      y = {
        [refines] = { Layer.reference "a".x }
      }
    }
    local flat = Layer.flatten (layer)
    assert.are.equal (flat.a.y.z.value, layer.a.x.z.value)
    assert.are.equal (flat.a.x.z.value, 1)
  end)
end)

describe ("issue #12", function ()
  it ("is fixed", function ()
    local Layer   = require "layeredata"
    local labels  = Layer.key.labels
    local refines = Layer.key.refines
    local layer   = Layer.new { name = "layer" }
    layer.a = {
      [labels] = { a = true },
      x = {
        z = {
          value = 1,
        },
      },
      y = {
        [refines] = { Layer.reference "a".x }
      }
    }
    assert.has.no.error (function ()
      Layer.dump (layer)
    end)
  end)
end)

describe ("issue #13", function ()
  it ("is fixed", function ()
    local Layer   = require "layeredata"
    local labels  = Layer.key.labels
    local default = Layer.key.default
    local refines = Layer.key.refines
    local layer = Layer.new { name = "layer" }
    layer.a = {
      [labels] = { a = true },
      x = { value = 1 },
      collection = {
        [default] = {
          [refines] = {
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
    local Layer   = require "layeredata"
    local labels  = Layer.key.labels
    local refines = Layer.key.refines
    local layer   = Layer.new { name = "layer" }
    layer.a = {
      [labels] = { a = true },
      x = { value = 1 },
      y = {
        [refines] = {
          Layer.reference "a".x,
        }
      },
      z = {
        [refines] = {
          Layer.reference (false).a.x,
        }
      },
    }
    assert.are.equal (layer.a.x.value, 1)
    assert.are.equal (layer.a.y.value, layer.a.x.value)
    assert.are.equal (layer.a.y.value, layer.a.z.value)
  end)
end)

describe ("issue #15", function ()
  it ("is fixed", function ()
    local Layer  = require "layeredata"
    local labels = Layer.key.labels
    local layer  = Layer.new { name = "layer" }
    layer.a = {
      [labels] = { a = true },
      [Layer.reference "a"] = 1,
    }
    assert.are.equal (layer.a [Layer.reference "a"], 1)
  end)
end)

describe ("issue #16", function ()
  it ("is fixed", function ()
    local Layer   = require "layeredata"
    local refines = Layer.key.refines
    local a       = Layer.new { name = "a" }
    local b       = Layer.new { name = "b" }
    b [refines] = { a }
    a.x = {
      value = 1,
    }
    b.y = {
      [refines] = {
        Layer.reference (false).x,
      }
    }
    assert.are.equal (b.y.value, a.x.value)
    assert.are.equal (a.x.value, 1)
  end)
end)

describe ("issue #17", function ()
  it ("is irrelevant", function ()
    local Layer = require "layeredata"
    assert.is_truthy (type (Layer) ~= "function")
  end)
end)

describe ("issue #18", function ()
  it ("is fixed", function ()
    local Layer  = require "layeredata"
    local labels = Layer.key.labels
    local layer  = Layer.new { layer = "layer" }
    layer.a = {
      [labels] = { a = true },
      x = { value = 1 },
      y = Layer.reference "a".x,
    }
    assert.are.equal (layer.a.y.value, layer.a.x.value)
    assert.are.equal (layer.a.y.value, 1)
  end)
end)

describe ("issue #19", function ()
  it ("is fixed", function ()
    local Layer   = require "layeredata"
    local labels  = Layer.key.labels
    local meta    = Layer.key.meta
    local checks  = Layer.key.checks
    local refines = Layer.key.refines
    local layer   = Layer.new { name = "record" }
    local model   = Layer.new { name = "record instance" }
    local _       = Layer.reference "record_model"
    local root    = Layer.reference (false)

    layer [meta] = {
      record = {
        [labels] = { record = true },
        [meta] = {
          __tags__ = {},
        },
        [checks] = {
          check_tags = function (proxy)
            local message = ""
            local tags = proxy [meta].__tags__
            for tag, value in Layer.pairs (tags) do
              if value ["__value_type__"] ~= nil
              or value ["__value_container__"] ~= nil then
                if proxy [tag] == nil then
                  message = message .. "Key '" .. tostring (tag) .. "' is missing. "
                elseif value ["__value_type__"] ~= nil
                   and type (proxy [tag]) ~= type (value["__value_type__"]) then
                  message = message .. "Type of " .. tostring(tag) .. "'s value is wrong. "
                elseif value["__value_container__"] ~= nil then
                  for k, v in Layer.pairs (value ["__value_container__"]) do
                    print(k, v)
                  end
                end
              end
            end
            if message ~= "" then
              return "check_tags", message
            end
          end,
        },
      },
    }
    model [refines] = {
      layer,
    }
    model.model = {
      [labels] = { record_model = true },
      [refines] = {
        root [meta].record,
      },
      [meta] = {
        __tags__ = {
          name = { __value_type__ = "string" },
        },
      },
      name = "model",
    }
    Layer.encode (Layer.flatten (model))
  end)
end)

describe ("issue #20", function ()
  it ("is fixed", function ()
    local Layer   = require "layeredata"
    local meta    = Layer.key.meta
    local default = Layer.key.default
    local layer   = Layer.new { name = "layer" }
    layer.a = {
      x = 1,
      y = 2,
      [meta]    = { z = 3 },
      [default] = { v = 0 },
    }
    local res = {}
    for k, v in Layer.contents (layer.a) do
      res [k] = v
    end
    assert.are.equal (res.x, 1)
    assert.are.equal (res.y, 2)
    assert.is_nil    (res [meta])
    assert.are.equal (layer.a [meta].z, 3)
    assert.is_nil    (layer.a [meta].v)
  end)
end)

describe ("issue #22", function ()
  it ("is fixed", function ()
    local Layer   = require "layeredata"
    local meta    = Layer.key.meta
    local default = Layer.key.default
    local layer   = Layer.new { layer = "layer" }
    layer.a = {
      x = 1,
      y = 2,
      [meta]    = { z = 3 },
      [default] = { v = 0 },
    }
    local flattened = Layer.flatten (layer)
    assert.are.equal (flattened.a [meta].z, 3)
  end)
end)

describe ("issue #23", function ()
  it ("is fixed", function ()
    local Layer    = require "layeredata"
    local checks   = Layer.key.checks
    local default  = Layer.key.default
    local refines  = Layer.key.refines
    local messages = Layer.key.messages
    local record   = Layer.new { name = "record" }
    record [checks] = {
     check = function ()
       return "checked", true
     end,
    }
    local model = Layer.new { name = "instance" }
    model.a = {
     [default] = {
       [refines] = {
         record,
       },
     },
     b = {},
    }
    local _ = model.a.b
    assert.is_true (model.a.b [messages].checked)
    assert.is_nil  (model [messages])
  end)
end)
