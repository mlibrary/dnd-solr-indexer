module SolrIndexer
  class TagArray < SimpleDelegator
    def clean
      tmp = []
      each do |tag|
        tmp << tag
        tmp << clean_tag(tag)
        tmp << clean_cg(tag)
      end
      tmp.compact.select { |item| !item.empty? }.uniq
    end

    private

    def clean_tag tag
      tag.downcase.gsub(%r{[/ ]}, "_")
    end

    def clean_cg tag
      tag.scan(/(subject|course|section|instructor|term|year):([^ ]*)/).sort do |a, b|
        vals = {
          "subject" => 1,
          "course" => 2,
          "section" => 3,
          "instructor" => 4,
          "term" => 5,
          "year" => 6
        }
        vals[a[0]] <=> vals[b[0]]
      end.map do |match|
        match.join(":")
      end.join(" ")
    end
  end
end
