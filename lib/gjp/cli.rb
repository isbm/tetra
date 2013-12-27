# encoding: UTF-8
require "gjp/logger"
require "clamp"
require "open-uri"

module Gjp
  class MainCommand < Clamp::Command
    include Logger

    # Common logging options
    option ["-v", "--verbose"], :flag, "verbose output"
    option ["--very-verbose"], :flag, "very verbose output"
    option ["--very-very-verbose"], :flag, "very very verbose output"

    def very_very_verbose=(flag)
      configure_log_level(verbose?, very_verbose?, flag)
    end
    
    def very_verbose=(flag)
      configure_log_level(verbose?, flag, very_very_verbose?)
    end
    
    def verbose=(flag)
      configure_log_level(flag, very_verbose?, very_very_verbose?)
    end

    def configure_log_level(v, vv, vvv)
      if vvv
        log.level = ::Logger::DEBUG
      elsif vv
        log.level = ::Logger::INFO
      elsif v
        log.level = ::Logger::WARN
      else
        log.level = ::Logger::ERROR
      end
    end

    # Subcommands
    subcommand "init", "Inits a gjp project in the current directory" do
      def execute
        checking_exceptions do
          Gjp::Project.init(".")
          puts "Project inited."
          puts "Add sources to src/<package name>, binary dependencies to kit/."
          puts "When you are ready to test a build, use \"gjp dry-run\"."
        end
      end
    end

    subcommand "dry-run", "Starts a dry-run build" do
      def execute
        checking_exceptions do
          if Gjp::Project.new(".").dry_run
            puts "Now dry-running, please start your build."
            puts "To run a Maven installation from the kit, use \"gjp mvn\"."
            puts "If the build succeedes end this dry run with \"gjp finish\"."
            puts "If the build does not succeed use \"gjp finish --abort\" to restore files."
          end
        end
      end
    end

    subcommand "mvn", "Locates and runs Maven from any directory in kit/" do
      parameter "[MAVEN OPTIONS] ...", "mvn options", :attribute_name => "dummy"

      # override parsing in order to pipe everything to mvn
      def parse(args)
        @options = args
      end

      def execute
        checking_exceptions do
          project = Gjp::Project.new(".")
          ensure_dry_running(true, project) do
            Gjp::MavenRunner.new(project).mvn(@options)
          end
        end
      end
    end

    subcommand "ant", "Locates and runs Ant from any directory in kit/" do
      parameter "[ANT OPTIONS] ...", "ant options", :attribute_name => "dummy"

      # override parsing in order to pipe everything to mvn
      def parse(args)
        @options = args
      end

      def execute
        checking_exceptions do
          project = Gjp::Project.new(".")
          ensure_dry_running(true, project) do
            Gjp::AntRunner.new(project).ant(@options)
          end
        end
      end
    end

    subcommand "finish", "Ends the current dry-run" do
      option ["-f", "--abort"], :flag, "build abort, restore files as before dry-run"
      def execute
        checking_exceptions do
          if Gjp::Project.new(".").finish(abort?)
            if abort?
              puts "Project reverted as before dry-run."
            else
              puts "Dry-run finished."
            end
          else
            puts "No dry-run is in progress."
          end
        end
      end
    end

    subcommand "generate-kit-archive", "Create or refresh the kit tarball" do
      option ["-f", "--full"], :flag, "create a full archive (not incremental)"
      def execute
        checking_exceptions do
          project = Gjp::Project.new(".")
          ensure_dry_running(false, project) do
            result_path = Gjp::Archiver.new(project).archive_kit(full?)
            print_generation_result(project, result_path)
          end
        end
      end
    end

    subcommand "generate-kit-spec", "Create or refresh a spec file for the kit" do
      def execute
        checking_exceptions do
          project = Gjp::Project.new(".")
          ensure_dry_running(false, project) do
            result_path, conflict_count = Gjp::SpecGenerator.new(project).generate_kit_spec
            print_generation_result(project, result_path, conflict_count)
          end
        end
      end
    end

    subcommand "generate-package-script", "Create or refresh a build.sh file for a package" do
      parameter "[DIRECTORY]", "path to a package directory (src/<package name>)", :default => "."
      def execute
        checking_exceptions do
          project = Gjp::Project.new(".")
          ensure_dry_running(false, project) do
            package_name = project.get_package_name(directory)
            history_file = File.join(Dir.home, ".bash_history")
            result_path, conflict_count = Gjp::ScriptGenerator.new(project, history_file).generate_build_script(package_name)
            print_generation_result(project, result_path, conflict_count)
          end
        end
      end
    end

    subcommand "generate-package-archive", "Create or refresh a package tarball" do
      parameter "[DIRECTORY]", "path to a package directory (src/<package name>)", :default => "."
      def execute
        checking_exceptions do
          project = Gjp::Project.new(".")
          ensure_dry_running(false, project) do
            package_name = project.get_package_name(directory)
            result_path = Gjp::Archiver.new(project).archive_package package_name
            print_generation_result(project, result_path)
          end
        end
      end
    end

    subcommand "generate-package-spec", "Create or refresh a spec file for a package" do
      option ["-f", "--filter"], "FILTER", "filter files to be installed by this spec", :default => "*.jar"
      parameter "[DIRECTORY]", "path to a package directory (src/<package name>)", :default => "."
      parameter "[POM]", "a pom file path", :default => "pom.xml"
      def execute
        checking_exceptions do
          project = Gjp::Project.new(".")
          ensure_dry_running(false, project) do
            package_name = project.get_package_name(directory)
            result_path, conflict_count = Gjp::SpecGenerator.new(project).generate_package_spec package_name, pom, filter
            print_generation_result(project, result_path, conflict_count)
          end
        end
      end
    end

    subcommand "generate-all", "Create or refresh specs, archives, scripts for a package and the kit" do
      option ["-f", "--filter"], "FILTER", "filter files to be installed by this package spec", :default => "*.jar"
      option ["-f", "--full"], :flag, "create a full archive (not incremental)"
      parameter "[DIRECTORY]", "path to a package directory (src/<package name>)", :default => "."
      parameter "[POM]", "a package pom file path", :default => "pom.xml"
      def execute
        checking_exceptions do
          project = Gjp::Project.new(".")
          ensure_dry_running(false, project) do
            package_name = project.get_package_name(directory)

            result_path = Gjp::Archiver.new(project).archive_kit(full?)
            print_generation_result(project, result_path)

            result_path, conflict_count = Gjp::SpecGenerator.new(project).generate_kit_spec
            print_generation_result(project, result_path, conflict_count)

            history_file = File.join(Dir.home, ".bash_history")
            result_path, conflict_count = Gjp::ScriptGenerator.new(project, history_file).generate_build_script(package_name)
            print_generation_result(project, result_path, conflict_count)

            result_path = Gjp::Archiver.new(project).archive_package package_name
            print_generation_result(project, result_path)

            result_path, conflict_count = Gjp::SpecGenerator.new(project).generate_package_spec package_name, pom, filter
            print_generation_result(project, result_path, conflict_count)
          end
        end
      end
    end

    subcommand "purge-jars", "Locates jars in src/ and moves them to kit/" do
      def execute
        checking_exceptions do
          project = Gjp::Project.new(".")

          ensure_dry_running(false, project) do
            project.purge_jars.each do |original, final|
              puts "Replaced #{original} with symlink pointing to to #{final}"
            end
          end
        end
      end
    end

    subcommand "get-maven-source-jars", "Attempts to download Maven kit/ sources" do
      def execute
        checking_exceptions do
          project = Gjp::Project.new(".")
          source_getter = Gjp::SourceGetter.new

          ensure_dry_running(false, project) do
            puts "Getting sources from Maven..."
            succeeded, failed = source_getter.get_maven_source_jars(project)

            puts "\n**SUMMARY**\n"
            puts "Sources found for:"
            succeeded.each do |path|
              puts " #{format_path(path, project)}"
            end

            puts "\nSources not found for:"
            failed.each do |path|
              puts " #{format_path(path, project)}"
            end
          end
        end
      end
    end

    subcommand "set-up-nonet-user", "Sets up a \"nonet\" user that cannot access the network" do
      def execute
        checking_exceptions do
          user = Gjp::LimitedNetworkUser.new("nonet")
          user.set_up

          "sudo #{user.get_path("useradd")} nonet\n" +
          "sudo #{user.get_path("iptables")} -A OUTPUT -m owner --uid-owner nonet -j DROP\n" +
          "User \"nonet\" set up, you can use \"sudo nonet\" to dry-run your build with no network access.\n" +
          "Note that the above iptables rule will be cleared at next reboot, you can use your distribution " +
          "tools to make it persistent or run \"gjp set-up-limited-nertwork-user\" again next time."
        end
      end
    end

    subcommand "tear-down-nonet-user", "Deletes a user previously created by gjp" do
      def execute
        checking_exceptions do
          user = Gjp::LimitedNetworkUser.new("nonet")

          user.tear_down

          "sudo #{user.get_path("iptables")} -D OUTPUT -m owner --uid-owner nonet -j DROP\n" +
          "sudo #{user.get_path("userdel")} nonet\n"
        end
      end
    end

    subcommand "get-pom", "Retrieves a pom file" do
      parameter "NAME", "a jar file name or a `name-version` string (heuristic)"
      def execute
        checking_exceptions do
          project = Gjp::Project.new(".")
          pom_getter = Gjp::PomGetter.new

          path, status = pom_getter.get_pom(name)
          if path
            text_status = if status == :found_in_jar
              "was inside the jar"
            elsif status == :found_via_sha1
              "found by sha1 search from search.maven.org"
            elsif status == :found_via_heuristic
              "found by heuristic search from search.maven.org"
            end

            puts "#{format_path(path, project)} written, #{text_status}"
          else
            puts "#{name}'s pom not found. Try:"
            puts "http://google.com/#q=#{URI::encode(pom_getter.cleanup_name(name) + " pom")}"
          end
        end
      end
    end

    subcommand "get-source", "Attempts to retrieve a project's sources" do
      parameter "POM", "a pom file path or URI"

      def execute
        checking_exceptions do
          project = Gjp::Project.new(".")
          source_getter = Gjp::SourceGetter.new

          puts "Attempting to find source through Maven...\n"
          if source_getter.get_maven_source_jar(project, pom)
            puts "\nSource jar found and added to Maven repository in kit/"
          else
            puts "\nSource jar not found in Maven. Saving effective POM..."
            effective_pom_path = Gjp::MavenRunner.new(project).get_effective_pom(pom)
            puts "#{effective_pom_path} saved. Looking for SCM address..."
            status, address = Gjp::SourceAddressGetter.new.get_source_address(effective_pom_path)
            if status != :not_found
              if status == :found_in_pom
                puts "Source SCM address found in #{effective_pom_path}: #{address}, attempting checkout..."
              elsif status == :found_on_github
                puts "Source SCM not found in POM."
                puts "Project found on GitHub: #{address}, attempting checkout..."
              end

              tag = Gjp::SourceGetter.new.get_source_from_scm(address, effective_pom_path, ".")
              if tag
                puts "Checked out tag #{tag}"
              else
                puts "Checked out, no tag found"
              end
            else
              puts "\nNothing found. Try:"
              pom = new Gjp::Pom(effective_pom_path)
              if pom.url and pom.url != ""
                puts pom.url
              else
                puts "http://google.com/#q=#{URI::encode(pom.artifact_id)}"
              end
            end
          end
        end
      end
    end

    private

    def ensure_dry_running(state, project)
      if project.is_dry_running == state
        yield
      else
        if state == true
          puts "Please start a dry-run first, use \"gjp dry-run\""
        else
          puts "Please finish or abort this dry-run first, use \"gjp finish\" or \"gjp finish --abort\""
        end
      end
    end

    # outputs output of a file generation
    def print_generation_result(project, result_path, conflict_count = 0)
      puts "#{format_path(result_path, project)} generated"
      if conflict_count > 0
        puts "Warning: #{conflict_count} unresolved conflicts"
      end
    end

    # generates a version of path relative to the current directory
    def format_path(path, project)
      full_path = if Pathname.new(path).relative?
        File.join(project.full_path, path)
      else
        path
      end
      Pathname.new(full_path).relative_path_from(Pathname.new(Dir.pwd))
    end

    # handles most fatal exceptions
    def checking_exceptions
      begin
        yield
      rescue Errno::EACCES => e
        $stderr.puts e
      rescue Errno::ENOENT => e
        $stderr.puts e
      rescue Errno::EEXIST => e
        $stderr.puts e
      rescue NoProjectDirectoryError => e
        $stderr.puts "#{e.directory} is not a gjp project directory, see gjp init"
      rescue NoPackageDirectoryError => e
        $stderr.puts "#{e.directory} is not a gjp package directory, see README"
      rescue GitAlreadyInitedError => e
        $stderr.puts "This directory is already a gjp project"
      rescue ExecutableNotFoundError => e
        $stderr.puts "Executable #{e.executable} not found in kit/ or any of its subdirectories"
      end
    end
  end
end
