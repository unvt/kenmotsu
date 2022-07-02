require 'sinatra'
require 'nokogiri'
require './constants'

get '/kenmotsu' do
#  content_type 'application/vnd.google-earth.kml+xml'
  content_type 'text/plain'
  p params
  query = params.map{|k, v| "#{k}=#{v}"}.join('&')
  url = "https://#{HOST}/kenmotsu/leaf?#{query}"
  builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') {|xml|
    xml.kml('xmlns' => 'http://www.opengis.net/kml/2.2') {
      xml.Document {
        xml.name '地理院地図KML'
        xml.open 1
        xml.Folder {
          xml.name '地理院地図KML SuperOverlay'
          xml.open 0
          xml.NetworkLink {
            xml.name params['t']
            xml.open 1
            xml.Url {
              xml.href url
              xml.viewRefreshMode 'onStop'
              xml.viewRefreshTime 0.1
            }
          }
        }
      }
    }
  }
  builder.to_xml
end

# thanks: @mapbox/tilebelt
def up(tile, dz)
  [tile[0] >> dz, tile[1] >> dz, tile[2] - dz]
end

def bboxToTile(bboxCoords, z)
  min = pointToTile(bboxCoords[0], bboxCoords[1], z)
  max = pointToTile(bboxCoords[2], bboxCoords[3], z)
  0.upto(z) {|dz|
    min_ = up(min, dz)
    max_ = up(max, dz)
    print "min #{up(min, dz)}, max #{up(max, dz)}\n"
    return min_ if min_ == max_
  }
end

def pointToTile(lon, lat, z)
  tile = pointToTileFraction(lon, lat, z)
  tile[0] = tile[0].floor
  tile[1] = tile[1].floor
  tile
end

D2R = Math::PI / 180
R2D = 180 / Math::PI

def pointToTileFraction(lon, lat, z)
  sin = Math.sin(lat * D2R)
  z2 = 2 ** z
  x = z2 * (lon / 360.0 + 0.5)
  y = z2 * (0.5 - 0.25 * Math.log((1 + sin) / (1 - sin)) / Math::PI)
  x = x % z2
  x += z2 if x < 0
  [x, y, z]
end

get '/kenmotsu/leaf' do
  content_type 'text/plain'
  # t=std&minzoom=8&maxzoom=16&ext=png&BBOX=138.5460879393046,35.29046093766914,138.7444408891545,35.39711339773409
  p params
  bbox = params['BBOX'].split(',').map{|v| v.to_f}
  maxzoom = params['maxzoom'] ? params['maxzoom'].to_i : MAXZOOM
  b = bboxToTile(bbox, maxzoom - DZ)
  builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') {|xml|
    xml.kml('xmlns' => 'http://www.opengis.net/kml/2.2') {

  (2 ** DZ).times {|dy|
    (2 ** DZ).times {|dx|
      print [b[0] * 2 ** DZ + dx, b[1] * 2 ** DZ + dy, b[2] + DZ], "\n"
    }
  }

    }
  }
  print builder.to_xml
end
