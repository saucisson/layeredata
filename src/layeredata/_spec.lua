require "busted.runner" ()

local assert = require "luassert"

describe ("issue #1", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata"
    local layer = Layer.new { name = "layer" }
    layer.x = {
      [Layer.key.refines] = {
        Layer.reference (layer).x.y,
      },
      y = {
        z = 1,
      },
    }
    assert.has.no.errors (function ()
      local _ = layer.x.z
    end)
    assert.are.equal (layer.x.z, 1)
  end)
end)

describe ("issue #2", function ()
  it ("is fixed", function ()
    local Layer  = require "layeredata"
    local layer  = Layer.new { name = "layer" }
    layer.x = {}
    layer.x.y = Layer.reference (layer.x)
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
    local layer  = Layer.new { name = "layer" }
    layer.a = {
      c = 1,
    }
    layer.a.b = Layer.reference (layer.a).c
    assert.are.equal (layer.a.b, layer.a.c)
    assert.are.equal (layer.a.b, 1)
  end)
end)

describe ("issue #5", function ()
  it ("is fixed", function ()
    local Layer  = require "layeredata"
    local layer  = Layer.new { name = "layer" }
    layer.x = {
      a = {},
      b = {},
    }
    layer.x.b.c = Layer.reference (layer.x).a
    assert.are.equal (layer.x.b.c, layer.x.a)
  end)
end)

describe ("issue #6", function ()
  it ("is fixed", function ()
    local Layer    = require "layeredata"
    local defaults = Layer.key.defaults
    local layer    = Layer.new { name = "layer" }
    layer.a = {
      z = 1,
    }
    layer.x = {
      [defaults] = { layer.a },
      b = {}
    }
    assert.are.equal (layer.x.b.z, layer.a.z)
    assert.are.equal (layer.x.b.z, 1)
  end)
end)

describe ("issue #7", function ()
  it ("is fixed", function ()
    local Layer  = require "layeredata"
    local layer  = Layer.new { name = "layer" }
    layer.x = {
      a = {
        z = 1,
      },
    }
    layer.x.b = Layer.reference (layer.x).a
    assert (Layer.encode (layer):match "%[labels%]")
    local dumped = Layer.dump (layer)
    assert.is_not_nil (dumped.x.b)
    dumped.x.b = nil
    assert.are_same (dumped, {
      x = {
        a = {
          z = 1,
        },
      }
    })
  end)
end)

describe ("issue #8", function ()
  it ("is fixed", function ()
    local Layer   = require "layeredata"
    local refines = Layer.key.refines
    local layer   = Layer.new { name = "mylayer" }
    layer.root = {
      x = { 1 }
    }
    layer.root.a = {
      [refines] = { Layer.reference (layer).root },
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
            Layer.coroutine.yield ("id", "message")
          end
        end
      },
    }
    layer.b = {
      final = true,
      value = 3,
      [refines] = {
        Layer.reference (layer).a
      },
    }
    layer.c = {
      final = true,
      [refines] = {
        Layer.reference (layer).a
      },
    }
    assert.is_nil     (layer.a [messages])
    assert.is_nil     (layer.b [messages])
    assert.is_not_nil (layer.c [messages])
  end)
end)

describe ("issue #12", function ()
  it ("is fixed", function ()
    local Layer   = require "layeredata"
    local refines = Layer.key.refines
    local layer   = Layer.new { name = "layer" }
    layer.a = {
      x = {
        z = {
          value = 1,
        },
      },
    }
    layer.a.y = {
      [refines] = { Layer.reference (layer.a).x }
    }
    assert.has.no.error (function ()
      Layer.dump (layer)
    end)
  end)
end)

describe ("issue #13", function ()
  it ("is fixed", function ()
    local Layer    = require "layeredata"
    local defaults = Layer.key.defaults
    local layer    = Layer.new { name = "layer" }
    layer.a = {
      x = { value = 1 },
    }
    layer.a.collection = {
      [defaults] = { Layer.reference (layer.a).x },
      e = {},
    }
    assert.are.equal (layer.a.collection.e.value, layer.a.x.value)
    assert.are.equal (layer.a.collection.e.value, 1)
  end)
end)

