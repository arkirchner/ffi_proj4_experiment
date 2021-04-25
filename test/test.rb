require 'minitest/autorun'
require 'byebug'

class Parser
  POINT = /\APOINT\ \((?<points>.+)\)\z/

  def self.from_wkt(well_known_text)
    case well_known_text
    when POINT
      new(well_known_text)
    else
      raise "Unsupported format: #{well_known_text}"
    end
  end

  def initialize(wkt)
    @wkt = wkt
    @points = wkt.match(POINT)[:points].split(',').map do |wkt_point|
      x, y, z = wkt_point.split(" ")
      Point.new(x: x, y: y, z: z)
    end
  end

  def to_wkt
    @wkt
  end

  def points
    @points
  end
end

class ParserTest < Minitest::Test
  def test_point_parsing
    parser = Parser.from_wkt('POINT (30 10)')

    assert_equal parser.to_wkt, 'POINT (30 10)'
    assert_equal parser.points, [Point.new(x: 30, y: 10, z: nil)]
  end

  # def test_point_z_parsing
  #   parser = Parser.from_wkt('POINT Z (30 10 5)')

  #   assert_equal parser.to_wkt, 'POINT Z (30 10 5)'
  #   assert_equal parser.points, [Point.new(x: 30, y: 10, z: 5)]
  # end

  # def test_line_string_parsing
  #   parser = Parser.from_wkt('LINESTRING (30 10, 10 30, 40 40)')

  #   assert_equal parser.to_wkt, 'LINESTRING (30 10, 10 30, 40 40)'
  #   assert_equal parser.points, [
  #     Point.new(x: 30, y: 10, z: nil),
  #     Point.new(x: 10, y: 30, z: nil),
  #     Point.new(x: 40, y: 40, z: nil)
  #   ]
  # end

  # def test_line_string_z_parsing
  #   parser = Parser.from_wkt('LINESTRING Z (30 10 40, 10 30 20, 40 40 10)')

  #   assert_equal parser.to_wkt, 'LINESTRING Z (30 10 40, 10 30 20, 40 40 10)'
  #   assert_equal parser.points, [
  #     Point.new(x: 30, y: 10, z: 40),
  #     Point.new(x: 10, y: 30, z: 20),
  #     Point.new(x: 40, y: 40, z: 10)
  #   ]
  # end
end

class Point
  attr_reader :x, :y, :z


  def initialize(x:, y:, z:)
    @x = x.is_a?(String) ? x.to_i : x
    @y = y.is_a?(String) ? y.to_i : y
    @z = z.is_a?(String) ? z.to_i : z
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
