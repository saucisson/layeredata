[![Build Status](https://travis-ci.org/saucisson/lua-layeredata.svg?branch=master)](https://travis-ci.org/saucisson/lua-layeredata)
[![Coverage Status](https://coveralls.io/repos/saucisson/lua-layeredata/badge.svg?branch=master&service=github)](https://coveralls.io/github/saucisson/lua-layeredata?branch=master)

# Layered Data

[![Join the chat at https://gitter.im/saucisson/lua-layeredata](https://badges.gitter.im/saucisson/lua-layeredata.svg)](https://gitter.im/saucisson/lua-layeredata?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

`layeredata` is a Lua library that allows to represent data in several layers,
and view them as merged.

# Install

This module is available in [luarocks](https://luarocks.org):
```bash
  luarocks install layeredata
```

To manually install it, simply copy the `src/layeredata.lua` file in your
`LUA_PATH`:
```bash
  cp -r src/layeredata <target>
```

# Usage

First, import the module:
```lua
  local Layer = require "layeredata"
```

# Test

Tests are written for [busted](http://olivinelabs.com/busted).
```bash
  busted test/issues.lua
```
