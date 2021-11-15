local result = require 'launch.util.result'

describe('result', function ()

  describe(':ok', function ()
    it('returns true if the result contains a value', function ()
      assert.is_true(result(nil, 1):ok())
    end)

    it('returns false if the result contains an error', function ()
      assert.is_false(result('some error', nil):ok())
    end)
  end)

  describe(':match', function ()
    it('returns the value of the first callback if the result contains a value', function ()
      assert.equal(1,
        result(nil, 1)
          :match(
            function () return 1 end,
            function () return 2 end
          ))
    end)

    it('returns the value of the second callback if the result contains an error', function ()
      assert.equal(2,
        result('some error', nil)
          :match(
            function () return 1 end,
            function () return 2 end
          ))
    end)

    it('passes the contained value to the first callback', function ()
      assert.equal(1,
        result(nil, 1)
          :match(
            function (val) return val end,
            function () error('unreachable') end
          ))
    end)

    it('passes the contained error to the second callback', function ()
      assert.equal('some error',
        result('some error', nil)
          :match(
            function () error('unreachable') end,
            function (err) return err end
          ))
    end)
  end)

  describe(':unwrap', function ()
    it('returns the value in the result if it exists', function ()
      assert.equal(1, result(nil, 1):unwrap())
    end)

    it('raises an error if no value exists', function ()
      local success = pcall(function ()
        result('some error', nil):unwrap()
      end)

      assert.is_false(success)
    end)
  end)

  describe(':unwrap_or', function ()
    it('returns the value in the result if it exists', function ()
      assert.equal(1, result(nil, 1):unwrap_or(2))
    end)

    it('returns the given alternative if the result contains an error', function ()
      assert.equal(2, result('some error', nil):unwrap_or(2))
    end)
  end)

  describe('.success', function ()
    it('returns a result containing the passed value', function ()
      assert.equal(1, result.success(1):unwrap())
    end)
  end)

  describe('.error', function ()
    it('returns a result containing the passed error', function ()
      local err = result.error('some error')
        :match(
          function () error('unreachable') end,
          function (err) return err end
        )

      assert.equal('some error', err)
    end)
  end)

  describe(':map', function ()
    it('executes the callback when the result contains a value', function ()
      local trigger = false
      result.success(1)
        :map(function () trigger = true end)

      assert.is_true(trigger)
    end)

    it('passes the contained value to the callback', function ()
      local captured = nil
      result.success(1)
        :map(function (val) captured = val end)

      assert.equal(1, captured)
    end)

    it('does not execute the callback if the result contains an error', function ()
      local trigger = false
      result.error()
        :map(function () trigger = true end)

      assert.is_false(trigger)
    end)

    it('stores the value returned by the callback in the result', function ()
      local contained = result.success(1)
        :map(function (v) return v + 1 end)
        :unwrap()

      assert.equal(2, contained)
    end)
  end)

  describe(':map_error', function ()
    it('does not execute the callback if the result contains a value', function ()
      local trigger = false
      result.success(1)
        :map_error(function () trigger = true end)

      assert.is_false(trigger)
    end)

    it('executes the callback when the result contains an error', function ()
      local trigger = false
      result.error()
        :map_error(function () trigger = true end)

      assert.is_true(trigger)
    end)

    it('passes the contained error to the callback', function ()
      local captured = nil
      result.error('some error')
        :map_error(function (err) captured = err end)

      assert.equal('some error', captured)
    end)

    it('stores the value returned by the callback as the new error in the result', function ()
      local error = result.error('some error')
        :map_error(function (err) return err .. '!' end)
        :match(
          function () error('result should be in error') end,
          function (err) return err end
        )

      assert.equal('some error!', error)
    end)
  end)

  describe(':flatten', function ()
    it('returns a contained value if it exists', function ()
      local ret = result.success(result.success(1)):flatten()
      assert.equal(1, ret:unwrap())
    end)

    it('does nothing if the result contains an error', function ()
      local res = result.error()
      local ret = res:flatten()

      assert.equal(res, ret)
    end)
  end)

  describe(':bind', function ()
    it('executes the callback if the result contains a value', function ()
      local trigger = false
      result.success(1)
        :bind(function () trigger = true end)

      assert.is_true(trigger)
    end)

    it('does not exectue the callback if the result contains an error', function ()
      local trigger = false
      result.error()
        :bind(function () trigger = true end)

      assert.is_false(trigger)
    end)

    it('passes the contained value to the callback', function ()
      local captured = nil
      result.success(1)
        :bind(function (val) captured = val end)

      assert.equal(1, captured)
    end)

    it('returns the result returned by the callback', function ()
      local inner = result.success(2)
      local ret = result.success(1)
        :bind(function () return inner end)

      assert.equal(inner, ret)
    end)
  end)

  it('can deal with multiple values in success', function ()
    local r = result.success(1,2,3)
    assert.are.same({1,2,3}, {r:unwrap()})

    r:map(function (...)
      assert.are.same({1,2,3}, {...})
    end)
  end)

  describe('.seq', function ()
    it('automagically unwraps yielded results if they contain a value', function ()
      result.seq(function ()
        local value = result.success(1):yield()
        assert.equal(1, value)
      end)
    end)

    it('cuts the callback short if a yielded result contains an error', function ()
      local trigger = false
      result.seq(function ()
        result.error('some error'):yield()
        trigger = true
      end)
      assert.is_false(trigger)
    end)

    it('returns the value returned by the callback as a result', function ()
      local res = result.seq(function ()
        return 1
      end)

      assert.equal(1, res:unwrap())
    end)

    it('returns the yielded failed result from the callback', function ()
      local f = result.error('some error')
      local res = result.seq(function ()
        f:yield()
      end)
      assert.equal(f, res)
    end)
  end)
end)
