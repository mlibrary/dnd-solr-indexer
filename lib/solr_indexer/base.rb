module SolrIndexer
  class Base
    attr_reader :config, :records, :submitter, :duration, :select

    def initialize(config, submitter)
      @config = config
      @select = config["select"] || "-*:*"
      @records = []
      @submitter = submitter
      @duration = Benchmark.realtime do
        fetch_records!
      end
    end

    def submit
      submitter.submit(records, select, duration)
    end

    def to_json
      records.to_json
    end
  end
end
