module SolrIndexer
  class Base
    attr_reader :config, :records, :submitter, :duration, :select, :segment

    def initialize(config, submitter)
      @config = config
      @segment = config["segment"] || "default"
      @select = config["select"] || "+segment:#{@segment}"
      @records = []
      @submitter = submitter
      @duration = Benchmark.realtime do
        fetch_records!
      end
    end

    def submit
      submitter.submit(records, select, segment, duration)
    end

    def to_json
      records.to_json
    end
  end
end