describe ("issue #14", function ()
  it ("is fixed", function ()
    local Layer   = require "layeredata"
    local refines = Layer.key.refines
    local layer   = Layer.new { name = "layer" }
    layer.a = {}
    layer.a.x = { value = 1 }
    layer.a.y = {
      [refines] = {
        Layer.reference (layer.a).x,
      }
    }
    layer.a.z = {
      [refines] = {
        Layer.reference (layer).a.x,
      }
    }
    assert.are.equal (layer.a.x.value, 1)
    assert.are.equal (layer.a.y.value, layer.a.x.value)
    assert.are.equal (layer.a.y.value, layer.a.z.value)
  end)
end)

describe ("issue #15", function ()
  it ("is fixed", function ()
    local Layer  = require "layeredata"
    local layer  = Layer.new { name = "layer" }
    layer.a = {}
    layer.a [Layer.reference (layer.a)] = 1
    assert.are.equal (layer.a [Layer.reference (layer.a)], 1)
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
        Layer.reference (b).x,
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
    local layer  = Layer.new { name = "layer" }
    layer.a = {
      x = { value = 1 },
    }
    layer.a.y = Layer.reference (layer.a).x
    assert.are.equal (layer.a.y.value, layer.a.x.value)
    assert.are.equal (layer.a.y.value, 1)
  end)
end)

describe ("issue #20", function ()
  it ("is fixed", function ()
    local Layer    = require "layeredata"
    local meta     = Layer.key.meta
    local defaults = Layer.key.defaults
    local layer    = Layer.new { name = "layer" }
    layer.d = {
      v = 0,
    }
    layer.a = {
      x = 1,
      y = 2,
      [meta]     = { z = 3 },
      [defaults] = { Layer.reference (layer).d },
    }
    local res = {}
    for k, v in Layer.pairs (layer.a) do
      res [k] = v
    end
    assert.are.equal (res.x, 1)
    assert.are.equal (res.y, 2)
    assert.is_nil    (res [meta])
    assert.are.equal (layer.a [meta].z, 3)
    assert.is_nil    (layer.a [meta].v)
  end)
end)

describe ("issue #23", function ()
  it ("is fixed", function ()
    local Layer    = require "layeredata"
    local checks   = Layer.key.checks
    local defaults = Layer.key.defaults
    local messages = Layer.key.messages
    local record   = Layer.new { name = "record" }
    record [checks] = {
     check = function ()
       Layer.coroutine.yield ("checked", true)
     end,
    }
    local model = Layer.new { name = "instance" }
    model.a = {
     [defaults] = { record },
     b = {},
    }
    local _ = model.a.b
    assert.is_true (model.a.b [messages].checked)
    assert.is_nil  (model [messages])
  end)
end)

describe ("issue #38", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata"
    local layer = Layer.new { name = "layer" }
    layer [Layer.key.meta] = {
      a = {},
    }
    layer.b = {}
    assert.is_true  (Layer.Proxy.has_meta (layer [Layer.key.meta].a))
    assert.is_false (Layer.Proxy.has_meta (layer.b))
  end)

  describe ("issue #39", function ()
    it ("is fixed", function ()
      local Layer = require "layeredata"
      local l1    = Layer.new { name = "l1" }
      l1 [Layer.key.meta] = {
        ref = Layer.reference (l1).t,
      }
      local l2 = Layer.new { name = "l2" }
      l2 [Layer.key.refines] = { l1 }
      assert.are.equal (l2 [Layer.key.meta].ref, l2.t)
    end)
  end)

  describe ("issue #46", function ()
    it ("is fixed", function ()
      local Layer = require "layeredata"
      local l1    = Layer.new { name = "l1" }
      l1 [Layer.key.meta] = {
        a = 1,
      }
      local l2 = Layer.new { name = "l2" }
      l2 [Layer.key.refines] = { l1 }
      local l3 = Layer.new { name = "l3" }
      l3.m = {}
      Layer.Proxy.replacewith (l3.m, l1)
      assert.is_not_nil (l3.m [Layer.key.meta])
    end)
  end)
end)
