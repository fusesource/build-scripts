Build Scripts
=============

This project contains a bunch of handy shell scripts for building, working with maven, git, doing releases and so forth.

Commands
--------

### Git

* gitcip does a git commit with a message then pushes the change
* gitci as above without the push

### Building

* mvnci does a "mvn clean install" build
* mvnnt as above without running any unit tests

### Releasing

* releaseprepare does a "mvn release:prepare" setting the release-altGitURL property to the local git file system 
* releaseperform does a "mvn release:perform" setting the release-altGitURL property to the local git file system 


# Scala

* fscc starts a fsc process; handy for use in IDEA with FSC mode enabled



Configurations
--------------

There is a sample ~/.m2/settings.xml in the etc directory.
