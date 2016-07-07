package = "layeredata"
version = "master-1"

source = {
  url = "git://github.com/cosyverif/layeredata",
}

description = {
  summary     = "Layered Data",
  detailed    = [[
The `layeredata` (layered data) library allows to represent data as trees
observed through several layers.
]],
  license     = "MIT/X11",
  homepage    = "https://github.com/cosyverif/layeredata",
  maintainer  = "Alban Linard <alban@linard.fr>",
}

dependencies = {
  "lua >= 5.1",
  "busted",
  "cluacov",
  "luacheck",
  "luacov",
  "luacov-coveralls",
}

build = {
  type    = "builtin",
  modules = {
    layeredata = "src/layeredata/init.lua",
  },
}
