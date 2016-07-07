package = "layeredata-env"
version = "master-1"

source = {
  url    = "git://github.com/cosyverif/layeredata",
  branch = "master",
}

description = {
  summary     = "Development environment for layeredata",
  detailed    = [[]],
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
  modules = {},
}
