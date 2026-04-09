module SolrIndexer
  class Base
    attr_reader :config, :records, :submitter, :duration, :select, :segment

    def initialize(config, submitter)
      @config = config
      @segment = config["segment"] || "default"
      @select = config["select"] || "+segment:#{@segment}"
      @records = []
      @submitter = submitter[config["submitter"] || "tidy"]
      @duration = Benchmark.realtime do
        fetch_records!
      end
    rescue => e
      puts e.full_message
      @failed = true
    end

    def failed?
      @failed ||= false
    end

    def submit
      if failed?
        puts "#{self.class.name}: Failed to fetch records, skipping submit."
        return self
      end
      submitter.submit(records, select, segment, duration)
      self
    rescue => e
      puts e.full_message
      @failed = true
      self
    end

    def to_json
      records.to_json
    end
  end
end
