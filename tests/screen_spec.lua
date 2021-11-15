local screen = require 'launch.util.screen'

describe('screen', function ()
  describe('.rect_with', function ()
    before_each(function ()
      vim.o.columns = 12
      vim.o.lines = 8
    end)

    it('returns a rectangle definition for given constriants', function ()
      local x, y, w, h = screen.rect_with {
        width = 2,
        height = 3,
        halign = 'left',
        valign = 'top'
      }:unwrap()

      assert.are.same({0, 0, 2, 3}, {x, y, w, h})
    end)

    it('uses vim`s size configuration to calculate right align', function ()
      local x, y, w, h = screen.rect_with {
        width = 2,
        height = 3,
        halign = 'right',
        valign = 'top'
      }:unwrap()

      assert.are.same({10, 0, 2, 3}, {x, y, w, h})
    end)

    it('uses vim`s size configuration to calculate bottom align', function ()
      local x, y, w, h = screen.rect_with {
        width = 2,
        height = 3,
        halign = 'left',
        valign = 'bottom'
      }:unwrap()

      assert.are.same({0, 3, 2, 3}, {x, y, w, h})
    end)

    it('centers rects given a fixed width', function ()
      local x, y, w, h = screen.rect_with {
        width = 6,
        height = 3,
        halign = 'center',
        valign = 'top'
      }:unwrap()

      assert.are.same({3, 0, 6, 3}, {x, y, w, h})
    end)

    it('centers rects given a fixed height', function ()
      local x, y, w, h = screen.rect_with {
        width = 6,
        height = 4,
        halign = 'left',
        valign = 'center'
      }:unwrap()

      assert.are.same({0, 1, 6, 4}, {x, y, w, h})
    end)

    it("rounds down when centering doesn't work perfectly", function ()
      local x, y, w, h = screen.rect_with {
        width = 5,
        height = 3,
        halign = 'center',
        valign = 'center'
      }:unwrap()

      assert.are.same({3, 1, 5, 3}, {x, y, w, h})
    end)

    it('calculates percentage width', function ()
      local x, y, w, h = screen.rect_with {
        width = '50%',
        height = 3,
        halign = 'left',
        valign = 'top'
      }:unwrap()

      assert.are.same({0, 0, 6, 3}, {x, y, w, h})
    end)

    it('calculates percentage height', function ()
      local x, y, w, h = screen.rect_with {
        width = 4,
        height = '100%',
        halign = 'left',
        valign = 'top'
      }:unwrap()

      assert.are.same({0, 0, 4, 6}, {x, y, w, h})
    end)

    it('rounds percentage calculations down', function ()
      local x, y, w, h = screen.rect_with {
        width = '20%',
        height = '30%',
        halign = 'left',
        valign = 'top'
      }:unwrap()

      assert.are.same({0, 0, 2, 1}, {x, y, w, h})
    end)

    it('raises an error if the given width is bigger than whats available', function ()
      local res = screen.rect_with {
        width = 20,
        height = 2,
        halign = 'left',
        valign = 'top'
      }

      assert.is_false(res:ok())
      res:map_error(function (err)
        assert.equal('h-overflow', err.type)
        assert.equal(8, err.overflow)
      end)
    end)

    it('raises an error if the given height is bigger than whats available', function ()
      local res = screen.rect_with {
        width = 5,
        height = 10,
        halign = 'left',
        valign = 'top'
      }

      assert.is_false(res:ok())
      res:map_error(function (err)
        assert.equal('v-overflow', err.type)
        assert.equal(4, err.overflow)
      end)
    end)

    it('truncate given size if needed and truncate flag is given', function ()
      local x, y, w, h = screen.rect_with {
        width = 20,
        height = 15,
        halign = 'left',
        valign = 'top',
        truncate = true
      }:unwrap()

      assert.are.same({0, 0, 12, 6}, {x, y, w, h})
    end)
  end)
end)
