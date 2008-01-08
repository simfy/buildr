require "pathname"
require "core/project"
require "java/artifact"


module Buildr
  module Eclipse #:nodoc:

    include Extension
    
    first_time do
      # Global task "eclipse" generates artifacts for all projects.
      desc "Generate Eclipse artifacts for all projects"
      Project.local_task "eclipse"=>"artifacts"
    end

    before_define do |project|
      project.recursive_task("eclipse")
    end

    after_define do |project|
      eclipse = project.task("eclipse")
      # We need paths relative to the top project's base directory.
      root_path = lambda { |p| f = lambda { |p| p.parent ? f[p.parent] : p.base_dir } ; f[p] }[project]

      # We want the Eclipse files changed every time the Buildfile changes, but also anything loaded by
      # the Buildfile (buildr.rb, separate file listing dependencies, etc), so we add anything required
      # after the Buildfile. So which don't know where Buildr shows up exactly, ignore files that show
      # in $LOADED_FEATURES that we cannot resolve.
      sources = Buildr.build_files.map { |file| File.expand_path(file) }.select { |file| File.exist?(file) }
      sources << File.expand_path(Rake.application.rakefile, root_path) if Rake.application.rakefile

      # Check if project has scala facet
      scala = project.task("scalac") if Rake::Task.task_defined?(project.name+":"+"scalac")
      
      # Only for projects that are Eclipse packagable.
      if project.packages.detect { |pkg| pkg.type.to_s =~ /(jar)|(war)|(rar)|(mar)|(aar)/ }
        eclipse.enhance [ file(project.path_to(".classpath")), file(project.path_to(".project")) ]

        # The only thing we need to look for is a change in the Buildfile.
        file(project.path_to(".classpath")=>sources) do |task|
          puts "Writing #{task.name}" if verbose

          # Find a path relative to the project's root directory.
          relative = lambda do |path|
            msg = [:to_path, :to_str, :to_s].find { |msg| path.respond_to? msg }
            path = path.__send__(msg)
            Pathname.new(File.expand_path(path)).relative_path_from(Pathname.new(project.path_to)).to_s
          end

          m2repo = Buildr::Repositories.instance.local
          excludes = [ '**/.svn/', '**/CVS/' ].join('|')

          File.open(task.name, "w") do |file|
            xml = Builder::XmlMarkup.new(:target=>file, :indent=>2)
            xml.classpath do
              # Note: Use the test classpath since Eclipse compiles both "main" and "test" classes using the same classpath
              cp = project.test.compile.classpath.map(&:to_s) - [ project.compile.target.to_s ]
              cp += scala.classpath.map(&:to_s) if scala
              cp = cp.uniq

              # Convert classpath elements into applicable Project objects
              cp.collect! { |path| projects.detect { |prj| prj.packages.detect { |pkg| pkg.to_s == path } } || path }

              # project_libs: artifacts created by other projects
              project_libs, others = cp.partition { |path| path.is_a?(Project) }

              # Separate artifacts from Maven2 repository
              m2_libs, others = others.partition { |path| path.to_s.index(m2repo) == 0 }

              # Generated: classpath elements in the project are assumed to be generated
              generated, libs = others.partition { |path| path.to_s.index(project.path_to.to_s) == 0 }

              xml.classpathentry :kind=>'con', :path=>'org.eclipse.jdt.launching.JRE_CONTAINER'
              xml.classpathentry :kind=>'con', :path=>'ch.epfl.lamp.sdt.launching.SCALA_CONTAINER' if scala

              srcs = project.compile.sources
              srcs << scala.sources if scala
              
              # hack until we have sunit task
              project.path_to("src/test/scala").tap do |dir|
                srcs += dir if scala and File.exist?(dir)
              end
              
              srcs = srcs.map { |src| relative[src] } + generated.map { |src| relative[src] }
              srcs.sort.uniq.each do |path|
                xml.classpathentry :kind=>'src', :path=>path, :excluding=>excludes
              end

              { :output => relative[project.compile.target],
                :lib    => libs.map(&:to_s),
                :var    => m2_libs.map { |path| path.to_s.sub(m2repo, 'M2_REPO') }
              }.each do |kind, paths|
                paths.sort.uniq.each do |path|
                  xml.classpathentry :kind=>kind, :path=>path
                end
              end

              # Classpath elements from other projects
              project_libs.map(&:id).sort.uniq.each do |project_id|
                xml.classpathentry :kind=>'src', :combineaccessrules=>"false", :path=>"/#{project_id}"
              end

              # Main resources implicitly copied into project.compile.target
              project.resources.sources.each do |path|
                if File.exist? project.path_to(path)
                  xml.classpathentry :kind=>'src', :path=>path, :excluding=>excludes
                end
              end

              # Test classes are generated in a separate output directory
              test_sources = project.test.compile.sources.map { |src| relative[src] }
              test_sources.each do |paths|
                paths.sort.uniq.each do |path|
                  xml.classpathentry :kind=>'src', :path=>path, :output => relative[project.test.compile.target], :excluding=>excludes
                end
              end

              # Test resources go in separate output directory as well
              project.test.resources.sources.each do |path|
                if File.exist? project.path_to(path)
                  xml.classpathentry :kind=>'src', :path=>path, :output => relative[project.test.compile.target], :excluding=>excludes
                end
              end
            end
          end
        end

        # The only thing we need to look for is a change in the Buildfile.
        file(project.path_to(".project")=>sources) do |task|
          puts "Writing #{task.name}" if verbose
          File.open(task.name, "w") do |file|
            xml = Builder::XmlMarkup.new(:target=>file, :indent=>2)
            xml.projectDescription do
              xml.name project.id
              xml.projects
              xml.buildSpec do
                xml.buildCommand do
                  xml.name "org.eclipse.jdt.core.javabuilder"
                end
                if scala
                  xml.buildCommand do
                    #xml.name "ch.epfl.lamp.sdt.core.scalabuilder"
                    xml.name "scala.plugin.scalabuilder"
                  end
                end
              end
              xml.natures do
                xml.nature "org.eclipse.jdt.core.javanature"
                #xml.nature "ch.epfl.lamp.sdt.core.scalanature" if scala
                xml.nature "scala.plugin.scalanature" if scala
              end
            end
          end
        end
      end

    end

  end
end # module Buildr


class Buildr::Project
  include Buildr::Eclipse
end