module SolrIndexer
  class Metadata
    attr_reader :best_bets, :academic_disciplines

    BEST_BETS = 'head meta[name="Best Bet"]'
    ACADEMIC_DISCIPLINE = 'head meta[name="Academic Discipline"]'

    def initialize(url)
      url = "http:" + url if url.start_with?("//")
      xml = Nokogiri.parse(Mechanize.new.get(url).body)
      @best_bets = xml.css(BEST_BETS).map do |meta|
        meta.attributes["content"].value
      end
      @academic_disciplines = xml.css(ACADEMIC_DISCIPLINE).map do |meta|
        meta.attributes["content"].value
      end
    rescue => e
      puts e.inspect
      @best_bets = []
      @academic_disciplines = []
    end
  end
end
