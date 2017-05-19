[![Build status](https://travis-ci.org/saucisson/layeredata.svg?branch=master)](https://travis-ci.org/saucisson/layeredata)
[![Coverage Status](https://coveralls.io/repos/github/saucisson/layeredata/badge.svg)](https://coveralls.io/github/saucisson/layeredata)
[![Chat](https://badges.gitter.im/saucisson/layeredata.svg)](https://gitter.im/saucisson/layeredata?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

# Layered Data

`layeredata` is a Lua library that allows to represent data in several layers,
and view them as merged.

See [this article](http://ceur-ws.org/Vol-1591/paper19.pdf).

# Install

This module is available in [luarocks](https://luarocks.org):
```bash
  luarocks install layeredata
```

# Usage

First, import the module:
```lua
  local Layer = require "layeredata"
```

# Test

Tests are written for [busted](http://olivinelabs.com/busted).
```bash
  busted src
```
