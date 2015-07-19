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

describe ("issue #8", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata"
    local layer = Layer.new { name = "mylayer" }
    layer.__label__ = "mylayer"
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
    local Layer = require "layeredata"
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
    local Layer = require "layeredata"
    local a = Layer.new { name = "a" }
    local b = Layer.new { name = "b" }
    local c = Layer.new { name = "c" }
    a.__label__ = "a"
    a.x = {
      value = 1,
    }
    b.__depends__ = { a }
    b.y = {
      __refines__ = { Layer.reference "a".x }
    }
    c.__depends__ = { b }
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
    local Layer = require "layeredata"
    local layer = Layer.new { name = "layer" }
    layer.a = {
      __label__ = "a",
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
    local Layer = require "layeredata"
    local layer = Layer.new { name = "layer" }
    layer.a = {
      __label__ = "a",
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
    local Layer = require "layeredata"
    local layer = Layer.new { name = "layer" }
    layer.a = {
      __label__ = "a",
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
    local Layer = require "layeredata"
    local layer = Layer.new { name = "layer" }
    layer.a = {
      __label__ = "a",
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
    local Layer = require "layeredata"
    local layer = Layer.new { name = "layer" }
    layer.a = {
      __label__ = "a",
      [Layer.reference "a"] = 1,
    }
    assert.are.equal (layer.a [Layer.reference "a"], 1)
  end)
end)

describe ("issue #16", function ()
  it ("is fixed", function ()
    local Layer = require "layeredata"
    local a     = Layer.new { name = "a" }
    local b     = Layer.new { name = "b" }
    b.__depends__ = { a }
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
