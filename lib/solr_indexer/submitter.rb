module SolrIndexer
  class Submitter
    def initialize(config)
      @solrs = config["solrs"].map { |solr| RSolr.connect(url: solr) }
    end

    def submit(documents, select, duration)
      timestamp = (Time.now - 300).utc.iso8601
      reports = []
      @solrs.each do |solr|
        status_report = {
          url: solr.uri.to_s,
          before: 0,
          updated: documents.length,
          deleted: 0,
          error: nil,
          completed_at:  Time.now.to_i,
          source: select,
          duration: duration
        }
        status_report[:before] =
          before =
            solr.get(
              "select",
              params: {q: select, rows: 0}
            )["response"]["numFound"].to_i

        status = solr.add(documents)["responseHeader"]["status"].to_i

        if status != 0
          status_report[:error] = "Add status: #{status}"
          reports << status_report
          next
        end

        solr.commit
        if before < 1
          reports << status_report
          next
        end
        status_report[:deleted] =
          deleting =
            solr.get(
              "select",
              params: {q: "#{select} +timestamp:[* TO #{timestamp}]", rows: 0}
            )["response"]["numFound"].to_i

        if deleting > 0.2 * before
          status_report[:error] = "Deleting: Trying to delete #{deleting} documents older than 5 minutes, which is more than 20% of the total documents found before submission (#{before}). This is too large to delete automatically."
          reports << status_report
          next
        end
        solr.delete_by_query("#{select} +timestamp:[* TO #{timestamp}]")
        solr.commit
        reports << status_report
      rescue => e
        status_report[:error] = "An error occurred: #{e.message}"
        reports << status_report
      end
      reports.each do |report|
        Reporter.new(report).report
      end
      reports
    end
  end
end
