module SolrIndexer
  class Blogs
    attr_reader :records, :url, :submitter, :select

    def initialize(config, submitter)
      @select = config["select"] || "-*:*"
      @url = config["url"]
      @records = []
      @submitter = submitter
      fetch_records!
    end

    def submit
      submitter.submit(records, select)
    end

    def to_json
      @records.to_json
    end

    def to_xml
      Nokogiri::XML::Builder.new do |xml|
        xml.add do
          records.each do |record|
            xml.doc_ do
              record.each_pair do |field, value|
                xml.field(name: field) { xml.text(value) }
              end
            end
          end
        end
      end.to_xml
    end

    private

    def fetch_records!
      page = 0
      count = 100
      while count == 100
        feed = Nokogiri::XML(Net::HTTP.get(URI(url + page.to_s)))
        posts = feed.xpath("//item")
        posts.each do |post|
          title = post.xpath("title").first.content
          pub_date = post.xpath("pubDate").first.content
          zulutime = Time.parse(pub_date).strftime("%Y-%m-%dT%H:%M:%SZ")
          creator = post.xpath("dc:creator").first.content
          link = post.xpath("link").first.content
          description = post.xpath("description").first.content
          content = Nokogiri::HTML5.fragment(description).text

          records << {
            "title" => title,
            "ssfield_date" => pub_date,
            "ssfield_author" => creator,
            "id" => link,
            "url" => link,
            "status" => true,
            "promote" => true,
            "content" => content,
            "source" => "drupal-blog-post",
            "ssfield_page_type" => "Blogs and Blog Posts",
            "body" => content,
            "teaser" => content,
            "type" => "blog_post",
            "created" => zulutime,
            "changed" => zulutime
          }
        end
        count = posts.count
        page += 1
      end
    end
  end
end
