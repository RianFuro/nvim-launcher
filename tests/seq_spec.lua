local seq = require 'launch.util.seq'

local function check_lazy(method)
  it('does nothing until an item in the seq is consumed', function ()
    local trigger = false
    local s = seq.from({1})
    s = s[method](s, function () trigger = true end)

    assert.is_false(trigger)
    s:pop()
    assert.is_true(trigger)
  end)
end

local function check_consume(method)
  it('passes the value of each consumed item as an argument to the callback', function ()
    local ls = {1,2,3}
    local it = 1

    local s = seq.from({1,2,3})
    s = s[method](s, function (x)
        assert.equal(ls[it], x)
        it = it + 1
        return {}
      end)

    s:collect()
    assert.equal(4, it)
  end)
end

describe('seq', function ()

  describe(':pop', function ()
    it('consumes the first item of the seq', function ()
      local s = seq.from({1,2,3})
      assert.equal(1, s:pop())
      assert.equal(2, s:pop())
      assert.equal(3, s:pop())
    end)

    it('returns nil if there are no more items', function ()
      local s = seq.from({})
      assert.equal(nil, s:pop())
    end)
  end)

  describe(':collect', function ()
    it('transforms the seq into a table, consuming all values', function ()
      local s = seq.from({1,2,3})
      local t = s:collect()

      assert.equal(1, t[1])
      assert.equal(2, t[2])
      assert.equal(3, t[3])
      assert.equal(nil, s:pop())
    end)
  end)

  describe('.reverse', function ()
    it('emits values in reverse', function ()
      local s = seq.reverse({1,2,3}):collect()
      assert.are.same({3,2,1}, s)
    end)
  end)

  describe('.repeat', function ()
    it('repeatedly emits the given value', function ()
      local s = seq.rep(''):take(3):collect()
      assert.are.same({'','',''}, s)
    end)
  end)

  describe('.pairs', function ()
    it('emits values as key-value-pairs', function ()
      local s = seq.pairs({a = 1})

      assert.are.same({'a', 1}, s:pop())
      assert.are.same(nil, s:pop())
    end)

    it('works with objects behind metatables if the metatable defines a __pairs property', function ()
      local wrapped = {a = 1}
      local wrapper = setmetatable({}, {
        __index = wrapped,
        __pairs = function ()
          local it = pairs(wrapped)
          return function (_, k)
            return it(wrapped, k)
          end
        end
      })
      local s = seq.pairs(wrapper)
      assert.are.same({'a', 1}, s:pop())
      assert.are.same(nil, s:pop())
    end)
  end)

  describe(':reduce', function ()
    it('executes the callback for each item', function ()
      local ls = {1,2,3}
      local it = 1
      seq.from(ls)
        :reduce(function (_, cur)
          assert.equal(ls[it], cur)
          it = it + 1
        end)

      assert.equal(4, it)
    end)

    it('provides the initial value to the first callback', function ()
      seq.from({1})
        :reduce(function (acc, _)
          assert.equal(2, acc)
        end, 2)
    end)

    it('provides the returned value of the previous callback to the next call as the accumulator', function ()
      local accs = {0,1,3,6,10}
      local it = 1
      seq.from({1,2,3,4,5})
        :reduce(function (acc, val)
          assert.equal(accs[it], acc)
          it = it + 1
          return acc + val
        end, 0)
    end)

    it('consumes all values', function ()
      local s = seq.from({1,2,3})
      s:reduce(function () end)
      assert.equal(s:pop(), nil)
    end)
  end)

  describe(':into_dict', function ()
    it('reduces key-value-pairs into a dictionary', function ()
      local s = seq.from({{'a', 1}, {'b', 2}})
      assert.are.same({a = 1, b = 2}, s:into_dict())
    end)
  end)

  describe(':map', function ()
    check_lazy('map')
    check_consume('map')

    it('consuming an item returns the value returned by the callback instead of the consumed item', function ()
      local s = seq.from({1,2})
        :map(function () return 3 end)

      assert.equal(3, s:pop())
      assert.equal(3, s:pop())
    end)

    it('passes the value of the consumed item as an argument to the callback', function ()
      local ls = {1,2}
      local it = 1

      local s = seq.from({1,2})
        :map(function (x)
          assert.equal(ls[it], x)
          it = it + 1
          return x + 1
        end)

      s:pop()
      s:pop()
      assert.equal(3, it)
    end)
  end)

  describe(':filter', function ()
    check_lazy('filter')
    check_consume('filter')

    it('consuming an item returns the first item where the callback returns true instead, consuming all other checked items', function ()
      local s = seq.from({1,2,3})
        :filter(function (x) return x == 2 end)

      assert.equal(2, s:pop())
      assert.equal(nil, s:pop())
    end)
  end)

  describe(':flatten', function ()
    it('transforms the seq so inner lists` items are consumed individually', function ()
      local ls = {{1,2},{3,4}}
      local s = seq.from(ls):flatten()

      assert.are.same({1,2,3,4}, s:collect())
    end)

    it('skips over empty lists', function ()
      local s = seq.from({{}, {1,2}}):flatten()
      assert.are.same({1,2}, s:collect())
    end)
  end)

  describe(':concat', function ()
    it('appends a seq', function ()
      local s = seq.from({1,2})
      local s2 = seq.from({3,4})

      assert.are.same({1,2,3,4}, s:concat(s2):collect())
    end)

    it('+ does concat', function ()
      local s = seq.from({1,2}) + seq.from({3,4})

      assert.are.same({1,2,3,4}, s:collect())
    end)
  end)

  describe(':flat_map', function ()
    check_lazy('flat_map')
    check_consume('flat_map')

    it('consuming an item returns the next item from the list returned by the callback instead', function ()
      local s = seq.from({1})
        :flat_map(function () return {2,3} end)

      assert.equal(2, s:pop())
      assert.equal(3, s:pop())
    end)
  end)

  describe(':window_when', function ()
    check_lazy('window_when')
    check_consume('window_when')

    it('consuming an item instead returns a seq of items until the callback matches', function ()
      local s = seq.from({1,2,3})
        :window_when(function (v) return v == 2 end)

      local ret = s:pop()
      assert.equal(1, ret:pop())
      assert.equal(2, ret:pop())
      ret = s:pop()
      assert.equal(3, ret:pop())
      assert.equal(nil, ret:pop())
      assert.equal(nil, s:pop())
    end)
  end)

  describe(':window_before', function ()
    check_lazy('window_before')
    check_consume('window_before')

    it('consuming an item instead returns a seq of items just before the callback matches', function ()
      local s = seq.from({1,2,3})
        :window_before(function (v) return v == 2 end)

      local ret = s:pop()
      assert.equal(1, ret:pop())
      assert.equal(nil, ret:pop())
      ret = s:pop()
      assert.equal(2, ret:pop())
      assert.equal(3, ret:pop())
      assert.equal(nil, ret:pop())
      assert.equal(nil, s:pop())
    end)
  end)
end)
