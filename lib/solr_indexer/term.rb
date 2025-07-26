module SolrIndexer
  class Term
    attr_reader :name, :keywords
    def initialize(name, keywords)
      @name = name
      @keywords = keywords
    end
  end
end
