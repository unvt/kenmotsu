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

def tileToBBOX(tile)
  [
    tile2lon(tile[0], tile[2]),
    tile2lat(tile[1] + 1, tile[2]),
    tile2lon(tile[0] + 1, tile[2]),
    tile2lat(tile[1], tile[2])
  ]
end

def tile2lon(x, z) 
  x.to_f / 2 ** z * 360.0 - 180.0
end

def tile2lat(y, z)
  n = Math::PI - 2 * Math::PI * y / 2 ** z
  R2D * Math.atan(0.5 * (Math.exp(n) - Math.exp(-n)))
end

get '/kenmotsu/gdal' do
  content_type 'text/plain'
  # https://x.optgeo.org/kenmotsu/gdal?z=2&x=3&y=1&minzoom=2&maxzoom=18&template=https://maps.gsi.go.jp/xyz/std/{z}/{x}/{y}.png
  p params
  (z, x, y, minzoom, maxzoom) = %w{z x y minzoom maxzoom}.map {|k|
    params[k].to_i
  }
  template = params['template']
  drawOrder = (x == 0) ? 2 * z + 1 : 2 * z
  (w, s, e, n) = tileToBBOX([x, y, z])
  print "#{z}/#{x}/#{y} -> #{w} #{s} #{e} #{n}\n"
  builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') {|xml|
    xml.kml('xmls' => 'http://www.opengis.net/kml/2.2') {
      xml.Document {
        xml.Style {
          xml.ListStyle('id' => 'hideChildren') {
            xml.listItemType 'checkHideChildren'
          }
        }
        xml.Region {
          xml.LatLonAltBox {
            xml.west w
            xml.south s
            xml.east e
            xml.north n
          }
          xml.Lod {
            xml.minLodPixels (z == minzoom) ? 32 : MINLODPIXELS
            xml.maxLodPixels (z == maxzoom) ? -1 : MAXLODPIXELS
          }
        }
        xml.GroundOverlay {
          xml.drawOrder drawOrder
          xml.Icon {
            xml.href template.
              sub('{z}', z.to_s).
              sub('{x}', x.to_s).
              sub('{y}', y.to_s)
          }
          xml.LatLonBox {
            xml.west w
            xml.south s
            xml.east e
            xml.north n
          }
        }
        2.times {|dy|
          2.times {|dx|
            cz = z + 1
            break if cz > maxzoom
            cx = 2 * x + dx
            cy = 2 * y + dy
            (cw, cs, ce, cn) = tileToBBOX([cx, cy, cz])
            xml.NetworkLink {
              xml.Region {
                xml.LatLonAltBox {
                  xml.west cw
                  xml.south cs
                  xml.east ce
                  xml.north cn
                }
                xml.Lod {
                  xml.minLodPixels MINLODPIXELS
                  xml.maxLodPixels (cz == MAXZOOM) ? -1 : MAXLODPIXELS
                }
              }
              xml.Link {
                xml.href "/gdal?z=#{cz}&x=#{cx}&y=#{cy}&minzoom=#{minzoom}&maxzoom=#{maxzoom}&template=#{template}"
                xml.viewRefreshMode 'onRegion'
              }
            }
          }
        }
      }
    }
  }
  builder.to_xml
end

get '/kenmotsu/manifold' do
  content_type 'text/plain'
  maxzoom = params['maxzoom'] || 18
  template = params['template'] || 
    'https://maps.gsi.go.jp/xyz/std/{z}/{x}/{y}.png'
  builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') {|xml|
    xml.kml('xmlns' => 'http://www.opengis.net/kml/2.2') {
      xml.Document {
        xml.name template
        xml.Style {
          xml.ListStyle('id' => 'hideChildren') {
            xml.listItemType 'chechHideChildren'
          }
        }
        (zo, xo, yo) = [2, 3, 1]
        8.times {|dy|
          8.times {|dx|
            z = zo + 3
            x = xo * 8 + dx
            y = yo * 8 + dy
            (w, s, e, n) = tileToBBOX([x, y, z])
            xml.NetworkLink {
              xml.Region {
                xml.LatLonAltBox {
                  xml.west w
                  xml.south s
                  xml.east e
                  xml.north n
                }
                xml.Lod {
                  xml.minLodPixels 32
                  xml.maxLodPixels MAXLODPIXELS
                }
              }
              xml.Link {
                xml.href "/gdal?z=#{z}&x=#{x}&y=#{y}&minzoom=#{z}&maxzoom=#{maxzoom}&template=#{template}"
                xml.viewRefreshMode 'onregion'
              }
            }
          }
        }
      }
    }
  }
  builder.to_xml
end

get '/kenmotsu/leaf' do
  content_type 'text/plain'
  # t=std&minzoom=8&maxzoom=16&ext=png&BBOX=138.5460879393046,35.29046093766914,138.7444408891545,35.39711339773409
  p params
  bbox = params['BBOX'].split(',').map{|v| v.to_f}
  maxzoom = params['maxzoom'] ? params['maxzoom'].to_i : MAXZOOM
  min = pointToTileFraction(bbox[0], bbox[1], maxzoom)
  max = pointToTileFraction(bbox[2], bbox[3], maxzoom)
  mid = pointToTileFraction(
    (bbox[0] + bbox[2]) / 2,
    (bbox[1] + bbox[3]) / 2,
    maxzoom)
  print "mid #{mid}, width = #{Math.log2(max[0] - min[0])}\n"
  delta = Math.log2(max[0] - min[0]).floor
  t = params['t']
  ext = params['ext']
  #b = bboxToTile(bbox, maxzoom - DZ)
  b = [mid[0].floor >> delta, mid[1].floor >> delta, maxzoom - delta]
  print "b=#{b}\n"
  builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') {|xml|
    xml.kml('xmlns' => 'http://www.opengis.net/kml/2.2') {
      xml.Document {
        xml.Folder {
          (2 ** DZ).times {|dy|
            (2 ** DZ).times {|dx|
              z = b[2] + DZ
              x = b[0] * 2 ** DZ + dx
              y = b[1] * 2 ** DZ + dy
              url = "https://maps.gsi.go.jp/xyz/#{t}/#{z}/#{x}/#{y}.#{ext}"
              #url = "https://x.optgeo.org/kenmotsu/xyz/#{t}/#{z}/#{x}/#{y}.#{ext}"
              (w, s, e, n) = tileToBBOX([x, y, z])
              xml.GroundOverlay {
                xml.name ''
                xml.Icon {
                  xml.href url
                }
                xml.LatLonBox {
                  xml.west w
                  xml.south s
                  xml.east e
                  xml.north n
                }
              }
            }
          }
        }
      }
    }
  }
  content = builder.to_xml
  print content
  content
end
