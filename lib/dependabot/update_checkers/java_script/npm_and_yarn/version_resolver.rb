# frozen_string_literal: true

require "dependabot/update_checkers/java_script/npm_and_yarn"
require "dependabot/file_parsers/java_script/npm_and_yarn"
require "dependabot/file_updaters/java_script/npm_and_yarn/npmrc_builder"
require "dependabot/utils/java_script/version"
require "dependabot/shared_helpers"
require "dependabot/errors"

# rubocop:disable Metrics/ClassLength
module Dependabot
  module UpdateCheckers
    module JavaScript
      class NpmAndYarn
        class VersionResolver
          # Error message from yarn add:
          # " > @reach/router@1.2.1" has incorrect \
          # peer dependency "react@15.x || 16.x || 16.4.0-alpha.0911da3"
          YARN_PEER_DEP_ERROR_REGEX =
            /
              "\s>\s(?<requiring_dep>[^"]+)"\s
              has\sincorrect\speer\sdependency\s
              "(?<required_dep>[^"]+)"
            /x.freeze

          # Error message from npm install:
          # react-dom@15.2.0 requires a peer of react@^15.2.0 \
          # but none is installed. You must install peer dependencies yourself.
          NPM_PEER_DEP_ERROR_REGEX =
            /
              (?<requiring_dep>[^\s]+)\s
              requires\sa\speer\sof\s
              (?<required_dep>[^\s]+)\sbut\snone\sis\sinstalled.
            /x.freeze

          def initialize(dependency:, credentials:, dependency_files:,
                         latest_allowable_version:, latest_version_finder:)
            @dependency               = dependency
            @credentials              = credentials
            @dependency_files         = dependency_files
            @latest_allowable_version = latest_allowable_version
            @latest_version_finder    = latest_version_finder
          end

          def latest_resolvable_version
            unless relevant_unmet_peer_dependencies.any?
              return latest_allowable_version
            end

            satisfying_versions.first
          end

          private

          attr_reader :dependency, :credentials, :dependency_files,
                      :latest_allowable_version, :latest_version_finder

          def peer_dependency_errors
            return @peer_dependency_errors if @peer_dependency_errors_checked

            @peer_dependency_errors_checked = true

            @peer_dependency_errors =
              fetch_peer_dependency_errors(version: latest_allowable_version)
          end

          def old_peer_dependency_errors
            if @old_peer_dependency_errors_checked
              return @old_peer_dependency_errors
            end

            @old_peer_dependency_errors_checked = true

            @old_peer_dependency_errors =
              fetch_peer_dependency_errors(version: dependency.version)
          end

          def fetch_peer_dependency_errors(version:)
            # TODO: Add all of the error handling that the FileUpdater does
            # here (since problematic repos will be resolved here before they're
            # seen by the FileUpdater)
            SharedHelpers.in_a_temporary_directory do
              write_temporary_dependency_files

              package_files.map do |file|
                path = Pathname.new(file.name).dirname
                run_checker(path: path, version: version)
              rescue SharedHelpers::HelperSubprocessFailed => error
                if (match = error.message.match(NPM_PEER_DEP_ERROR_REGEX))
                  match.named_captures
                elsif (match = error.message.match(YARN_PEER_DEP_ERROR_REGEX))
                  match.named_captures
                else
                  raise
                end
              end.compact
            end
          end

          def unmet_peer_dependencies
            peer_dependency_errors.
              map { |captures| error_details_from_captures(captures) }
          end

          def old_unmet_peer_dependencies
            old_peer_dependency_errors.
              map { |captures| error_details_from_captures(captures) }
          end

          def error_details_from_captures(captures)
            {
              requirement_name:
                captures.fetch("required_dep").sub(/@[^@]+$/, ""),
              requirement_version:
                captures.fetch("required_dep").split("@").last,
              requiring_dep_name:
                captures.fetch("requiring_dep").sub(/@[^@]+$/, "")
            }
          end

          def relevant_unmet_peer_dependencies
            relevant_unmet_peer_dependencies =
              unmet_peer_dependencies.select do |dep|
                dep[:requirement_name] == dependency.name ||
                  dep[:requiring_dep_name] == dependency.name
              end

            return [] if relevant_unmet_peer_dependencies.empty?

            relevant_unmet_peer_dependencies.
              reject { |issue| old_unmet_peer_dependencies.include?(issue) }
          end

          def satisfying_versions
            latest_version_finder.
              possible_versions_with_details.
              select do |version, details|
                unless peer_reqs_on_dep.all? { |r| r.satisfied_by?(version) }
                  next false
                end
                next true unless details["peerDependencies"]

                details["peerDependencies"].all? do |dep, req|
                  dep = top_level_dependencies.find { |d| d.name == dep }
                  req = Utils::JavaScript::Requirement.new(req)
                  next unless version_for_dependency(dep)

                  req.satisfied_by?(version_for_dependency(dep))
                end
              end.
              map(&:first)
          end

          def peer_reqs_on_dep
            unmet_peer_dependencies.
              select { |dep| dep[:requirement_name] == dependency.name }.
              map { |dep| dep[:requirement_version] }.
              map { |req| Utils::JavaScript::Requirement.new(req) }
          end

          def run_checker(path:, version:)
            if [*package_locks, *shrinkwraps].any?
              run_npm_checker(path: path, version: version)
            end

            run_yarn_checker(path: path, version: version) if yarn_locks.any?
            run_yarn_checker(path: path, version: version) if lockfiles.none?
          end

          def run_yarn_checker(path:, version:)
            SharedHelpers.with_git_configured(credentials: credentials) do
              Dir.chdir(path) do
                SharedHelpers.run_helper_subprocess(
                  command: "node #{yarn_helper_path}",
                  function: "checkPeerDependencies",
                  args: [
                    Dir.pwd,
                    dependency.name,
                    version,
                    requirements_for_path(dependency.requirements, path),
                    top_level_dependencies.map(&:to_h)
                  ]
                )
              end
            end
          end

          def run_npm_checker(path:, version:)
            SharedHelpers.with_git_configured(credentials: credentials) do
              Dir.chdir(path) do
                SharedHelpers.run_helper_subprocess(
                  command: "node #{npm_helper_path}",
                  function: "checkPeerDependencies",
                  args: [
                    Dir.pwd,
                    dependency.name,
                    version,
                    requirements_for_path(dependency.requirements, path),
                    top_level_dependencies.map(&:to_h)
                  ]
                )
              end
            end
          end

          def requirements_for_path(requirements, path)
            return requirements if path.to_s == "."

            requirements.map do |r|
              next unless r[:file].start_with?("#{path}/")

              r.merge(file: r[:file].gsub(/^#{Regexp.quote("#{path}/")}/, ""))
            end.compact
          end

          def write_temporary_dependency_files
            write_lock_files

            File.write(".npmrc", npmrc_content)

            package_files.each do |file|
              path = file.name
              FileUtils.mkdir_p(Pathname.new(path).dirname)

              updated_content = file.content
              updated_content = replace_ssh_sources(updated_content)

              # A bug prevents Yarn recognising that a directory is part of a
              # workspace if it is specified with a `./` prefix.
              updated_content = remove_workspace_path_prefixes(updated_content)

              updated_content = sanitized_package_json_content(updated_content)
              File.write(file.name, updated_content)
            end
          end

          def write_lock_files
            yarn_locks.each do |f|
              FileUtils.mkdir_p(Pathname.new(f.name).dirname)
              File.write(f.name, prepared_yarn_lockfile_content(f.content))
            end

            package_locks.each do |f|
              FileUtils.mkdir_p(Pathname.new(f.name).dirname)
              File.write(f.name, f.content)
            end

            shrinkwraps.each do |f|
              FileUtils.mkdir_p(Pathname.new(f.name).dirname)
              File.write(f.name, f.content)
            end
          end

          def prepared_yarn_lockfile_content(content)
            content.gsub(/^#{Regexp.quote(dependency.name)}\@.*?\n\n/m, "")
          end

          def npmrc_content
            FileUpdaters::JavaScript::NpmAndYarn::NpmrcBuilder.new(
              credentials: credentials,
              dependency_files: dependency_files
            ).npmrc_content
          end

          # TODO: Move into a generic file preparer class that can be reused
          # between this class and the FileUpdater
          def replace_ssh_sources(content)
            updated_content = content

            git_ssh_requirements_to_swap.each do |req|
              new_req = req.gsub(%r{git\+ssh://git@(.*?)[:/]}, 'https://\1/')
              updated_content = updated_content.gsub(req, new_req)
            end

            updated_content
          end

          def remove_workspace_path_prefixes(content)
            json = JSON.parse(content)
            return content unless json.key?("workspaces")

            workspace_object = json.fetch("workspaces")
            paths_array =
              if workspace_object.is_a?(Hash)
                workspace_object.values_at("packages", "nohoist").
                  flatten.compact
              elsif workspace_object.is_a?(Array) then workspace_object
              else raise "Unexpected workspace object"
              end

            paths_array.each { |path| path.gsub!(%r{^\./}, "") }

            json.to_json
          end

          def git_ssh_requirements_to_swap
            if @git_ssh_requirements_to_swap
              return @git_ssh_requirements_to_swap
            end

            @git_ssh_requirements_to_swap = []

            package_files.each do |file|
              FileParsers::JavaScript::NpmAndYarn::DEPENDENCY_TYPES.each do |t|
                JSON.parse(file.content).fetch(t, {}).each do |_, requirement|
                  next unless requirement.start_with?("git+ssh:")

                  req = requirement.split("#").first
                  @git_ssh_requirements_to_swap << req
                end
              end
            end

            @git_ssh_requirements_to_swap
          end

          def sanitized_package_json_content(content)
            content.
              gsub(/\{\{.*?\}\}/, "something"). # {{ name }} syntax not allowed
              gsub("\\ ", " ")                  # escaped whitespace not allowed
          end

          def version_class
            Utils::JavaScript::Version
          end

          # Top level dependecies are required in the peer dep checker
          # to fetch the manifests for all top level deps which may contain
          # "peerDependency" requirements
          def top_level_dependencies
            @top_level_dependencies ||= FileParsers::JavaScript::NpmAndYarn.new(
              dependency_files: dependency_files,
              source: nil,
              credentials: credentials
            ).parse.select(&:top_level?)
          end

          def lockfiles
            [*yarn_locks, *package_locks, *shrinkwraps]
          end

          def package_locks
            @package_locks ||=
              dependency_files.
              select { |f| f.name.end_with?("package-lock.json") }
          end

          def yarn_locks
            @yarn_locks ||=
              dependency_files.
              select { |f| f.name.end_with?("yarn.lock") }
          end

          def shrinkwraps
            @shrinkwraps ||=
              dependency_files.
              select { |f| f.name.end_with?("npm-shrinkwrap.json") }
          end

          def package_files
            @package_files ||=
              dependency_files.
              select { |f| f.name.end_with?("package.json") }
          end

          def yarn_helper_path
            project_root = File.join(File.dirname(__FILE__), "../../../../..")
            File.join(project_root, "helpers/yarn/bin/run.js")
          end

          def npm_helper_path
            project_root = File.join(File.dirname(__FILE__), "../../../../..")
            File.join(project_root, "helpers/npm/bin/run.js")
          end

          def version_for_dependency(dep)
            if dep.version && version_class.correct?(dep.version)
              return version_class.new(dep.version)
            end

            dep.requirements.map { |r| r[:requirement] }.compact.
              reject { |req_string| req_string.start_with?("<") }.
              select { |req_string| req_string.match?(version_regex) }.
              map { |req_string| req_string.match(version_regex) }.
              select { |version| version_class.correct?(version.to_s) }.
              map { |version| version_class.new(version.to_s) }.
              max
          end

          def version_regex
            version_class::VERSION_PATTERN
          end
        end
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
