#!/usr/bin/ruby
#= Overview
# release-notes.rb generates release notes in Confluence wiki markup, aggregating information found in:
# - the release notes in the FUSE JIRA 
# - the subversion commit logs since the last release
#
#= Usage
#
#  Usage:  release-notes.rb <release_version> --since <previous_version>
#
#  The release-notes.cfg file in this directory should contain the FUSE JIRA project key
#  e.g. project: ESB
#
#= Example
#
#  Example: release-notes.rb 4.2.0-fuse-02-00 --since 4.2.0-fuse-01-00


require 'net/http'
require 'rdoc/usage'
require 'rubygems'
require 'httpclient'
require 'jira4r'
require 'rexml/document'
require 'rss/0.9'
require 'tempfile'
require 'uri'
require 'yaml'

include REXML

ISSUE_NUMBER=/[A-Z][A-Z0-9]{1,10}-[0-9]{1,4}/

LOG = Logger.new(STDOUT)
LOG.level = Logger::WARN

class Subversion
  
  def self.readLog(startrev, endrev = "HEAD") 
    temp_file = Tempfile.new('release_notes')
    system("svn log -r #{startrev}:#{endrev} > #{temp_file.path}")
    
    commit = Array.new
    IO.foreach(temp_file.path) { |line|
      if (line =~ /^-+$/) then
        yield commit unless commit.empty?
        commit = Array.new
      else
        commit << line
      end
    }
    
    yield commit unless commit.empty?
  end
  
end

class Svnmerge

  def self.isBlocked?(commit)
    commit.select{ |line| line =~ /Blocked revisions .* via svnmerge/}.length > 0
  end

end

class Issue

  attr_accessor :issue, :category, :description, :links, :url
  def initialize(url)
    @url = url
    @issue = id(url)
    @links = [url]
  end

  def to_wiki  
    links = @links.map { |url| "[#{id(url)}|#{url}]" }.join("/")
    "#{links} - #{@description}"
  end

  def id(url)
    url.scan(ISSUE_NUMBER)[0]
  end

  def <=>(other)
    return (@issue <=> other.issue)
  end
  
  def to_s
    "[#{@issue}] #{@description}"
  end

end

class FuseJira
  
  def initialize
    @jira = Jira4R::JiraTool.new(2, "http://fusesource.com/issues")
    @jira.logger = LOG
    @jira.login("cruise", "cruise01")
  end

  def project(key)
    selected_project = @jira.getProjectByKey(key)
    abort("Project #{key} not found in FUSE JIRA") unless selected_project
    selected_project
  end

  def version(project, name)
    selected_versions = @jira.getVersions(project).select{ |version| version.name.strip == name }
    abort("Version #{name} not found in FUSE JIRA") if selected_versions.empty?
    selected_versions.first
  end

end

class ReleaseNotes

  def initialize(project, version)
    @jira = FuseJira.new

    @project = project
    @version = version
    @apache = Hash.new
    @fuse = Hash.new
  end
  
  def apacheRssUrl(id)
    if (id =~ /CXF/ or id =~ /FELIX/) then
      "https://issues.apache.org/jira/si/jira.issueviews:issue-xml/#{id}/#{id}.xml"
    else
      "https://issues.apache.org/activemq/si/jira.issueviews:issue-xml/#{id}/#{id}.xml"
    end
  end

  def fuseRssUrl
    puts "==> Fetching project and version id from FUSE JIRA"

    project = @jira.project(@project).id
    version = @jira.version(@project, @version).id
    
    puts("...Project FUSE #{@project} -> #{project}")
    puts("...Version #{@version} -> #{version}")

    "http://fusesource.com/issues/sr/jira.issueviews:searchrequest-xml/temp/SearchRequest.xml?pid=#{project}&resolution=1&resolution=6&fixfor=#{version}&sorter/field=issuekey&sorter/order=DESC&tempMax=1000"
  end

  def addFuseIssues()
    url = fuseRssUrl()
    puts "==> Scanning the FUSE JIRA"
    readRssFeed(url) do |issue, item|
      link = XPath.first(item, "customfields/customfield[@id='customfield_10003']/customfieldvalues/customfieldvalue/text()").to_s
      issue.links << link if !link.empty?    
      puts "...#{issue}"
      @fuse[issue]=link.scan(ISSUE_NUMBER)[0]
    end
    puts "...found #{@fuse.size} issues in the FUSE JIRA"
  end


  def addFromSvnLog(previous)
    date = @jira.version(@project, previous).releaseDate.strftime("%Y-%m-%d")
    puts "==> Scanning the subversion commit log since #{previous} release on #{date}"
    Subversion.readLog("{#{date}}") { |commit|
      next if Svnmerge.isBlocked?(commit)
      commit.each { |line|
        line.scan(ISSUE_NUMBER).uniq.each { |id|
          next if @fuse.value?(id) or @apache.value?(id)
          readRssFeed(apacheRssUrl(id)) { |issue,item|
            puts "...#{issue}"
            @apache[issue] = id if issue
          }
        }
      }
    }

    puts "...found #{@apache.size} additional issues from the commit log"
  end

  def to_wiki(filename)
    puts "==> Generating release notes"
    issues = (@fuse.keys + @apache.keys).sort
    categories = issues.map { |issue| issue.category }.uniq.sort
    File.open(filename, 'w') { |file|
      file.puts "h2. What's new in FUSE #{@project} #{@version}, #{DateTime.now.strftime('%B %d, %Y')}" 
      categories.each { |category|
        file.puts "h3. #{category}"
        issues.select { |issue| issue.category == category }.each { |issue|
          file.puts "* #{issue.to_wiki}"
        }
        file.puts
      }
    }
    puts "...release notes written to #{filename}"
  end

  def readRssFeed(url)
    client = HTTPClient.new
    begin
      doc = Document.new(client.get_content(url))

      XPath.each(doc, "//item") do |item|  
        issue = Issue.new(XPath.first(item, "link/text()").to_s)
        issue.category = XPath.first(item, "type/text()").to_s
        issue.description = XPath.first(item, "title/text()").to_s.gsub(/\[\(?[A-Z0-9]{2,7}-[0-9]{1,4}\)?\]/, "").strip
        yield issue, item
      end	
    rescue Exception => e
      puts "Error getting #{url}: #{e.message}"
      yield nil, nil
    end
  end

end

RDoc::usage unless ARGV.length == 3 and ARGV[1] == "--since" and File.exist?("release-notes.cfg")

config = YAML::load(File.open('release-notes.cfg'))

relnotes = ReleaseNotes.new(config['project'], ARGV[0])
relnotes.addFuseIssues
relnotes.addFromSvnLog(ARGV[2])

relnotes.to_wiki("release-notes.wiki")
