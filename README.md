# ltest

Lua test framework.

## Quick Start

``` lua
local lt = require "ltest"

local test1 = lt.test "test1"

function test1:hello()
    lt.assertEquals(_VERSION, "Lua 5.4")
end

os.exit(lt.run(), true)
```
