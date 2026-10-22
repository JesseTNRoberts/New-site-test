#!/usr/bin/env ruby
# frozen_string_literal: true

# Refreshes _data/stats.yml with live numbers for the homepage trackers.
#
#   publications  papers dated in the tracker year on Google Scholar
#                 (falls back to OpenAlex via ORCID if Scholar blocks the request).
#                 A successful Scholar fetch also rewrites _data/publications.yml,
#                 the list shown on the Publications page.
#   strava        miles of matching activities (Run, TrailRun, ...) in the tracker year
#
# Each source is independent: if one fails, its previous values in stats.yml are kept
# and marked stale, so the site never shows a zero because an API hiccuped.
#
# Configuration
#   _data/goals.yml   year, and sport_types for the strava tracker
#   _config.yml       author.googlescholar (profile URL) and author.orcid
#   env               STRAVA_CLIENT_ID, STRAVA_CLIENT_SECRET, STRAVA_REFRESH_TOKEN
#                     (Strava is skipped if these aren't set; see scripts/strava_auth.rb)
#
# Usage: ruby scripts/update_stats.rb   (run from the repo root)
# Only the Ruby standard library is used, so no gems are needed.

require "yaml"
require "json"
require "net/http"
require "uri"
require "time"
require "date"

ROOT = File.expand_path("..", __dir__)
STATS_PATH = File.join(ROOT, "_data", "stats.yml")
PUBS_PATH = File.join(ROOT, "_data", "publications.yml")
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) " \
     "Chrome/128.0 Safari/537.36"
METERS_PER_MILE = 1609.344
TZ_OFFSET = "-06:00" # Central time; only matters for activities near midnight on Jan 1

class FetchError < StandardError; end

def log(msg)
  warn("[stats] #{msg}")
  # In GitHub Actions, also surface each message as an annotation on the run's summary page.
  puts "::notice title=stats::#{msg.gsub("\n", " ")}" if ENV["GITHUB_ACTIONS"]
end

def http_get(url, headers = {})
  uri = URI(url)
  req = Net::HTTP::Get.new(uri)
  req["User-Agent"] = UA
  headers.each { |k, v| req[k] = v }
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                        open_timeout: 15, read_timeout: 30) { |h| h.request(req) }
  raise FetchError, "GET #{uri.host}#{uri.path} -> HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)

  res.body.force_encoding("UTF-8")
end

def http_post_form(url, form)
  res = Net::HTTP.post_form(URI(url), form)
  raise FetchError, "POST #{url} -> HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)

  JSON.parse(res.body)
end

# ---------------------------------------------------------------- publications

def scholar_user_id(config)
  url = config.dig("author", "googlescholar").to_s
  url[/[?&]user=([\w-]+)/, 1]
end

def strip_tags(s)
  s.to_s.gsub(/<[^>]+>/, "").gsub("&amp;", "&").gsub("&#39;", "'").gsub("&quot;", '"')
   .gsub("&lt;", "<").gsub("&gt;", ">").gsub("&nbsp;", " ").gsub("&hellip;", "…").squeeze(" ").strip
end

