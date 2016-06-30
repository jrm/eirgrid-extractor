require 'json'
require 'csv'


class FileProcessor
  
  Encoding.default_external = Encoding.list[1]
  
  SEP = /\s+/
  REF = /(?<ref>(?:T|D)G\d+(?:[a-z])?)/
  PROJECT = /(?<project>.*?(\s+\(\d\)?))/
  CONTACT = /(?<contact>.*?)/
  DATE = /(?<date>\d\d\/\d\d\/\d\d\d\d)/
  STATUS = /(?<status>On\s+Hold|Processing|Live)/
  LOCATION = /(?<location>.*?)/
  SIZE = /(?<size>[0-9]+(?:.[0-9]+)?)/
  PAGE_REGEX = /Page/
  LINE_REGEX1 = /\A#{REF}#{SEP}#{CONTACT}#{SEP}#{DATE}#{SEP}#{STATUS}#{SEP}#{LOCATION}#{SEP}#{SIZE}\Z/
  GEO_REGEX = /(?<geo>(?:N|E)\d+(?:,)?(?:N|E)\d+)/  
  
  #revised file format
  GEO_REGEX2 = /(?<geo_e>E\d+),\s(?<geo_n>N\d+)/  
  LINE_REGEX2 = /\A#{REF}#{SEP}#{CONTACT}#{SEP}#{DATE}#{SEP}#{STATUS}#{SEP}#{LOCATION}#{SEP}#{GEO_REGEX2}#{SEP}#{SIZE}\Z/
  
  
  attr_reader :rows
  
  def initialize(path, opts = {})
    @path = path
    @name = opts[:name]
    @process_id = Time.now.to_i
    @rows = {}
    @matched_records = 0
    @geo_referenced_records = 0
    @data_folder = File.expand_path('../../data', __FILE__)
    @bin_folder = File.expand_path('../../bin', __FILE__)
  end
  
  def process(opts = {})
    parse
    File.open("#{@data_folder}/eigrid-#{@process_id}.csv", "wb") do |file|
      file << csv
    end
    File.open("#{@data_folder}/eigrid-#{@process_id}.kml", "wb") do |file|
      file << kml
    end
    yield self if block_given?    
  end
  
  def preview
    {process_id: @process_id, rows: @rows.values}
  end  
  
  def kml
    kml = KMLFile.new
    document = KML::Document.new(:name => @name)
    rows = @rows.values
    [ {id: 'live', color: '#0f0', icon: 'ball.png'},
      {id: 'processing', color: '#0ff', icon: 'ball.png'},
      {id: 'onhold', color: '#ff0', icon: 'ball.png'} ].each do |s|
      document.styles << KML::Style.new(
        :id         => "#{s[:style]}-style",
        :icon_style => KML::IconStyle.new(:icon => KML::Icon.new(:href => s[:icon]))
      )
    end
    folder = KML::Folder.new(:name => "Records")    
    folders = {}    
    total = rows.size
    rows.each_with_index do |row,i|
      status = row[:status] ? row[:status].gsub("\s",'') : 'NoStatus'
      style = status.downcase
      unless folders[row[:company]]
        folder.features << folders[row[:company]] = KML::Folder.new(:name => row[:company])
      end
      folders[row[:company]].features << KML::Placemark.new(
        :name => "#{row[:ref]} - #{row[:project]} - #{row[:size]}",
        :description => "#{row[:base_contact]}",
        :geometry    => KML::Point.new(:coordinates => {lat: row[:geo][:lat], lng: row[:geo][:lng]}),
        :style_url   => "##{style}-style"
      )
    end 
    document.features << folder
    kml.objects << document
    kml.render
  end
  
  def csv
    rows = @rows.values
    headers = ["Ref","Project","Company","Contact","Project/Company/Contact","Date","Status","Location","Size","N","E","Lat","Lng"]
    csv_data  = CSV.generate do |csv|
      csv << headers
      rows.each do |row|
        status = row[:status] ? row[:status].gsub("\s",'') : 'NoStatus'
        csv << [
          row[:ref],
          row[:project],
          row[:company],
          row[:contact],
          row[:base_contact],
          row[:date],
          status,
          row[:location],
          row[:size],
          row[:geo][:n],
          row[:geo][:e],
          row[:geo][:lat],
          row[:geo][:lng],
        ]
      end
    end
    csv_data   
  end
  
  private
  
  def parse(opts = {})
    text = `#{@bin_folder}/pdftotext -enc UTF-8 -table #{@path} -`
    current_ref = nil
    index = 0
    text.split("\n").each do |line|      
      line.strip!
      next if line.size == 0 || line =~ PAGE_REGEX
      if md1 = line.match(LINE_REGEX2)
        
        index += 1
        current_ref = md1[:ref]
        @matched_records += 1
        if md_p = md1[:contact].match(/\A(.*?)\s{2,}?(.*?),(.*)\Z/)
          project = md_p[1].strip
          company = md_p[2].strip
          contact = md_p[3].strip
        end
        @rows[current_ref] = {
          ref: current_ref,
          index: index,
          project: project, 
          company: company, 
          contact: contact, 
          base_contact: md1[:contact], 
          date: md1[:date],
          status: md1[:status],
          location: md1[:location],
          size: md1[:size],
          rem:"", 
          geo: {n: md1[:geo_n], e: md1[:geo_e], lat: 0, lng: 0}
        }
        if latlng = irish_to_last_long(rows[current_ref][:geo])
          @rows[current_ref][:geo].merge!(latlng)
        end
        
        next
        
      elsif md1 = line.match(LINE_REGEX1)
        
        index += 1
        current_ref = md1[:ref]
        @matched_records += 1
        if md_p = md1[:contact].match(/\A(.*?)\s{2,}?(.*?),(.*)\Z/)
          project = md_p[1].strip
          company = md_p[2].strip
          contact = md_p[3].strip
        end
        @rows[current_ref] = {
          ref: current_ref,
          index: index,
          project: project, 
          company: company, 
          contact: contact, 
          base_contact: md1[:contact], 
          date: md1[:date],
          status: md1[:status],
          location: md1[:location],
          size: md1[:size],
          rem:"", 
          geo: {n: "0", e: "0", lat: 0, lng: 0}
        }
        
      else
        @rows[current_ref] && @rows[current_ref][:rem] << line.strip.gsub("\s","")
        if @rows[current_ref] 
          rem = @rows[current_ref][:rem]
          next if rem.size == 0
          if md_g = @rows[current_ref][:rem].match(GEO_REGEX)
            @geo_referenced_records += 1
            if md_g[:geo].match(/(N\d+)/)
              @rows[current_ref][:geo][:n] = $1
            end
            if md_g[:geo].match(/(E\d+)/)
              @rows[current_ref][:geo][:e] = $1
            end
            if latlng = irish_to_last_long(@rows[current_ref][:geo])
              @rows[current_ref][:geo].merge!(latlng)
            end
          end
        end
      end
    end
  end
  
  def irish_to_last_long(coord)
    e = coord[:e].gsub("E",'').to_i
    n = coord[:n].gsub("N",'').to_i
    en = Breasal::EastingNorthing.new(easting: e, northing: n, type: :ie)
    begin
      if wgs84 = en.to_wgs84 # => {:latitude=>52.67752501534847, :longitude=>-1.8148108086293673}
        {lat: wgs84[:latitude], lng: wgs84[:longitude]}
      end
    rescue
      {lat: 0, lng: 0}
    end
  end
  
  
end