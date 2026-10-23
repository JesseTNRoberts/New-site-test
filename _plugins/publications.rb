# frozen_string_literal: true

# Annotates the Google Scholar mirror (_data/publications.yml) at build time:
#   - each paper gets `tier`, `label` and `note` from _data/venues.yml and
#     _data/publication_overrides.yml, plus a stable `key` and a numeric `sort_year`;
#   - hidden papers are dropped.
# Keeping this at build time means editing the rules never needs a new Scholar fetch.
module JesseSite
  class PublicationTiers < Jekyll::Generator
    safe true
    priority :high

    def generate(site)
      pubs = site.data["publications"]
      return unless pubs.is_a?(Hash) && pubs["papers"].is_a?(Array)

      venues = site.data["venues"] || {}
      rules = venues["rules"] || []
      overrides = site.data["publication_overrides"] || []

      papers = pubs["papers"].map do |paper|
        p = paper.dup
        venue = p["venue"].to_s
        rule = rules.find { |r| r["match"] && venue.downcase.include?(r["match"].to_s.downcase) }
        p["tier"] = if rule then rule["tier"].to_i
                    elsif venue.strip.empty? then (venues["empty_venue_tier"] || 3).to_i
                    else (venues["default_tier"] || 2).to_i
                    end
        p["label"] = rule && rule["label"]

        overrides.each do |o|
          next unless o["title"] && p["title"].to_s.downcase.include?(o["title"].to_s.downcase)

          p["tier"] = o["tier"].to_i if o.key?("tier")
          p["label"] = o["label"] if o.key?("label")
          p["note"] = o["note"] if o.key?("note")
          p["hide"] = o["hide"] if o.key?("hide")
        end

        p["sort_year"] = p["year"].to_i
        p["cited_by"] = p["cited_by"].to_i
        p["key"] = p["title"].to_s.downcase.gsub(/[^a-z0-9]+/, "-")[0, 60]
        p
      end

      papers.reject! { |p| p["hide"] }
      pubs["papers"] = papers
      Jekyll.logger.info "Publications:", "#{papers.size} papers"
    end
  end
end
