module SolrIndexer
  class SimpleField
    attr_reader :source, :destination

    def initialize(source, destination)
      @source = source
      @destination = [destination].flatten
    end
  end
end
