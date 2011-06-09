#!/usr/bin/ruby

require 'tempfile'

USAGE = "usage: svnmerge-ignore.rb REVISION
         
Ignore a revision using svnmerge.
        
Unlike svnmerge block, this command will first merge the revision
and then undo all changes made to file, only keeping directory 
property changes.
        
The REVISION argument will be passed to svnmerge merge -r REVISION
for doing the initial merge."

def usage
  puts USAGE
  Process.exit -1
end

def svnmerge(revision)
  command = "svnmerge merge -r #{revision}"
  puts "Running #{command}"
  system(command)
end

def ignore
  puts "Reverting changes"
  temp_file = Tempfile.new('svnmerge_ignore')
  system("svn status > #{temp_file.path}")

  IO.foreach(temp_file.path) do |line|
    next if line.index('?') == 0
    change = line[5..-1].chomp.strip
  
    # only revert file changes, keep directory property changes around
    system("svn revert #{change}") unless File.directory?(change)
  end
end

def update_commit_message(revision)
  puts "Updating commit message"
  url = File.readlines("svnmerge-commit-message.txt")[1]
  File.open("svnmerge-commit-message.txt", "w+") { |io|
    io.puts("Ignored revision #{revision} with svnmerge-ignore.rb from")
    io.puts(url)
  }
end

usage() unless (ARGV.size == 1)

svnmerge(ARGV[0])
ignore
update_commit_message(ARGV[0])

