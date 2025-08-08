require "json"
require "yaml"
require "net/http"
require "nokogiri"
require "time"
require "rsolr"
require "faraday"
require "htmlentities"
require "delegate"
require "erb"

module SolrIndexer
  def self.strip_html_tags(text)
    Nokogiri::HTML(text).tap do |page_content|
      page_content.css("style").remove
      page_content.css("script").remove
    end.css("*").xpath("./text()").map(&:text).join(" ")
  rescue
    text
  end
end


require_relative "solr_indexer/term"
require_relative "solr_indexer/nodes"
require_relative "solr_indexer/literal_field"
require_relative "solr_indexer/simple_field"
require_relative "solr_indexer/bundle_field"
require_relative "solr_indexer/prefixed_field"
require_relative "solr_indexer/multi_source_field"

require_relative "solr_indexer/base"
require_relative "solr_indexer/xml"
require_relative "solr_indexer/blogs"
require_relative "solr_indexer/staff"
require_relative "solr_indexer/microsites"
require_relative "solr_indexer/reporter"
require_relative "solr_indexer/submitter"

require_relative "solr_indexer/tag_array"
require_relative "solr_indexer/metadata"
require_relative "solr_indexer/lib_guides"
