require 'minitest/autorun'
require 'byebug'

class Parser
  POINT = /\APOINT\ ?\((?<points>[\d\.\-\ ]+)\)\z/
  POINT_Z = /\APOINT\ ?Z\ \((?<points>[\d\.\-\ ]+)\)\z/
  LINESTRING = /\ALINESTRING\ ?\((?<points>[\d\.,\-\ ]+)\)\z$/
  LINESTRING_Z = /\ALINESTRING\ ?Z\ \((?<points>[\d\.,\-\ ]+)\)\z/

  def self.from_wkt(well_known_text)
    points_text = case well_known_text
                  when POINT
                    type = :point
                    well_known_text.match(POINT)[:points]
                  when POINT_Z
                    type = :point_z
                    well_known_text.match(POINT_Z)[:points]
                  when LINESTRING
                    type = :linestring
                    well_known_text.match(LINESTRING)[:points]
                  when LINESTRING_Z
                    type = :linestring_z
                    well_known_text.match(LINESTRING_Z)[:points]
                  else
                    raise "Unsupported format: #{well_known_text}"
                  end.strip

    points = points_text.split(',').map { |point_text| point_text.split(' ') }.map do |x, y, z|
      Point.new(x: x, y: y, z: z)
    end

    new(points, type)
  end

  def initialize(points, type)
    @points = points
    @type = type
  end

  def to_wkt
    case @type
    when :point
      point = points.first
      "POINT(#{point.x} #{point.y})"
    when :point_z
      point = points.first
      "POINT Z (#{point.x} #{point.y} #{point.z})"
    when :linestring
      "LINESTRING(#{points.map { |p| "#{p.x} #{p.y}" }.join(', ')})"
    when :linestring_z
      "LINESTRING Z (#{points.map { |p| "#{p.x} #{p.y} #{p.z}" }.join(', ')})"
    end
  end

  def points
    @points
  end
end

class ParserTest < Minitest::Test
  def test_point_parsing
    parser = Parser.from_wkt('POINT(30.0 10.0)')

    assert_equal parser.to_wkt, 'POINT(30.0 10.0)'
    assert_equal parser.points, [Point.new(x: 30, y: 10, z: nil)]
  end

  def test_point_z_parsing
    parser = Parser.from_wkt('POINT Z (30 10 5)')

    assert_equal parser.to_wkt, 'POINT Z (30.0 10.0 5.0)'
    assert_equal parser.points, [Point.new(x: 30, y: 10, z: 5)]
  end

  def test_line_string_parsing
    parser = Parser.from_wkt('LINESTRING(30.0 10.0, 10.0 30.0, 40.0 40.0)')

    assert_equal parser.to_wkt, 'LINESTRING(30.0 10.0, 10.0 30.0, 40.0 40.0)'
    assert_equal parser.points, [
      Point.new(x: 30, y: 10, z: nil),
      Point.new(x: 10, y: 30, z: nil),
      Point.new(x: 40, y: 40, z: nil)
    ]
  end

  def test_line_string_z_parsing
    parser = Parser.from_wkt('LINESTRING Z (30.0 10.0 40.0, 10.0 30.0 20.0, 40.0 40.0 10.0)')

    assert_equal parser.to_wkt, 'LINESTRING Z (30.0 10.0 40.0, 10.0 30.0 20.0, 40.0 40.0 10.0)'
    assert_equal parser.points, [
      Point.new(x: 30, y: 10, z: 40),
      Point.new(x: 10, y: 30, z: 20),
      Point.new(x: 40, y: 40, z: 10)
    ]
  end
end

class Point
  attr_reader :x, :y, :z


  def initialize(x:, y:, z:)
    @x = x.is_a?(String) ? x.to_f : x
    @y = y.is_a?(String) ? y.to_f : y
    @z = z.is_a?(String) ? z.to_f : z || 0.0
  end

  def ==(other)
    self.class == other.class &&
    x.round(5) == other.x.round(5) &&
    y.round(5) == other.y.round(5) &&
    z.floor(12) == other.z.floor(12)
  end

  alias :eql? :==
end

class Transfrom
  def initialize(points)
    @points = points
  end

  def execute
    points_string = points.map { |p| "#{p.y} #{p.x} #{p.z}" }.join("\n")
    %x{echo '#{points_string}' | cs2cs -d 12 EPSG:4326 EPSG:6691}.split("\n")
      .map { |p| p.split(" ").map(&:to_f) }
      .map { |x, y, z| Point.new(x: x, y: y, z: z)  }
  end

  private

  attr_reader :points
end

class TransfromTest < Minitest::Test
  def test_long_2d_linestings
    long_2d_4326_points = Parser.from_wkt(File.open("test/long_2d_4326_linestring.txt").read.strip).points
    long_2d_6691_points = Parser.from_wkt(File.open("test/long_2d_6691_linestring.txt").read.strip).points

    assert_equal Transfrom.new(long_2d_4326_points).execute, long_2d_6691_points
  end

  def test_long_2d_linestings
    long_3d_4326_points = Parser.from_wkt(File.open("test/long_3d_4326_linestring.txt").read.strip).points
    long_3d_6691_points = Parser.from_wkt(File.open("test/long_3d_6691_linestring.txt").read.strip).points

    assert_equal Transfrom.new(long_3d_4326_points).execute, long_3d_6691_points
  end

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
