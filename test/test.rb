require 'minitest/autorun'
require 'byebug'

class WktCs2Cs
  def initialize(from_cs, to_cs, reverse_input: false, reverse_output: false)
    @from_cs = from_cs
    @to_cs = to_cs
    @reverse_input = reverse_input
    @reverse_output = reverse_output
  end

  def parse(well_known_text)
    parsed_wky = WktParser.parse(well_known_text)

    %x{echo '#{parsed_wky.point_list_text}' | cs2cs -d 12 #{'-r' if @reverse_input} #{'-s' if @reverse_output} '#{@from_cs}' '#{@to_cs}'}
      .strip
      .then { |point_list_text| WktBuilder.new(point_list_text, parsed_wky.type).build }
  end

  class WktBuilder
    def initialize(point_list_text, type)
      @point_list_text = point_list_text
      @type = type
    end

    def build
      case @type
      when :point
        "POINT(#{point_list_text})"
      when :point_z
        "POINT Z (#{point_list_text})"
      when :linestring
        "LINESTRING(#{point_list_text})"
      when :linestring_z
        "LINESTRING Z (#{point_list_text})"
      when :polygon
        "POLYGON((#{point_list_text}))"
      end
    end

    def has_z?
      @type.to_s.end_with?('_z')
    end

    def point_list_text
      @point_list_text
        .split("\n")
        .map { |p| p.split(" ").map(&:to_f) }
        .map { |p| has_z? ? p : p.first(2) }
        .map { |p| p.join(' ') }.join(', ')
    end
  end

  class WktParser
    POINT = /\APOINT\ ?\((?<points>[\d\.\-\ ]+)\)\z/
    POINT_Z = /\APOINT\ ?Z\ \((?<points>[\d\.\-\ ]+)\)\z/
    LINESTRING = /\ALINESTRING\ ?\((?<points>[\d\.,\-\ ]+)\)\z$/
    LINESTRING_Z = /\ALINESTRING\ ?Z\ \((?<points>[\d\.,\-\ ]+)\)\z/
    POLYGON = /\APOLYGON\ ?\(\((?<points>[\d\.,\-\ ]+)\)\)\z$/

    def self.parse(well_known_text)
      point_list_text =  case well_known_text.strip
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
                when POLYGON
                  type = :polygon
                  well_known_text.match(POLYGON)[:points]
                else
                  raise "Unsupported format: #{well_known_text}"
                end.split(',')
                  .join("\n")

      new(point_list_text, type)
    end

    def initialize(point_list_text, type)
      @point_list_text = point_list_text
      @type = type
    end

    attr_reader :point_list_text, :type
  end
end

class WktCs2CsParseAndParseBackTest < Minitest::Test
  DELTA = 0.0000001

  def parse_and_parse_back(well_known_text)
    WktCs2Cs.new('EPSG:6691', 'EPSG:4326', reverse_output: true).parse(WktCs2Cs.new('EPSG:4326', 'EPSG:6691', reverse_input: true).parse(well_known_text))
  end

  def test_point_parsing
    assert_equal_well_known_text parse_and_parse_back('POINT(30.0 10.0)'), 'POINT(30.0 10.0)', DELTA
  end

  def test_point_z_parsing
    assert_equal_well_known_text parse_and_parse_back('POINT Z (30.0 10.0 5.0)'), 'POINT Z (30.0 10.0 5.0)', DELTA
  end

  def test_line_string_parsing
    assert_equal_well_known_text parse_and_parse_back('LINESTRING(30.0 10.0, 10.0 30.0, 40.0 40.0)'),
      'LINESTRING(30.0 10.0, 10.0 30.0, 40.0 40.0)', DELTA
  end

  def test_line_string_z_parsing
    assert_equal_well_known_text parse_and_parse_back('LINESTRING Z (30.0 10.0 40.0, 10.0 30.0 20.0, 40.0 40.0 10.0)'),
      'LINESTRING Z (30.0 10.0 40.0, 10.0 30.0 20.0, 40.0 40.0 10.0)', DELTA
  end

  def test_polygon_parsing
    assert_equal_well_known_text parse_and_parse_back('POLYGON((30.0 10.0, 40.0 40.0, 20.0 40.0, 10.0 20.0, 30.0 10.0))'),
      'POLYGON((30.0 10.0, 40.0 40.0, 20.0 40.0, 10.0 20.0, 30.0 10.0))', DELTA
  end

  def test_long_2d_linesting_parsing
    assert_equal_well_known_text parse_and_parse_back(File.open("test/long_2d_4326_linestring.txt").read.strip),
      File.open("test/long_2d_4326_linestring.txt").read.strip, DELTA
  end

  def test_long_3d_linesting_parsing
    assert_equal_well_known_text parse_and_parse_back(File.open("test/long_3d_4326_linestring.txt").read.strip),
      File.open("test/long_3d_4326_linestring.txt").read.strip, DELTA
  end
end

class WtkCs2CsTransformationTest < Minitest::Test
  def cs2cs
    WktCs2Cs.new('EPSG:4326', 'EPSG:6691', reverse_input: true)
  end

  def test_long_2d_linesting
    assert_equal_well_known_text cs2cs.parse(File.open("test/long_2d_4326_linestring.txt").read.strip),
      File.open("test/long_2d_6691_linestring.txt").read.strip, 0.000001
  end

  def test_long_3d_linesting
    assert_equal_well_known_text cs2cs.parse(File.open("test/long_3d_4326_linestring.txt").read.strip),
      File.open("test/long_3d_6691_linestring.txt").read.strip, 0.000001
  end
end

def assert_equal_well_known_text(expectation, actual, delta)
  a_p = WktCs2Cs::WktParser.parse(expectation).point_list_text.split("\n").map { |p_s| p_s.split(' ').map(&:to_f) }
  b_p = WktCs2Cs::WktParser.parse(actual).point_list_text.split("\n").map { |p_s| p_s.split(' ').map(&:to_f) }
  a_p.zip(b_p).each do |a_p, b_p|
    assert_in_delta a_p[0], b_p[0], delta
    assert_in_delta a_p[1], b_p[1], delta
    assert_equal a_p[2], b_p[2] if a_p[2] || b_p[2]
  end
end
