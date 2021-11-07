local view = require 'launch.util.view'
local state = require 'launch.util.view.state'
local component = require 'launch.util.view.component'
local block = component.block

describe('component', function ()
  it('calls the callback when the returned function is invoked', function ()
    local trigger = false
    component(function () trigger = true end)()
    assert.is_true(trigger)
  end)

  it('passes all keyword parameters from the invocation to the callback', function ()
    component(function (props)
      assert.equal(1, props.a) 
      assert.equal(2, props.b) 
    end)({ a = 1, b = 2 })
  end)

  it('passes all positional parameters from the invocation on the `children` field', function ()
    component(function (props)
      assert.are.same({1,2,3}, props.children)
    end)({ 1, 2, 3 })
  end)

  it('can be rendered to a list', function ()
    local result = component.render(function ()
      return block {
        'hello',
        'world'
      }
    end)

    assert.are.same({'hello', 'world'}, result)
  end)

  it('flattens down nested components to a single list when rendered', function ()
    local result = component.render(function ()
      return block {
        'hello',
        block {
          'you',
          'handsome',
          'being'
        }
      }
    end)

    assert.are.same({'hello', 'you', 'handsome', 'being'}, result)
  end)

  describe('block', function ()
    it('returns its children', function ()
      local c = block { 'hello', 'world' } 
      assert.are.same({ 'hello', 'world' }, c)
    end)

    it('inserts lines equal to margin_block_start before its children', function ()
      local c = block {
        margin_block_start = 2,
        'hello, world'
      }

      assert.are.same({ '', '', 'hello, world' }, c)
    end)

    it('inserts lines equal to margin_block_end after its children', function ()
      local c = block {
        margin_block_end = 2,
        'hello, world'
      }

      assert.are.same({ 'hello, world', '', '' }, c)
    end)
  end)
end)

describe('state', function ()
  it('raises an error if the initial value is not a table', function ()
    local result = pcall(function ()
      state.new(1)
    end)
    assert.is_false(result)
  end)

  it('returns values of fields from the state', function ()
    local s = state.new {
      a = 1
    }

    assert.equals(1, s.a)
  end)

  it('can be subscribed to', function ()
    local s = state.new {
      a = 1
    }
    local trigger = false

    state.subscribe(s, function ()
      trigger = true
    end)

    s.a = 2

    assert.is_true(trigger)
  end)

  it('converts tables on the initial state to proxy-objects', function ()
    local s = state.new {
      sub = {
        a = 1,
        subsub = {
          b = 2
        }
      }
    }

    local trigger = false
    state.subscribe(s.sub, function ()
      trigger = true
    end)
    s.sub.a = 3
    assert.is_true(trigger)

    trigger = false
    state.subscribe(s.sub.subsub, function ()
      trigger = true
    end)
    s.sub.subsub.b = 3
    assert.is_true(trigger)
  end)

  it('propagates change notifications upwards', function ()
    local s = state.new {
      sub = {
        a = 1,
      }
    }

    local trigger = false
    state.subscribe(s, function ()
      trigger = true
    end)
    s.sub.a = 3
    assert.is_true(trigger)
  end)

  it('subscription returns an unsubscribe function that removes the callback', function ()
    local s = state.new {
      a = 1
    }

    local trigger = false
    local unsubscribe = state.subscribe(s, function ()
      trigger = true
    end)
    unsubscribe()
    s.a = 2
    assert.is_false(trigger)
  end)
end)

describe('view', function ()
  it('renders into a buffer', function ()
    local bufnr = vim.api.nvim_create_buf(false, true)

    view(bufnr, function ()
      return block {
        'hello',
        'world'
      }
    end) 

    assert.are.same({ 'hello', 'world' }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
  end)

  it('updates the buffer content when the state changes', function ()
    local bufnr = vim.api.nvim_create_buf(false, true)

    local v = view(bufnr, function (props)
      return block {
        'hello',
        props.text
      }
    end, { text = 'world' }) 

    v.state.text = 'you handsome being'
    assert.are.same({ 'hello', 'you handsome being' }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
  end)
end)