# Parses one Scholar profile page into { papers: [...], citations: Integer|nil }.
#
# A paper row looks like:
#   <tr class="gsc_a_tr">
#     <td class="gsc_a_t"><a href="/citations?view_op=view_citation&..." class="gsc_a_at">Title</a>
#       <div class="gs_gray">J Roberts, D Fisher</div>
#       <div class="gs_gray">Proceedings of AAAI 38 (17), 1-9<span class="gs_oph">, 2024</span></div></td>
#     <td class="gsc_a_c"><a href="..." class="gsc_a_ac gs_ibl">12</a></td>
#     <td class="gsc_a_y"><span class="gsc_a_h gsc_a_hc gs_ibl">2024</span></td>
#   </tr>
def parse_scholar(html)
  if html.include?("gs_captcha") || html =~ /unusual traffic|not a robot/i
    raise FetchError, "Google Scholar returned a CAPTCHA"
  end

  rows = html.scan(%r{<tr class="gsc_a_tr[^"]*".*?</tr>}m)
  raise FetchError, "couldn't find any publications on the Scholar page (layout changed?)" if rows.empty?

  papers = rows.map do |r|
    link = r[%r{<a[^>]*href="([^"]+)"[^>]*class="gsc_a_at"}, 1] || r[%r{<a[^>]*class="gsc_a_at"[^>]*href="([^"]+)"}, 1]
    gray = r.scan(%r{<div class="gs_gray">(.*?)</div>}m).flatten
    {
      "title" => strip_tags(r[%r{class="gsc_a_at"[^>]*>(.*?)</a>}m, 1]),
      "authors" => strip_tags(gray[0]),
      # drop the ", 2024" Scholar appends to the venue line
      "venue" => strip_tags(gray[1].to_s.sub(%r{<span class="gs_oph">.*?</span>}m, "")),
      "year" => r[%r{class="gsc_a_y[^"]*".*?>\s*((?:19|20)\d\d)\s*<}m, 1]&.to_i,
      "cited_by" => r[%r{class="gsc_a_ac[^"]*"[^>]*>\s*(\d+)\s*<}, 1].to_i,
      "url" => link && "https://scholar.google.com#{link.gsub('&amp;', '&')}"
    }
  end
  # First cell of the "Cited by" table is all-time citations.
  citations = html[%r{class="gsc_rsb_std[^"]*"[^>]*>\s*(\d+)\s*<}, 1]&.to_i

  { papers: papers, citations: citations }
end

def fetch_scholar(user_id, year)
  raise FetchError, "no Google Scholar profile URL in _config.yml" unless user_id

  papers = []
  citations = nil
  # Scholar shows up to 100 papers per page; loop in case the profile grows past that.
  (0..900).step(100) do |start|
    url = "https://scholar.google.com/citations?user=#{user_id}&hl=en&cstart=#{start}&pagesize=100&sortby=pubdate"
    page = parse_scholar(http_get(url, "Accept-Language" => "en-US,en;q=0.9"))
    papers.concat(page[:papers])
    citations ||= page[:citations]
    break if page[:papers].size < 100

    sleep 2
  end
  write_publications(papers, user_id)
  { "papers_this_year" => papers.count { |p| p["year"] == year }, "papers_total" => papers.size,
    "citations" => citations, "source" => "Google Scholar" }
end

# Full publication list for the Publications page (_includes/scholar-publications.html).
# Only written after a successful Scholar fetch, so a blocked request never wipes the list.
def write_publications(papers, user_id)
  sorted = papers.sort_by { |p| [-(p["year"] || 0), p["title"].downcase] }
  data = { "profile" => "https://scholar.google.com/citations?user=#{user_id}",
           "updated" => Time.now.utc.iso8601, "papers" => sorted }
  header = "# Generated from Google Scholar by scripts/update_stats.rb (daily via GitHub Actions).\n" \
           "# Don't edit by hand. To fix a paper, edit it on your Scholar profile.\n"
  File.write(PUBS_PATH, header + data.to_yaml.sub(/\A---\n/, ""))
  log "wrote #{papers.size} papers to #{PUBS_PATH}"
end

def fetch_openalex(orcid, year)
  id = orcid.to_s[/\d{4}-\d{4}-\d{4}-\d{3}[\dX]/]
  raise FetchError, "no ORCID in _config.yml" unless id

  base = "https://api.openalex.org/works?per-page=1&filter=author.orcid:#{id}"
  this_year = JSON.parse(http_get("#{base},publication_year:#{year}"))
  total = JSON.parse(http_get(base))
  { "papers_this_year" => this_year.dig("meta", "count"), "papers_total" => total.dig("meta", "count"),
    "citations" => nil, "source" => "OpenAlex (ORCID)" }
end

def fetch_publications(config, year)
  fetch_scholar(scholar_user_id(config), year)
rescue FetchError, StandardError => e
  log "Scholar failed (#{e.message}); trying OpenAlex"
  fetch_openalex(config.dig("author", "orcid"), year)
end

# ---------------------------------------------------------------------- strava

def strava_access_token
  id, secret, refresh = ENV.values_at("STRAVA_CLIENT_ID", "STRAVA_CLIENT_SECRET", "STRAVA_REFRESH_TOKEN")
  raise FetchError, "Strava secrets not set (skipping)" if [id, secret, refresh].any? { |v| v.to_s.empty? }

  tok = http_post_form("https://www.strava.com/oauth/token",
                       "client_id" => id, "client_secret" => secret,
                       "grant_type" => "refresh_token", "refresh_token" => refresh)
  if tok["refresh_token"] && tok["refresh_token"] != refresh
    log "Strava issued a new refresh token; update the STRAVA_REFRESH_TOKEN secret if Strava starts failing"
  end
  tok.fetch("access_token")
end

def fetch_strava(year, sport_types)
  token = strava_access_token
  after = Time.new(year, 1, 1, 0, 0, 0, TZ_OFFSET).to_i
  before = Time.new(year + 1, 1, 1, 0, 0, 0, TZ_OFFSET).to_i
  meters = 0.0
  count = 0
  (1..50).each do |page|
    url = "https://www.strava.com/api/v3/athlete/activities?after=#{after}&before=#{before}&per_page=200&page=#{page}"
    acts = JSON.parse(http_get(url, "Authorization" => "Bearer #{token}"))
    acts.each do |a|
      next unless sport_types.include?(a["sport_type"] || a["type"])

      meters += a["distance"].to_f
      count += 1
    end
    break if acts.size < 200
  end
  { "miles_this_year" => (meters / METERS_PER_MILE).round(1), "activities" => count,
    "sport_types" => sport_types }
end

# ------------------------------------------------------------------------ main

def main
  config = YAML.safe_load_file(File.join(ROOT, "_config.yml"), aliases: true)
  goals = YAML.safe_load_file(File.join(ROOT, "_data", "goals.yml"), permitted_classes: [Date])
  year = (goals["year"] || Date.today.year).to_i
  sport_types = goals.fetch("trackers", []).find { |t| t["source"] == "strava" }&.dig("sport_types") || %w[Run TrailRun]

  old = File.exist?(STATS_PATH) ? (YAML.safe_load_file(STATS_PATH, permitted_classes: [Time, Date]) || {}) : {}
  old = {} unless old["year"].to_i == year # new year: don't carry last year's totals forward
  now = Time.now.utc.iso8601
  stats = { "year" => year }
  changed = false

  { "publications" => -> { fetch_publications(config, year) },
    "strava" => -> { fetch_strava(year, sport_types) } }.each do |key, fetcher|
    fresh = fetcher.call
    log "#{key}: #{fresh.inspect}"
    stats[key] = fresh.merge("updated" => now)
    changed = true
  rescue StandardError => e
    log "#{key} not updated: #{e.message}"
    stats[key] = old[key] if old[key] # keep the last good numbers
  end

  unless changed
    log "nothing fetched; leaving #{STATS_PATH} untouched"
    return
  end

  header = "# Generated by scripts/update_stats.rb (daily via GitHub Actions). Don't edit by hand;\n" \
           "# targets and manual numbers live in _data/goals.yml.\n"
  File.write(STATS_PATH, header + stats.to_yaml.sub(/\A---\n/, ""))
  log "wrote #{STATS_PATH}"
end

main if $PROGRAM_NAME == __FILE__
