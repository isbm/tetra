# encoding: UTF-8

module Tetra
  # runs programs from a tetra kit with tetra-specific options
  class KitRunner
    include Logging

    def initialize(project)
      @project = project
    end

    # finds an executable in a bin/ subdirectory of kit
    def find_executable(name)
      @project.from_directory do
        Find.find("kit") do |path|
          next unless path =~ /bin\/#{name}$/

          log.debug("found #{name} executable: #{path}")
          return path
        end
      end

      log.debug("#{name} executable not found")
      nil
    end

    # runs an external executable, returns true on success
    def run_executable(full_commandline)
      log.debug "running #{full_commandline}"
      Process.wait(Process.spawn(full_commandline))
      $CHILD_STATUS.exitstatus == 0
    end
  end

  # an executable from the kit was not found
  class ExecutableNotFoundError < Exception
    attr_reader :executable

    def initialize(executable)
      @executable = executable
    end
  end
end