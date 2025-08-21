module SolrIndexer
  class Reporter
    PUSH_GATEWAY = "http://pushgateway.prometheus:9091/metrics/job/solr_indexer"
    def initialize(status)
      @status = status
    end

    def instance
      "/instance/#{URI(@status[:url]).hostname}"
    end

    def segment
      "/segment/#{@status[:segment].gsub(%r{\+segment:|\(|\)}, "").gsub(" ", "--")}"
    end

    def labels
      ""
    end

    def duration
       @status[:duration]
    end

    def completed_at
      @status[:completed_at]
    end

    def before
      @status[:before]
    end

    def deleted
      @status[:deleted]
    end

    def updated
      @status[:updated]
    end

    def error
      @status[:error] ? 1 : 0
    end

    def prom_duration
      <<~PROM
        # HELP solr_indexer_duration_seconds Duration of Solr indexing operations in seconds
        # TYPE solr_indexer_duration_seconds gauge
        solr_indexer_duration_seconds#{labels} #{duration}
      PROM
    end

    def prom_completed_at
      <<~PROM
        # HELP solr_indexer_completed_at Timestamp for the most recent successful indexing operation
        # TYPE solr_indexer_completed_at gauge
        solr_indexer_completed_at#{labels} #{completed_at}
      PROM
    end

    def prom_before
      <<~PROM
        # HELP solr_indexer_before Number of documents already in the index matching the segment
        # TYPE solr_indexer_before gauge
        solr_indexer_before#{labels} #{before}
      PROM
    end

    def prom_updated
      <<~PROM
        # HELP solr_indexer_updated Number of documents updated in the index
        # TYPE solr_indexer_updated gauge
        solr_indexer_updated#{labels} #{updated}
      PROM
    end

    def prom_deleted
      <<~PROM
        # HELP solr_indexer_deleted Number of documents deleted from the index
        # TYPE solr_indexer_deleted gauge
        solr_indexer_deleted#{labels} #{deleted}
      PROM
    end

    def prom_error
      <<~PROM
        # HELP solr_indexer_error Indicates if there was an error during the indexing operation
        # TYPE solr_indexer_error gauge
        solr_indexer_error#{labels} #{error}
      PROM
    end

    def report
      prom = prom_duration +
        prom_completed_at +
        prom_before +
        prom_updated +
        prom_deleted +
        prom_error
      begin
        Faraday.post(PUSH_GATEWAY + instance + segment, prom)
      rescue => e
        puts e.message
        puts PUSH_GATEWAY + instance + segment
        puts prom
      end
    end
  end
end
