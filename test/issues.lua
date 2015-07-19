require 'busted.runner'()

local assert   = require "luassert"

describe ("issue #1", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata"
    local layer = Layer.new { name = "layer" }
    layer.__label__ = "root"
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

describe ("issue #2", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata"
    local layer = Layer.new { name = "layer" }
    layer.x = {
      __label__ = "x",
      y = Layer.reference "x",
    }
    assert.are.equal (layer.x, layer.x.y)
    assert (Layer.dump (layer):match "y")
  end)
end)

describe ("issue #3", function ()
  it ("is updated and fixed", function ()
    local Layer = require "layeredata"
    local back  = Layer.new { name = "back" }
    local front = Layer.new { name = "front" }
    front.__depends__ = { back }
    back.x    = {}
    front.x.y = true
    assert.is_true (front.x.y)
  end)
end)

describe ("issue #4", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata"
    local layer = Layer.new { name = "layer" }
    layer.a = {
      __label__ = "a",
      b = Layer.reference "a".c,
      c = 1,
    }
    assert.are.equal (layer.a.b, layer.a.c)
    assert.are.equal (layer.a.b, 1)
  end)
end)

describe ("issue #5", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata"
    local layer = Layer.new { name = "layer" }
    layer.x = {
      __label__ = "x",
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
    local Layer = require "layeredata"
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
    local Layer = require "layeredata"
    local layer = Layer.new { name = "layer" }
    layer.x = {
      __label__ = "x",
      a = {
        z = 1,
      },
      b = Layer.reference "x".a,
    }
    assert (Layer.dump (layer):match [[b%s*=%s*"x%s*->%s*%[a%]"]])
    assert (Layer.dump (layer, true):match [[b%s*=%s*{]])
  end)
end)
