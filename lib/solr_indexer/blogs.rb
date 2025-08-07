module SolrIndexer
  class Blogs < Base
    attr_reader :url, :blog_urls

    def initialize(config, submitter)
      @url = config["url"]
      @blog_urls = []
      super
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

    def fetch_records!
      # fetch_blog_posts! has to run before fetch_blogs! to populate blog_urls
      fetch_blog_posts!
      fetch_blogs!
      fetch_blogs_gateway!
    end

    def fetch_blog_posts!
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
          blog_url = File.dirname(link)
          blog_urls << blog_url unless blog_urls.include?(blog_url)

          records << {
            title: title,
            ssfield_date: pub_date,
            ssfield_author: creator,
            id: link,
            url: link,
            status: true,
            promote: true,
            content: content,
            source: "blogs",
            ssfield_page_type: "Blogs and Blog Posts",
            body: content,
            teaser: content,
            type: "blog_post",
            type_name: "Blog Post",
            created: zulutime,
            changed: zulutime
          }
        end
        count = posts.count
        page += 1
      end
    end



    def fetch_blogs_gateway!
      blogs_url = File.dirname(url)
      response = Faraday.get(blogs_url)
      doc = Nokogiri::HTML5(response.body)
      title = doc.xpath("//meta[@property='og:site_name']").first.attr("content").to_s
      content = doc.xpath("//meta[@property='og:description']").first.attr("content").to_s
      records << {
        title: title,
        id: blogs_url,
        url: blogs_url,
        status: true,
        promote: true,
        content: content,
        body: content,
        teaser: content,
        important: true,
        source: "blogs",
        ssfield_page_type: "Blogs and Blog Posts",
        type: "blog_gateway",
        type_name: "Blog Gateway",
      }
    end

    def fetch_blogs!
      blog_urls.each do |blog_url|
        response = Faraday.get(blog_url)
        doc = Nokogiri::HTML5(response.body)
        title = doc.xpath("//meta[@property='og:title']").first.attr("content").to_s
        content = doc.xpath("//meta[@property='og:description']").first.attr("content").to_s

        records << {
          title: title,
          id: blog_url,
          url: blog_url,
          status: true,
          promote: true,
          body: content,
          teaser: content,
          content: content,
          type: "blog",
          type_name: "Blog",
          source: "blogs",
          important: true,
          ssfield_page_type: "Blogs and Blog Posts",
        }
      end
    end
  end
end
