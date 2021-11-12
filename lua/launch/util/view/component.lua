local seq = require 'launch.util.seq'

local M = {}

local function component(cb)
  return function (props)
    props = props or {}
    local children = seq.from(props):collect()
    props.children = children

    local bindings = props.on or {}
    props.on = nil

    local result = cb(props) or {}
    local __bindings = {}
    for k, cb in pairs(bindings) do
      table.insert(__bindings, {
        chord = k,
        cb = cb
      })
    end
    result.bindings = __bindings
    result.component = true
    return result
  end
end

M.block = component(function (props)
  local margin_block_start = props.margin_block_start or 0
  local margin_block_end = props.margin_block_end or 0

  local children =
    seq.rep(''):take(margin_block_start)
    + seq.from(props.children)
    + seq.rep(''):take(margin_block_end)

  return children:collect()
end)

local function flatten_component(component_result, context)
  return seq.from(component_result)
    :reduce(function (acc, cur)
      if (type(cur) == 'string') then return {
        rows = acc.rows + seq.from({cur}),
        bindings = acc.bindings,
        current_line = acc.current_line + 1
      } end

      if (type(cur) == 'table' and not cur.component) then
        local nested = flatten_component(cur, { current_line = acc.current_line })
        local rows = nested.rows:collect()
        return {
          rows = acc.rows + seq.from(rows),
          bindings = acc.bindings + nested.bindings,
          current_line = nested.current_line
        }
      end

      if (type(cur) == 'table' and cur.component) then
        local nested = flatten_component(cur, { current_line = acc.current_line })
        local rows = nested.rows:collect()
        return {
          rows = acc.rows + seq.from(rows),
          bindings = acc.bindings
            + nested.bindings
            + seq.from(cur.bindings)
                :map(function (b)
                  return {
                    chord = b.chord,
                    handle = b.cb,
                    range = {acc.current_line, acc.current_line + #rows}
                  }
                end),
          current_line = nested.current_line
        }
      end
    end, {
      rows = seq.from({}),
      bindings = seq.from({}),
      current_line = context.current_line,
    })
end

function M.render(component, props)
  local result = flatten_component({component(props)}, { current_line = 0 })
  local rows = result.rows:collect()
  rows.bindings = result.bindings:collect()
  return rows
end

return setmetatable(M, {
  __call = function (_, ...)
    return component(...)
  end
})
