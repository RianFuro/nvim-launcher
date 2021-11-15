local result = require 'launch.util.result'

local M = {}

local function align_inside(size, left, right, to)
  return math.floor(left + ((right - left) * to) - (size * to))
end

local function as_percentage(value)
  local percentage = type(value) == 'string' and value:match('(%d+)%%')
  return percentage
    and result.success(percentage / 100)
    or result.error()
end

local function percentage_of(value)
  return function (p)
    return math.floor(value * p)
  end
end

local align_map = {
  left = 0, top = 0,
  center = 0.5,
  right = 1, bottom = 1
}

function M.rect_with(constraints)
  local hmax, vmax = vim.o.columns, vim.o.lines - vim.o.cmdheight - (vim.o.laststatus ~= 0 and 1 or 0)

  local width = as_percentage(constraints.width)
    :map(percentage_of(hmax))
    :unwrap_or(constraints.width)

  local height = as_percentage(constraints.height)
    :map(percentage_of(vmax))
    :unwrap_or(constraints.height)

  if constraints.truncate then
    width = math.min(width, hmax)
    height = math.min(height, vmax)
  end

  if width > hmax then
    return result.error { type = 'h-overflow', overflow = width - hmax }
  end

  if height > vmax then
    return result.error { type = 'v-overflow', overflow = height - vmax }
  end

  local x = align_inside(width, 0, hmax, align_map[constraints.halign])
  local y = align_inside(height, 0, vmax, align_map[constraints.valign])

  return result.success(x, y, width, height)
end

return M
