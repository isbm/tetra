# encoding: UTF-8

module Tetra
  # tetra generate-script
  class GenerateScriptSubcommand < Tetra::Subcommand
    def execute
      checking_exceptions do
        project = Tetra::Project.new(".")
        ensure_dry_running(:has_finished, project) do
          history = File.join(Dir.home, ".bash_history")
          result_path, conflict_count =
            Tetra::Package.new(project).to_script(history)
          print_generation_result(project, result_path, conflict_count)
        end
      end
    end
  end
end
