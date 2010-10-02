require 'rake'
require 'rake/clean'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'rake/testtask'
require 'fileutils'
include FileUtils

NAME = "shotgun"
VERS = "0.1"
PKG = "#{NAME}-#{VERS}"
BIN = "*.{bundle,jar,so,obj,pdb,lib,def,exp}"
CLEAN.include ["lib/**/#{BIN}", '**/.*.sw?', '*.gem', '.config']
RDOC_OPTS = ['--quiet', '--title', 'Shotgun - Damn. Fast.', '--main', 'README', '--inline-source']
PKG_FILES = %w(COPYING README Rakefile)
SPEC = Gem::Specification.new do |spec|
  spec.name = NAME
  spec.version = VERS
  spec.platform = Gem::Platform::RUBY
  spec.has_rdoc = true
  spec.rdoc_options += RDOC_OPTS
  spec.extra_rdoc_files = ["README", "COPYING"]
  spec.summary = "A simple EventMachine-based asynchronous webserver."
  spec.description = spec.summary
  spec.author = "Simon Wex"
  spec.email = 'simon@simonwex.com'
  # TODO Point to online docs.
  spec.homepage = 'http://simonwex.com/shotgun'
  spec.files = PKG_FILES
  spec.files = FileList['lib/**/*.rb', 'test/**'].to_a + PKG_FILES
  spec.require_paths = ["lib"] 
  spec.bindir = "bin"
  spec.add_dependency('eventmachine', '>= 0.12.10')
  spec.add_dependency('eventmachine_httpserver', '>= 0.2.0')
  spec.add_dependency('passenger', '>= 2.2.15')
end

desc "Does a test run"
task :default => [:test]

desc "Packages up Shotgun."
task :package => [:clean]

desc "Run all the tests"
Rake::TestTask.new do |t|
    t.libs << "test" 
    t.test_files = FileList['test/*_test.rb']
    t.verbose = true
end

Rake::RDocTask.new do |rdoc|
    rdoc.rdoc_dir = 'doc/rdoc'
    rdoc.options += RDOC_OPTS
    rdoc.main = "README"
    rdoc.rdoc_files.add ['README', 'COPYING', 'lib/**/*.rb']
end

Rake::GemPackageTask.new(SPEC) do |p|
    p.need_tar = true
    p.gem_spec = SPEC
end

task "lib" do
  directory "lib"
end

task :install_local do
  sh %{rake package}
  sh %{sudo gem install --local pkg/#{NAME}-#{VERS}}
end


task :install do
  sh %{rake package}
  sh %{sudo gem install pkg/#{NAME}-#{VERS}}
end

task :uninstall => [:clean] do
  sh %{sudo gem uninstall #{NAME}}
end
