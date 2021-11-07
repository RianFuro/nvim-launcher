local seq = require 'launch.util.seq'

local function component(cb)
  return function (props) 
    props = props or {}
    local children = seq.from(props):collect()    
    props.children = children

    return cb(props)
  end
end

return setmetatable({
  -- TODO: make this useful (color, padding, etc)
  block = component(function (props)
    return props.children
  end)
}, {
  __call = function (_, ...)
    return component(...)
  end
})
