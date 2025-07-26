module SolrIndexer
  class Nodes
    def initialize
      @terms = {}
      @urls = {}
    end

    def register(name, url)
      @terms[name] = {}
      @urls[name] = url
    end

    def lookup(name, id)
      @terms[name][id] ||= fetch(@urls[name], id)
    end

    def fetch(url, id)
      data = JSON.parse(Net::HTTP.get(URI(url + id)))
      data.dig("data", "attributes", "title")
    end
  end
end
