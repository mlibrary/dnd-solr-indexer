module SolrIndexer
  class XML < Base
    def fetch_records!
      xml = File.open(config["data"]) { |f| Nokogiri::XML(f) }
      xml.xpath("//doc").each do |doc|
        record = {}
        doc.xpath("field").each do |field|
          name = field.attribute("name").value
          value = field.text.strip
          next if value.empty?
          if record[name].is_a?(Array)
            record[name] << value
          elsif record[name]
            record[name] = [record[name], value]
          else
            record[name] = value
          end
        end
        @records << record
      end
      @records 
    end
  end
end
