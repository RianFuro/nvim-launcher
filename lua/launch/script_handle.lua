local M = {}

local jobs = {}

function M.new(script)
  return setmetatable({
    start = function (self)
      if script.is_running then return end

      local term_channel = vim.api.nvim_open_term(script.bufnr, {})
      local job = {
        id = nil,
        output_received = false,
        exit = false
      }
      job.id = vim.fn.jobstart(script.cmd, {
        -- TODO: cwd to guess_root
        on_stdout = function (_, lines)
          vim.api.nvim_chan_send(term_channel, table.concat(lines, '\r\n'))
          if #lines == 1 and lines[1] == '' then
            job.output_received = true
          end
        end,
        on_exit = function ()
          self:stop()
          job.exit = true
        end
      })
      jobs[script.name] = job

      script.is_running = true
    end,
    stop = function (self)
      if not script.is_running then return end

      local job = jobs[script.name]
      vim.fn.jobstop(job.id)
      return self:sync()
    end,
    sync = function ()
      if not script.is_running then return end

      local job = jobs[script.name]
      vim.fn.jobwait({job.id}, -1)
      vim.wait(100, function ()
        return job.output_received and job.exit
      end, 20)
      script.is_running = false

      local output = vim.api.nvim_buf_get_lines(script.bufnr, 0, -1, true)
      while output[#output] == '' and #output > 0 do
        output[#output] = nil
      end
      return { output = output }
    end,
    open_output_buffer = function (mods)
      vim.cmd((mods or '') .. ' sbuffer '..script.bufnr)
    end
  }, {
    __index = function (_, k)
      return script[k]
    end
  })
end

return M
