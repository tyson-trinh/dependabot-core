# frozen_string_literal: true

require "bundler"

require "bundler_definition_ruby_version_patch"
require "bundler_definition_bundler_version_patch"
require "bundler_git_source_patch"

require "dependabot/shared_helpers"
require "dependabot/errors"
require "dependabot/file_updaters/base"

# rubocop:disable Metrics/ClassLength
module Dependabot
  module FileUpdaters
    module Ruby
      class Bundler < Dependabot::FileUpdaters::Base
        require_relative "bundler/gemspec_sanitizer"
        require_relative "bundler/gemfile_updater"
        require_relative "bundler/git_pin_replacer"
        require_relative "bundler/git_source_remover"
        require_relative "bundler/requirement_replacer"
        require_relative "bundler/gemspec_dependency_name_finder"

        LOCKFILE_ENDING = /(?<ending>\s*(?:RUBY VERSION|BUNDLED WITH).*)/m
        GIT_DEPENDENCIES_SECTION = /GIT\n.*?\n\n(?!GIT)/m
        GIT_DEPENDENCY_DETAILS = /GIT\n.*?\n\n/m
        GEM_NOT_FOUND_ERROR_REGEX = /locked to (?<name>[^\s]+) \(/
        GEMSPEC_SOURCES = [
          ::Bundler::Source::Path,
          ::Bundler::Source::Gemspec
        ].freeze
        RETRYABLE_ERRORS = [::Bundler::HTTPError].freeze

        def self.updated_files_regex
          [/^Gemfile$/, /^Gemfile\.lock$/, %r{^[^/]*\.gemspec$}]
        end

        def updated_dependency_files
          updated_files = []

          if gemfile && file_changed?(gemfile)
            updated_files <<
              updated_file(
                file: gemfile,
                content: updated_gemfile_content(gemfile)
              )
          end

          if lockfile && dependencies.any?(&:appears_in_lockfile?)
            updated_files <<
              updated_file(file: lockfile, content: updated_lockfile_content)
          end

          top_level_gemspecs.each do |file|
            next unless file_changed?(file)
            updated_files <<
              updated_file(file: file, content: updated_gemspec_content(file))
          end

          evaled_gemfiles.each do |file|
            next unless file_changed?(file)
            updated_files <<
              updated_file(file: file, content: updated_gemfile_content(file))
          end

          updated_files
        end

        private

        def check_required_files
          file_names = dependency_files.map(&:name)

          if file_names.include?("Gemfile.lock") &&
             !file_names.include?("Gemfile")
            raise "A Gemfile must be provided if a lockfile is!"
          end

          return if file_names.any? { |name| name.match?(%r{^[^/]*\.gemspec$}) }
          return if file_names.include?("Gemfile")

          raise "A gemspec or Gemfile must be provided!"
        end

        def gemfile
          @gemfile ||= get_original_file("Gemfile")
        end

        def lockfile
          @lockfile ||= get_original_file("Gemfile.lock")
        end

        def evaled_gemfiles
          @evaled_gemfiles ||=
            dependency_files.
            reject { |f| f.name.end_with?(".gemspec") }.
            reject { |f| f.name.end_with?(".lock") }.
            reject { |f| f.name.end_with?(".ruby-version") }.
            reject { |f| f.name == "Gemfile" }
        end

        def updated_gemfile_content(file)
          GemfileUpdater.new(
            dependencies: dependencies,
            gemfile: file
          ).updated_gemfile_content
        end

        def updated_gemspec_content(gemspec)
          content = gemspec.content

          dependencies.each do |dependency|
            content = replace_gemspec_version_requirement(
              gemspec, dependency, content
            )
          end

          content
        end

        def replace_gemspec_version_requirement(gemspec, dependency, content)
          return content unless requirement_changed?(gemspec, dependency)

          updated_requirement =
            dependency.requirements.
            find { |r| r[:file] == gemspec.name }.
            fetch(:requirement)

          RequirementReplacer.new(
            dependency: dependency,
            file_type: :gemspec,
            updated_requirement: updated_requirement
          ).rewrite(content)
        end

        def updated_lockfile_content
          @updated_lockfile_content ||=
            begin
              updated_content = build_updated_lockfile
              if lockfile.content == updated_content
                raise "Expected content to change!"
              end
              updated_content
            end
        end

        def build_updated_lockfile
          base_directory = dependency_files.first.directory
          lockfile_body =
            SharedHelpers.in_a_temporary_directory(base_directory) do |tmp_dir|
              write_temporary_dependency_files

              SharedHelpers.in_a_forked_process do
                # Set the path for path gemspec correctly
                ::Bundler.instance_variable_set(:@root, tmp_dir)

                # Remove installed gems from the default Rubygems index
                ::Gem::Specification.all = []

                # Set auth details
                relevant_credentials.each do |cred|
                  ::Bundler.settings.set_command_option(
                    cred.fetch("host"),
                    cred["token"] || "#{cred['username']}:#{cred['password']}"
                  )
                end

                generate_lockfile
              end
            end
          post_process_lockfile(lockfile_body)
        end

        def generate_lockfile
          dependencies_to_unlock = dependencies.map(&:name)

          begin
            definition = build_definition(dependencies_to_unlock)

            old_reqs = lock_deps_being_updated_to_exact_versions(definition)

            definition.resolve_remotely!

            old_reqs.each do |dep_name, old_req|
              definition.dependencies.
                find { |d| d.name == dep_name }.
                instance_variable_set(:@requirement, old_req)
            end

            definition.to_lock
          rescue ::Bundler::GemNotFound => error
            unlock_yanked_gem(dependencies_to_unlock, error) && retry
          rescue ::Bundler::VersionConflict => error
            unlock_blocking_subdeps(dependencies_to_unlock, error) && retry
          rescue *RETRYABLE_ERRORS
            raise if @retrying
            @retrying = true
            sleep(rand(1.0..5.0))
            retry
          end
        end

        def unlock_yanked_gem(dependencies_to_unlock, error)
          raise unless error.message.match?(GEM_NOT_FOUND_ERROR_REGEX)
          gem_name = error.message.match(GEM_NOT_FOUND_ERROR_REGEX).
                     named_captures["name"]
          raise if dependencies_to_unlock.include?(gem_name)
          dependencies_to_unlock << gem_name
        end

        def unlock_blocking_subdeps(dependencies_to_unlock, error)
          all_deps = ::Bundler::LockfileParser.new(lockfile.content).
                     specs.map(&:name)
          top_level = build_definition([]).dependencies.map(&:name)
          allowed_new_unlocks = all_deps - top_level - dependencies_to_unlock

          potentials_deps =
            error.cause.conflicts.values.
            flat_map(&:requirement_trees).
            map do |tree|
              tree.find { |req| allowed_new_unlocks.include?(req.name) }
            end.compact.map(&:name)

          raise if potentials_deps.none?

          dependencies_to_unlock.append(*potentials_deps)
        end

        def build_definition(dependencies_to_unlock)
          ::Bundler::Definition.build(
            "Gemfile",
            "Gemfile.lock",
            gems: dependencies_to_unlock
          )
        end

        def lock_deps_being_updated_to_exact_versions(definition)
          dependencies.each_with_object({}) do |dep, old_reqs|
            next unless Gem::Version.correct?(dep.version)
            new_req = Gem::Requirement.create("= #{dep.version}")
            defn_dep = definition.dependencies.find { |d| d.name == dep.name }
            next unless defn_dep
            old_reqs[dep.name] = defn_dep.requirement
            defn_dep.instance_variable_set(:@requirement, new_req)
          end
        end

        def write_temporary_dependency_files
          File.write("Gemfile", updated_gemfile_content(gemfile))
          File.write("Gemfile.lock", lockfile.content)

          top_level_gemspecs.each do |gemspec|
            File.write(
              gemspec.name,
              sanitized_gemspec_content(updated_gemspec_content(gemspec))
            )
          end

          write_ruby_version_file
          write_path_gemspecs
          write_imported_ruby_files

          evaled_gemfiles.each do |file|
            path = file.name
            FileUtils.mkdir_p(Pathname.new(path).dirname)
            File.write(path, updated_gemfile_content(file))
          end
        end

        def write_ruby_version_file
          return unless ruby_version_file
          path = ruby_version_file.name
          FileUtils.mkdir_p(Pathname.new(path).dirname)
          File.write(path, ruby_version_file.content)
        end

        def write_path_gemspecs
          path_gemspecs.each do |file|
            path = file.name
            FileUtils.mkdir_p(Pathname.new(path).dirname)
            File.write(path, sanitized_gemspec_content(file.content))
          end
        end

        def write_imported_ruby_files
          imported_ruby_files.each do |file|
            path = file.name
            FileUtils.mkdir_p(Pathname.new(path).dirname)
            File.write(path, file.content)
          end
        end

        def path_gemspecs
          all = dependency_files.select { |f| f.name.end_with?(".gemspec") }
          all - top_level_gemspecs
        end

        def imported_ruby_files
          dependency_files.select { |f| f.name.end_with?(".rb") }
        end

        def top_level_gemspecs
          dependency_files.select { |f| f.name.match?(%r{^[^/]*\.gemspec$}) }
        end

        def ruby_version_file
          dependency_files.find { |f| f.name == ".ruby-version" }
        end

        def post_process_lockfile(lockfile_body)
          lockfile_body = reorder_git_dependencies(lockfile_body)
          replace_lockfile_ending(lockfile_body)
        end

        def reorder_git_dependencies(lockfile_body)
          new_section = lockfile_body.match(GIT_DEPENDENCIES_SECTION)&.to_s
          old_section = lockfile.content.match(GIT_DEPENDENCIES_SECTION)&.to_s

          return lockfile_body unless new_section && old_section

          new_deps = new_section.scan(GIT_DEPENDENCY_DETAILS)
          old_deps = old_section.scan(GIT_DEPENDENCY_DETAILS)

          return lockfile_body unless new_deps.count == old_deps.count

          reordered_new_section = new_deps.sort_by do |new_dep_details|
            remote = new_dep_details.match(/remote: (?<remote>.*\n)/)[:remote]
            i = old_deps.index { |details| details.include?(remote) }

            # If this dependency isn't in the old lockfile then we can't rely on
            # that (presumably outdated) lockfile to do reordering. Instead, we
            # just return the default-ordered content just generated.
            return lockfile_body unless i
            i
          end.join

          lockfile_body.gsub(new_section, reordered_new_section)
        end

        def replace_lockfile_ending(lockfile_body)
          # Re-add the old `BUNDLED WITH` version (and remove the RUBY VERSION
          # if it wasn't previously present in the lockfile)
          lockfile_body.gsub(
            LOCKFILE_ENDING,
            lockfile.content.match(LOCKFILE_ENDING)&.[](:ending) || "\n"
          )
        end

        def sanitized_gemspec_content(gemspec_content)
          new_version = replacement_version_for_gemspec(gemspec_content)

          GemspecSanitizer.
            new(replacement_version: new_version).
            rewrite(gemspec_content)
        end

        def replacement_version_for_gemspec(gemspec_content)
          return "0.0.1" unless lockfile

          gemspec_specs =
            ::Bundler::LockfileParser.new(lockfile.content).specs.
            select { |s| GEMSPEC_SOURCES.include?(s.source.class) }

          gem_name =
            GemspecDependencyNameFinder.new(gemspec_content: gemspec_content).
            dependency_name

          return gemspec_specs.first&.version || "0.0.1" unless gem_name
          spec = gemspec_specs.find { |s| s.name == gem_name }
          spec&.version || gemspec_specs.first&.version || "0.0.1"
        end

        def relevant_credentials
          credentials.select do |cred|
            next true if cred["type"] == "git_source"
            next true if cred["type"] == "rubygems_server"
            false
          end
        end
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
