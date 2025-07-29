module SolrIndexer
  class LibGuides
    attr_reader :records, :select, :submitter, :duration, :config

    def initialize(config, submitter)
      @config = config
      @select = config["select"] || "-*:*"
      @submitter = submitter
      @duration = Benchmark.realtime do
        fetch_records!
      end
    end

    def fetch_records!
      oauth_url = "#{config["url"]}/oauth/token"
      oauth_params = {
        client_id: config["client_id"],
        client_secret: config["client_secret"],
        grant_type: "client_credentials"
      }
      access_token = JSON.parse(Faraday.post(oauth_url, oauth_params).body)["access_token"]

      guides_url = "#{config["url"]}/guides"
      guides_params = {expand: "owner,pages,pages.boxes,pages.boxes.assets,subjects,tags,metadata"}
      assets_url = "#{config["url"]}/assets/"
      content_conn = Faraday.new

      api_conn = Faraday.new do |f|
        f.headers["Authorization"] = "Bearer #{access_token}"
      end
      data = JSON.parse(api_conn.get(guides_url, guides_params).body)

      docs = []
      pages = []

      data.each do |guide|
        tags = TagArray.new((guide["tags"] || []).map { |tag| tag["text"] }).clean
        subjects = TagArray.new((guide["subjects"] || []).map { |subject| subject["name"] }).clean
        highly_recommended = (guide["metadata"] || [])
          .select { |metadata| ["Best Bet", "Highly Recommended"].include?(metadata["name"]) }
          .map { |metadata| metadata["content"] }
        academic_disciplines = (guide["metadata"] || [])
          .select { |metadata| metadata["name"] == "Academic Discipline" }
          .map { |metadata| metadata["content"] }
        base_id = (guide["friendly_url"] && guide["friendly_url"].length > 0) ? guide["friendly_url"] : guide["url"]
        base = {
          id: base_id,
          entity_id: guide["id"],
          body: guide["description"],
          tags: tags + subjects,
          type: guide["type_label"],
          title: guide["name"],
          sort_title: guide["name"],
          source: "libguides-guide",
          stitle: guide["name"],
          author: guide["owner"]["email"],
          ssfield_author: [guide["owner"]["first_name"], guide["owner"]["last_name"]].join(" "),
          status: guide["status"],
          teaser: guide["description"],
          teaser_stripped: guide["description"].gsub(/<[^>]*>/, ""),
          smfield_academic_discipline: academic_disciplines,
          content: [guide["description"], tags, academic_disciplines, highly_recommended].flatten.join(" ").gsub(%r{\s+}, " ").gsub(%r{\s$}, "").gsub(%r{^\s}, ""),
          og_groups_both: academic_disciplines + highly_recommended,
          segment: "2.0",
          ssfield_page_type: "Research Guides"
        }

        if ["best_bet", "best bet", "best bets", "best_bets"].any? { |tag| tags.include?(tag) }
          tags + highly_recommended
        else
          highly_recommended
        end.each do |tag|
          field = tag.gsub(/[,()!:;\[\]]/, "").gsub(/[\/ ]/, "_").downcase
          if field.length > 1
            base["isfield-order-" + field] = 1
            base["isfield-high-" + field] = 2
          end
        end
        docs << base
        api_conn.get(assets_url, {guide_ids: base[:entity_id]})
        guide["pages"].each do |page|
          next if page["enable_display"] == "0"
          p = base.clone
          p[:source] = "libguides-page"
          p[:id] = "#{base[:entity_id]}_#{page["id"]}"
          p[:url] = page["friendly_url"] || page["url"]
          p[:ssfield_page_title] =
            p[:tsfield_page_title] = page["name"]
          p[:sort_title] =
            p[:title] = "#{p[:ssfield_page_title]} on #{base[:title]}"
          p[:tmfield_page_content] = begin
            Nokogiri::HTML(content_conn.get(p[:url]).body).tap do |page_content|
              page_content.css("style").remove
              page_content.css("script").remove
            end.css(".s-lib-box-content").css("*").xpath("./text()").map(&:text).join(" ")
          rescue
            ""
          end.gsub(%r{\s+}, " ").gsub(%r{\s$}, "").gsub(%r{^\s}, "")
          p[:content] = (base[:content] + " " + p[:tmfield_page_content])
          pages << p
        end
      end
      @records = docs + pages
    end

    def submit
      submitter.submit(records, select, duration)
    end

    def to_json
      records.to_json
    end
  end
end
