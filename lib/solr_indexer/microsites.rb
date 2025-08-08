module SolrIndexer
  class Microsites < Base
    def fetch_records!
      response = Faraday.get(config["names"])
        return unless response.success?
      names = JSON.parse(response.body).inject({}) do |ret, user|
        ret[user.dig("name", 0, "value")] = user.dig("field_user_display_name", 0, "value")
        ret
      end
      response = Faraday.get(config["sites"])
      return unless response.success?
      sites = JSON.parse(response.body)
      sites.each do |record|
        records << {
          id: record["url"],
          url: record["url"],
          title: record["name"],
          teaser: record["description"],
          content: record["name"] + " " + record["description"],
          source: "drupal",
          ssfield_page_type: "Specialty Sites",
          status: true,
        }
      end
      sites.each do |site|
        response = Faraday.get(site["url"] + "/wp-json/wp/v2/users?per_page=100")
        next unless response.success?
        users = JSON.parse(response.body)
        ["pages", "posts"].each do |type|
          response = Faraday.get(site["url"] + "/wp-json/wp/v2/#{type}?per_page=100&status=publish")
          next unless response.success?
          containers = JSON.parse(response.body)
          containers.each do |container|
            username = users.find { |u| u["id"] == container["author"]}&.fetch("name", nil)
            display_name = names[username] || username
            record = {
              id: container["link"],
              url: container["link"],
              title: container["title"]["rendered"],
              teaser: SolrIndexer.strip_html_tags(container["excerpt"]["rendered"]),
              content: SolrIndexer.strip_html_tags(container["content"]["rendered"]),
              source: "drupal",
              ssfield_page_type: "Specialty Sites",
              status: true,
              type: type,
            }
            record[:ssfield_author] if display_name
            record[:author] = username if username
            records << record
          end
        end
      end
    end
  end
end
