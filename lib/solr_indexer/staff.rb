module SolrIndexer
  class Staff
    attr_reader :select, :submitter

    def initialize(config, submitter)
      @select = config["select"] || "-*:*"
      @submitter = submitter
      @data = JSON.parse(Net::HTTP.get(URI(config["data"])))

      @taxonomy = {}
      config["taxonomy"].each do |t|
        @taxonomy[t["name"]] = parse_terms(t["url"])
      end

      @node = SolrIndexer::Nodes.new
      config["nodes"].each do |n|
        @node.register(n["name"], n["url"])
      end

      @fields = {}
      load_fields(config["fields"])
    end

    def submit
      submitter.submit(records, select)
    end

    def load_fields(list)
      list.each do |field|
        type = field["type"]
        args = field["args"]
        @fields[type] ||= []
        @fields[type] << case type
        when "literal"
          LiteralField.new(*args)
        when "timestamp", "value", "location", "location_json"
          SimpleField.new(*args)
        when "concat", "photo"
          PrefixedField.new(*args)
        when "taxonomy_name", "taxonomy_tag", "taxonomy_keyword", "node"
          BundleField.new(*args)
        when "content"
          MultiSourceField.new(*args)
        end
      end
    end

    def to_xml
      Nokogiri::XML::Builder.new do |xml|
        xml.add do
          @data.each do |record|
            xml.doc_ do
              record_to_xml(record, xml)
            end
          end
        end
      end.to_xml
    end

    def records
      to_a
    end

    def to_a
      @data.map do |record|
        record_to_hash(record)
      end
    end

    def record_to_hash(record)
      result = {}

      @fields["literal"].each do |field|
        result[field.name] = field.value
      end

      @fields["value"].each do |field|
        record.fetch(field.source, []).map { |value| value["value"].to_s }.each do |content|
          field.destination.each do |field_name|
            if result.has_key?(field_name)
              result[field_name] += " " + content
            else
              result[field_name] = content
            end
          end
        end
      end

      @fields["timestamp"].each do |field|
        record.fetch(field.source, []).map { |value| value["value"].sub("+00:00", "Z").to_s }.each do |content|
          field.destination.each do |field_name|
            if result.has_key?(field_name)
              result[field_name] += " " + content
            else
              result[field_name] = content
            end
          end
        end
      end

      @fields["taxonomy_name"].each do |field|
        record.fetch(field.source, []).compact.map { |value| @taxonomy[field.name][value["target_uuid"]]&.name.to_s }.each do |content|
          field.destination.each do |field_name|
            next if content.nil? || content.empty?
            if result.has_key?(field_name)
              result[field_name] += " " + content
            else
              result[field_name] = content
            end
          end
        end
      end

      @fields["taxonomy_tag"].each do |field|
        record.fetch(field.source, []).compact.map { |value| @taxonomy[field.name][value["target_uuid"]]&.name.to_s.downcase.gsub(/[,()]/, "").gsub(/[^a-z'&-.]/, "_").squeeze("_").sub(/_+$/, "") }.each do |content|
          field.destination.each do |field_name|
            next if content.nil? || content.empty?
            if result.has_key?(field_name)
              result[field_name] += " " + content
            else
              result[field_name] = content
            end
          end
        end
      end

      @fields["taxonomy_keyword"].each do |field|
        record.fetch(field.source, []).compact.map { |value| @taxonomy[field.name][value["target_uuid"]]&.keywords.to_s }.each do |content|
          field.destination.each do |field_name|
            next if content.nil? || content.empty?
            if result.has_key?(field_name)
              result[field_name] += " " + content
            else
              result[field_name] = content
            end
          end
        end
      end

      @fields["node"].each do |field|
        [record.fetch(field.source, []).last].compact.map { |value| @node.lookup(field.name, value["target_uuid"]).to_s }.each do |content|
          field.destination.each do |field_name|
            next if content.nil? || content.empty?
            if result.has_key?(field_name)
              result[field_name] += " " + content
            else
              result[field_name] = content
            end
          end
        end
      end

      @fields["concat"].each do |field|
        record.fetch(field.source, []).map { |value| field.prefix + value["value"].to_s }.each do |content|
          field.destination.each do |field_name|
            if result.has_key?(field_name)
              result[field_name] += " " + content
            else
              result[field_name] = content
            end
          end
        end
      end

      @fields["photo"].each do |field|
        record.fetch(field.source, []).map { |photo| field.prefix + URI(photo["url"]).path.to_s }.each do |content|
          field.destination.each do |field_name|
            if result.has_key?(field_name)
              result[field_name] += " " + content
            else
              result[field_name] = content
            end
          end
        end
      end

      @fields["content"].each do |field|
        content = field.source.map { |source| record.fetch(source).map { |value| value["value"].to_s } }.flatten.join(field.join)
        field.destination.each do |field_name|
          if result.has_key?(field_name)
            result[field_name] += " " + content
          else
            result[field_name] = content
          end
        end
      end

      @fields["location"].each do |field|
        record.fetch(field.source, []).map do |location|
          location["address_line1"] + "\n" + location["locality"] + ", " + location["administrative_area"] + " " + location["postal_code"]
        end.each do |content|
          field.destination.each do |field_name|
            result[field_name] = if result.has_key?(field_name)
              [result[field_name], content].flatten
            else
              content
            end
          end
        end
      end

      @fields["location_json"].each do |field|
        record.fetch(field.source, []).map do |location|
          {
            "street" => location["address_line1"],
            "additional" => location["address_line2"],
            "postal_code" => location["postal_code"],
            "city" => location["locality"],
            "province" => location["administrative_area"],
            "country" => location["country_code"]
          }.to_json
        end.each do |content|
          field.destination.each do |field_name|
            result[field_name] = if result.has_key?(field_name)
              [result[field_name], content].flatten
            else
              content
            end
          end
        end
      end
      result
    end

    def record_to_xml(record, xml)
      @fields["literal"].each do |field|
        xml.field(name: field.name) { xml.text(field.value) }
      end

      @fields["value"].each do |field|
        record.fetch(field.source, []).map { |value| value["value"].to_s }.each do |content|
          field.destination.each do |field_name|
            xml.field(name: field_name) { xml.text(content) }
          end
        end
      end

      @fields["timestamp"].each do |field|
        record.fetch(field.source, []).map { |value| value["value"].sub("+00:00", "Z").to_s }.each do |content|
          field.destination.each do |field_name|
            xml.field(name: field_name) { xml.text(content) }
          end
        end
      end

      @fields["taxonomy_name"].each do |field|
        record.fetch(field.source, []).compact.map { |value| @taxonomy[field.name][value["target_uuid"]]&.name.to_s }.each do |content|
          field.destination.each do |field_name|
            next if content.nil? || content.empty?
            xml.field(name: field_name) { xml.text(content) }
          end
        end
      end

      @fields["taxonomy_tag"].each do |field|
        record.fetch(field.source, []).compact.map { |value| @taxonomy[field.name][value["target_uuid"]]&.name.to_s.downcase.gsub(/[,()]/, "").gsub(/[^a-z'&-.]/, "_").squeeze("_").sub(/_+$/, "") }.each do |content|
          field.destination.each do |field_name|
            next if content.nil? || content.empty?
            xml.field(name: field_name) { xml.text(content) }
          end
        end
      end

      @fields["taxonomy_keyword"].each do |field|
        record.fetch(field.source, []).compact.map { |value| @taxonomy[field.name][value["target_uuid"]]&.keywords.to_s }.each do |content|
          field.destination.each do |field_name|
            next if content.nil? || content.empty?
            xml.field(name: field_name) { xml.text(content) }
          end
        end
      end

      @fields["node"].each do |field|
        [record.fetch(field.source, []).last].compact.map { |value| @node.lookup(field.name, value["target_uuid"]).to_s }.each do |content|
          field.destination.each do |field_name|
            next if content.nil? || content.empty?
            xml.field(name: field_name) { xml.text(content) }
          end
        end
      end

      @fields["concat"].each do |field|
        record.fetch(field.source, []).map { |value| field.prefix + value["value"].to_s }.each do |content|
          field.destination.each do |field_name|
            xml.field(name: field_name) { xml.text(content) }
          end
        end
      end

      @fields["photo"].each do |field|
        record.fetch(field.source, []).map { |photo| field.prefix + URI(photo["url"]).path.to_s }.each do |content|
          field.destination.each do |field_name|
            xml.field(name: field_name) { xml.text(content) }
          end
        end
      end

      @fields["content"].each do |field|
        content = field.source.map { |source| record.fetch(source).map { |value| value["value"].to_s } }.flatten.join(field.join)
        field.destination.each do |field_name|
          xml.field(name: field_name) { xml.text(content) }
        end
      end

      @fields["location"].each do |field|
        record.fetch(field.source, []).map do |location|
          location["address_line1"] + "\n" + location["locality"] + ", " + location["administrative_area"] + " " + location["postal_code"]
        end.each do |content|
          field.destination.each do |field_name|
            xml.field(name: field_name) { xml.text(content) }
          end
        end
      end

      @fields["location_json"].each do |field|
        record.fetch(field.source, []).map do |location|
          {
            "street" => location["address_line1"],
            "additional" => location["address_line2"],
            "postal_code" => location["postal_code"],
            "city" => location["locality"],
            "province" => location["administrative_area"],
            "country" => location["country_code"]
          }.to_json
        end.each do |content|
          field.destination.each do |field_name|
            xml.field(name: field_name) { xml.text(content) }
          end
        end
      end
    end

    private
    def fetch_terms(url, data = [])
      page = JSON.parse(Net::HTTP.get(URI(url)))
      data += page["data"]
      if page["links"]["next"]
        fetch_terms(page["links"]["next"]["href"], data)
      else
        data
      end
    end

    def parse_terms(url)
      fetch_terms(url).map do |term|
        [term["id"], Term.new(term["attributes"]["name"], term["attributes"]["field_service_experts_keywords"])]
      end.to_h
    end
  end
end
