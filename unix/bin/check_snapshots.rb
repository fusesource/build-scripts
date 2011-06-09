#!/usr/bin/ruby

require 'rexml/document'
require 'tempfile'

pom = REXML::Document.new(File.new("pom.xml"))
version = pom.root.elements["version"].text

puts "POM version: #{version}"

puts "- Grep'ing all the pom.xml files"
count = 0
Dir.glob('**/pom.xml').each { |file| 
  IO.foreach(file) { |line| 
    filtered = line.gsub(Regexp.new("#{version}"), "")
    filtered.grep(/SNAPSHOT/).each { |match| 
      puts "  WARNING: Found #{match.chop} in #{file}"
      count = count + 1
    }
  } 
}
puts "  OK: No SNAPSHOTs found" unless count > 0


puts "- Running a mvn dependency:tree"
count = 0
temp_file = Tempfile.new('check_snapshots')
system("mvn dependency:tree > #{temp_file.path}")
IO.foreach(temp_file.path) { |line|
    filtered = line.gsub(Regexp.new("#{version}"), "")

    filtered.grep(/SNAPSHOT/).each { |match|
      puts "  WARNING: Found #{match.chop} in dependency tree"
      count = count + 1
    }  
}
puts "  OK: No SNAPSHOTs found" unless count > 0
