local seq = require 'launch.util.seq'

local function component(cb)
  return function (props) 
    props = props or {}
    local children = seq.from(props):collect()    
    props.children = children

    return cb(props)
  end
end

local function render(component, props)
  local function flat(item)
    if (type(item) == 'string') then return {item} end
    if (type(item) == 'table') then return seq.from(item):flat_map(flat):collect() end
  end

  local result = component(props or {})
  return seq.from(result)
    :flat_map(flat)
    :collect()
end

return setmetatable({
  render = render,

  -- TODO: make this useful (color, padding, etc)
  block = component(function (props)
    local margin_block_start = props.margin_block_start or 0
    local margin_block_end = props.margin_block_end or 0

    local children =
      seq.rep('', margin_block_start) 
      + seq.from(props.children) 
      + seq.rep('', margin_block_end)

    return children:collect()
  end),
}, {
  __call = function (_, ...)
    return component(...)
  end
})
