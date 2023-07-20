# typed: false
# frozen_string_literal: true

module Dependabot
  module Nuget
    module NativeHelpers
      def self.native_helpers_root
        helpers_root = ENV.fetch("DEPENDABOT_NATIVE_HELPERS_PATH", nil)
        return helpers_root unless helpers_root.nil?

        File.join(__dir__, "../../../helpers")
      end

      def self.run_nuget_updater_tool(repo_root, proj_path, dependency, is_transitive)
        exePath = File.join(native_helpers_root, "NuGetUpdater", "NuGetUpdater.Cli")
        command = [
          exePath,
          "--repo-root",
          repo_root,
          "--solution-or-project",
          proj_path,
          "--dependency",
          dependency.name,
          "--new-version",
          dependency.version,
          "--previous-version",
          dependency.previous_version,
          is_transitive ? "--transitive" : "",
          "--verbose"
        ].join(" ")

        fingerprint = [
          exePath,
          "--repo-root",
          "<repo-root>",
          "--solution-or-project",
          "<path-to-solution-or-project>",
          "--dependency",
          "<dependency-name>",
          "--new-version",
          "<new-version>",
          "--previous-version",
          "<previous-version>",
          is_transitive ? "--transitive" : "",
          "--verbose"
        ].join(" ")

        puts "running NuGet updater:\n" + command

        output = SharedHelpers.run_shell_command(command, fingerprint: fingerprint)

        puts output
      end
    end
  end
end
