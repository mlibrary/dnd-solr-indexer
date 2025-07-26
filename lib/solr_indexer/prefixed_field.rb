module SolrIndexer
  class PrefixedField
    attr_reader :source, :destination, :prefix

    def initialize(source, destination, prefix)
      @source = source
      @destination = [destination].flatten
      @prefix = prefix
    end
  end
end
