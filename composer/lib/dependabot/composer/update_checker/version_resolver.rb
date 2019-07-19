# frozen_string_literal: true

require "dependabot/errors"
require "json"
require "dependabot/shared_helpers"
require "dependabot/composer/update_checker"
require "dependabot/composer/version"
require "dependabot/composer/requirement"
require "dependabot/composer/native_helpers"

module Dependabot
  module Composer
    class UpdateChecker
      class VersionResolver
        class MissingExtensions < StandardError
          attr_reader :extensions

          def initialize(extensions)
            @extensions = extensions
            super
          end
        end

        VERSION_REGEX = /[0-9]+(?:\.[A-Za-z0-9\-_]+)*/.freeze
        SOURCE_TIMED_OUT_REGEX =
          /The "(?<url>[^"]+packages\.json)".*timed out/.freeze

        def initialize(credentials:, dependency:, dependency_files:,
                       requirements_to_unlock:, latest_allowable_version:)
          @credentials                  = credentials
          @dependency                   = dependency
          @dependency_files             = dependency_files
          @requirements_to_unlock       = requirements_to_unlock
          @latest_allowable_version     = latest_allowable_version
          @composer_platform_extensions = initial_platform
        end

        def latest_resolvable_version
          @latest_resolvable_version ||= fetch_latest_resolvable_version
        end

        private

        attr_reader :credentials, :dependency, :dependency_files,
                    :requirements_to_unlock, :latest_allowable_version,
                    :composer_platform_extensions

        def fetch_latest_resolvable_version
          version = fetch_latest_resolvable_version_string
          return if version.nil?
          return unless Composer::Version.correct?(version)

          Composer::Version.new(version)
        rescue MissingExtensions => e
          previous_extensions = composer_platform_extensions.dup
          update_required_extensions(e.extensions)
          raise if previous_extensions == composer_platform_extensions

          retry
        end

        def fetch_latest_resolvable_version_string
          base_directory = dependency_files.first.directory
          SharedHelpers.in_a_temporary_directory(base_directory) do
            File.write("composer.json", prepared_composer_json_content)
            File.write("composer.lock", lockfile.content) if lockfile
            File.write("auth.json", auth_json.content) if auth_json

            run_update_checker
          end
        rescue SharedHelpers::HelperSubprocessFailed => e
          retry_count ||= 0
          retry_count += 1
          retry if transitory_failure?(e) && retry_count < 2
          handle_composer_errors(e)
        end

        def transitory_failure?(error)
          return true if error.message.include?("404 Not Found")
          return true if error.message.include?("timed out")
          return true if error.message.include?("Temporary failure")

          error.message.include?("Content-Length mismatch")
        end

        def run_update_checker
          SharedHelpers.with_git_configured(credentials: credentials) do
            SharedHelpers.run_helper_subprocess(
              command: "php -d memory_limit=-1 #{php_helper_path}",
              escape_command_str: false,
              function: "get_latest_resolvable_version",
              args: [
                Dir.pwd,
                dependency.name.downcase,
                git_credentials,
                registry_credentials
              ]
            )
          end
        end

        def prepared_composer_json_content
          content = composer_file.content

          content = content.gsub(
            /"#{Regexp.escape(dependency.name)}"\s*:\s*".*"/,
            %("#{dependency.name}": "#{updated_version_requirement_string}")
          )

          json = JSON.parse(content)

          composer_platform_extensions.each do |extension, requirements|
            json["config"] ||= {}
            json["config"]["platform"] ||= {}
            json["config"]["platform"][extension] =
              version_for_reqs(requirements)
          end

          JSON.dump(json)
        end

        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/PerceivedComplexity
        def updated_version_requirement_string
          lower_bound =
            if requirements_to_unlock == :none
              dependency.requirements.first&.fetch(:requirement) || ">= 0"
            elsif dependency.version
              ">= #{dependency.version}"
            else
              version_for_requirement =
                dependency.requirements.map { |r| r[:requirement] }.compact.
                reject { |req_string| req_string.start_with?("<") }.
                select { |req_string| req_string.match?(VERSION_REGEX) }.
                map { |req_string| req_string.match(VERSION_REGEX) }.
                select { |version| Gem::Version.correct?(version) }.
                max_by { |version| Gem::Version.new(version) }

              ">= #{version_for_requirement || 0}"
            end

          # Add the latest_allowable_version as an upper bound. This means
          # ignore conditions are considered when checking for the latest
          # resolvable version.
          #
          # NOTE: This isn't perfect. If v2.x is ignored and v3 is out but
          # unresolvable then the `latest_allowable_version` will be v3, and
          # we won't be ignoring v2.x releases like we should be.
          return lower_bound unless latest_allowable_version

          # If the original requirement is just a stability flag just use that
          return lower_bound if lower_bound.strip.start_with?("@")

          lower_bound + ", <= #{latest_allowable_version}"
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/PerceivedComplexity

        # rubocop:disable Metrics/PerceivedComplexity
        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/CyclomaticComplexity
        # rubocop:disable Metrics/MethodLength
        def handle_composer_errors(error)
          sanitized_message = remove_url_credentials(error.message)

          if error.message.start_with?("Failed to execute git clone")
            dependency_url =
              error.message.match(/--mirror '(?<url>.*?)'/).
              named_captures.fetch("url")
            raise Dependabot::GitDependenciesNotReachable, dependency_url
          elsif error.message.start_with?("Failed to clone")
            dependency_url =
              error.message.match(/Failed to clone (?<url>.*?) via/).
              named_captures.fetch("url")
            raise Dependabot::GitDependenciesNotReachable, dependency_url
          elsif error.message.start_with?("Could not parse version") ||
                error.message.include?("does not allow connections to http://")
            raise Dependabot::DependencyFileNotResolvable, sanitized_message
          elsif error.message.include?("package requires php") ||
                error.message.include?("requested PHP extension")
            missing_extensions =
              error.message.scan(/\sext\-.*? .*?\s|(?<=requires )php .*?\s/).
              map do |extension_string|
                name, requirement = extension_string.strip.split(" ")
                { name: name, requirement: requirement }
              end
            raise MissingExtensions, missing_extensions
          elsif error.message.include?("cannot require itself") ||
                error.message.include?('packages.json" file could not be down')
            raise Dependabot::DependencyFileNotResolvable, error.message
          elsif error.message.include?("No driver found to handle VCS") &&
                !error.message.include?("@") && !error.message.include?("://")
            msg = "Dependabot detected a VCS requirement with a local path, "\
                  "rather than a URL. Dependabot does not support this "\
                  "setup.\n\nThe underlying error was:\n\n#{error.message}"
            raise Dependabot::DependencyFileNotResolvable, msg
          elsif error.message.include?("requirements could not be resolved")
            # We should raise a Dependabot::DependencyFileNotResolvable error
            # here, but can't confidently distinguish between cases where we
            # can't install and cases where we can't update. For now, we
            # therefore just ignore the dependency.
            nil
          elsif error.message.include?("URL required authentication") ||
                error.message.include?("403 Forbidden")
            source =
              error.message.match(%r{https?://(?<source>[^/]+)/}).
              named_captures.fetch("source")
            raise Dependabot::PrivateSourceAuthenticationFailure, source
          elsif error.message.match?(SOURCE_TIMED_OUT_REGEX)
            url = error.message.match(SOURCE_TIMED_OUT_REGEX).
                  named_captures.fetch("url")
            raise if url.include?("packagist.org")

            source = url.gsub(%r{/packages.json$}, "")
            raise Dependabot::PrivateSourceTimedOut, source
          elsif error.message.start_with?("Allowed memory size")
            raise Dependabot::OutOfMemory
          elsif error.message.start_with?("Package not found in updated") &&
                !dependency.top_level?
            # If we can't find the dependency in the composer.lock after an
            # update, but it was originally a sub-dependency, it's because the
            # dependency is no longer required and is just cruft in the
            # composer.json. In this case we just ignore the dependency.
            nil
          elsif error.message.include?("stefandoorn/sitemap-plugin-1.0.0.0") ||
                error.message.include?("simplethings/entity-audit-bundle-1.0.0")
            # We get a recurring error when attempting to update these repos
            # which doesn't recur locally and we can't figure out how to fix!
            #
            # Package is not installed: stefandoorn/sitemap-plugin-1.0.0.0
            nil
          else
            raise error
          end
        end
        # rubocop:enable Metrics/PerceivedComplexity
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/MethodLength

        def version_for_reqs(requirements)
          req_arrays =
            requirements.
            map { |str| Composer::Requirement.requirements_array(str) }
          potential_versions =
            req_arrays.flatten.map do |req|
              op, version = req.requirements.first
              case op
              when ">" then version.bump
              when "<" then Composer::Version.new("0.0.1")
              else version
              end
            end

          version =
            potential_versions.
            find do |v|
              req_arrays.any? { |reqs| reqs.all? { |r| r.satisfied_by?(v) } }
            end
          raise "No matching version for #{requirements}!" unless version

          version.to_s
        end

        def update_required_extensions(additional_extensions)
          additional_extensions.each do |ext|
            composer_platform_extensions[ext.fetch(:name)] ||= []
            composer_platform_extensions[ext.fetch(:name)] +=
              [ext.fetch(:requirement)]
            composer_platform_extensions[ext.fetch(:name)] =
              composer_platform_extensions[ext.fetch(:name)].uniq
          end
        end

        def php_helper_path
          NativeHelpers.composer_helper_path
        end

        def initial_platform
          return {} unless parsed_composer_file["type"] == "library"
          return {} unless parsed_composer_file.dig("require", "php")

          { "php" => [parsed_composer_file.dig("require", "php")] }
        end

        def parsed_composer_file
          JSON.parse(composer_file.content)
        end

        def composer_file
          @composer_file ||=
            dependency_files.find { |f| f.name == "composer.json" }
        end

        def lockfile
          @lockfile ||=
            dependency_files.find { |f| f.name == "composer.lock" }
        end

        def auth_json
          @auth_json ||= dependency_files.find { |f| f.name == "auth.json" }
        end

        def git_credentials
          credentials.
            select { |cred| cred["type"] == "git_source" }.
            select { |cred| cred["password"] }
        end

        def registry_credentials
          credentials.
            select { |cred| cred["type"] == "composer_repository" }.
            select { |cred| cred["password"] }
        end

        def remove_url_credentials(message)
          message.gsub(%r{(?<=://)[^\s]*:[^\s]*(?=@)}, "****")
        end
      end
    end
  end
end
