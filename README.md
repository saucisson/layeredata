[![wercker status](https://app.wercker.com/status/5a98f823f3651ef85c5f67ab6c9bb525/s "wercker status")](https://app.wercker.com/project/bykey/5a98f823f3651ef85c5f67ab6c9bb525)
[![Coverage Status](https://coveralls.io/repos/github/cosyverif/layeredata/badge.svg?branch=master)](https://coveralls.io/github/cosyverif/layeredata?branch=master)
[![Join the chat at https://gitter.im/cosyverif/layeredata](https://badges.gitter.im/cosyverif/layeredata.svg)](https://gitter.im/cosyverif/layeredata?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

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
