module SolrIndexer
  class OnlineExhibits < Base
    def fetch_records!
      JSON.parse(Faraday.get(config["url"]).body).each do |record|
        records << {
          id: record["url"],
          url: record["url"],
          title: record["title"],
          og_groups_both: record["tags"],
          content: SolrIndexer.strip_html_tags(record["description"]),
          status: 1,
          source: "drupal",
          segment: "online-exhibits",
          important: false,
          ssfield_page_type: "Online Exhibits"
        }
      end
    rescue StandardError => e
      puts e.inspect
    end
  end
end
