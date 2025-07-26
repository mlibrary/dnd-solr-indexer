module SolrIndexer
  class MultiSourceField
    attr_reader :source, :destination, :join

    def initialize(source, destination, join = " ")
      @source = [source].flatten
      @destination = [destination].flatten
      @join = join
    end
  end
end
