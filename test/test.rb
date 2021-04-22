require 'minitest/autorun'
require 'byebug'

class Point
  attr_reader :x, :y, :z

  def initialize(x:, y:, z:)
    @x = x
    @y = y
    @z = z
  end
end

class PointTest < Minitest::Test
  def test_coords
    point = Point.new(x: 1, y: 2, z: 3)

    assert point.x == 1
    assert point.y == 2
    assert point.z == 3
  end
end
