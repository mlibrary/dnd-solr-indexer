module SolrIndexer
  class BundleField
    attr_reader :source, :destination, :name

    def initialize(source, destination, name)
      @source = source
      @destination = [destination].flatten
      @name = name
    end
  end
end
