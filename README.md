[![Build status](https://app.wercker.com/status/091b4342d5d89fa9e55f7f7373f7a6fc/s/master "wercker status")](https://app.wercker.com/project/byKey/091b4342d5d89fa9e55f7f7373f7a6fc)
[![Coverage Status](https://coveralls.io/repos/github/cosyverif/layeredata/badge.svg)](https://coveralls.io/github/cosyverif/layeredata)
[![Chat](https://badges.gitter.im/cosyverif/layeredata.svg)](https://gitter.im/cosyverif/layeredata?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

# Layered Data

`layeredata` is a Lua library that allows to represent data in several layers,
and view them as merged.

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
