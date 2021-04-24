require 'minitest/autorun'
require 'byebug'

class Point
  attr_reader :x, :y, :z

  def initialize(x:, y:, z:)
    @x = x
    @y = y
    @z = z
  end

  def ==(other)
    self.class == other.class &&
    x == other.x &&
    y == other.y &&
    z == other.z
  end

  alias :eql? :==
end

class Transfrom
  def initialize(points)
    @points = points
  end

  def execute
    points_string = points.map { |p| "#{p.y} #{p.x} #{p.z}" }.join("\n")
    %x{echo '#{points_string}' | cs2cs -d 9 EPSG:4326 EPSG:6691}.split("\n")
      .map { |p| p.split(" ").map(&:to_f) }
      .map { |x, y, z| Point.new(x: x, y: y, z: z)  }
  end

  private

  attr_reader :points
end

class TransfromTest < Minitest::Test
  def test_point_6691_transformation
    points = [Point.new(x: 1, y: 2, z: 3), Point.new(x: 4, y: 5, z: 6)]
    # SELECT ST_AsText(
    #   ST_Transform(ST_SetSRID(ST_MakeLine(ST_MakePoint(1,2,3),
    #   ST_MakePoint(4,5,6)),4326), 6691)
    # );
    transformed_points = [
      Point.new(x: -4363323.630289483, y: 19706751.247232683, z: 3),
      Point.new(x: -4783719.117165595, y: 19239727.99342521, z: 6)
    ]

    assert_equal Transfrom.new(points).execute, transformed_points
  end
end


class PointTest < Minitest::Test
  def test_coords
    point = Point.new(x: 1, y: 2, z: 3)

    assert point.x == 1
    assert point.y == 2
    assert point.z == 3
  end

  def test_equality
    assert_equal Point.new(x: 1, y: 2, z: 3), Point.new(x: 1, y: 2, z: 3)
    assert Point.new(x: 2, y: 2, z: 3) != Point.new(x: 1, y: 2, z: 3)
  end
end
