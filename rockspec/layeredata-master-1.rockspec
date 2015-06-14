package = "layeredata"
version = "master-1"

source = {
  url = "git://github.com/saucisson/lua-layeredata",
}

description = {
  summary     = "",
  detailed    = [[]],
  license     = "MIT/X11",
  maintainer  = "Alban Linard <alban.linard@lsv.ens-cachan.fr>",
}

dependencies = {
  "c3       >= 0",
  "coronest >= 0",
  "serpent  >= 0",
}

build = {
  type    = "builtin",
  modules = {
    ["layeredata"] = "src/layeredata.lua",
  },
}
