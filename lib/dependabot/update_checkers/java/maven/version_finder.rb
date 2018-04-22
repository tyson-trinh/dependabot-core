# frozen_string_literal: true

require "nokogiri"
require "dependabot/shared_helpers"
require "dependabot/file_parsers/java/maven/repositories_finder"
require "dependabot/update_checkers/java/maven"
require "dependabot/utils/java/version"

module Dependabot
  module UpdateCheckers
    module Java
      class Maven
        class VersionFinder
          def initialize(dependency:, dependency_files:)
            @dependency = dependency
            @dependency_files = dependency_files
          end

          def latest_version
            possible_versions = versions

            unless wants_prerelease?
              possible_versions = possible_versions.reject(&:prerelease?)
            end

            unless wants_date_based_version?
              possible_versions =
                possible_versions.reject { |v| v > version_class.new(1900) }
            end

            possible_versions.last
          end

          def versions
            repository_urls.
              map { |url| dependency_metadata(url).css("versions > version") }.
              flatten.
              select { |node| version_class.correct?(node.content) }.
              map { |node| version_class.new(node.content) }.sort
          end

          private

          attr_reader :dependency, :dependency_files

          def wants_prerelease?
            return false unless dependency.version
            return false unless version_class.correct?(dependency.version)
            version_class.new(dependency.version).prerelease?
          end

          def wants_date_based_version?
            # Alternatively, we could hit the index URL for the package
            # and parse the messy HTML to get the updated at for each version.
            # The below saves a request, and is probably cleaner.
            return false unless dependency.version
            return false unless version_class.correct?(dependency.version)
            version_class.new(dependency.version) >= version_class.new(100)
          end

          def maven_central_latest_version
            repository_urls.
              map { |url| dependency_metadata(url).at_css("release")&.content }.
              max_by do |v|
                next version_class.new(v) if version_class.correct?(v)
                version_class.new("0")
              end
          end

          def dependency_metadata(repository_url)
            @dependency_metadata ||= {}
            @dependency_metadata[repository_url] ||=
              begin
                response = Excon.get(
                  dependency_metadata_url(repository_url),
                  idempotent: true,
                  middlewares: SharedHelpers.excon_middleware
                )
                Nokogiri::XML(response.body)
              end
          end

          def repository_urls
            @repository_urls ||=
              FileParsers::Java::Maven::RepositoriesFinder.new(
                dependency_files: dependency_files
              ).repository_urls(pom: pom)
          end

          def pom
            filename = dependency.requirements.first.fetch(:file)
            dependency_files.find { |f| f.name == filename }
          end

          def dependency_metadata_url(repository_url)
            group_id, artifact_id = dependency.name.split(":")

            "#{repository_url}/"\
            "#{group_id.tr('.', '/')}/"\
            "#{artifact_id}/"\
            "maven-metadata.xml"
          end

          def version_class
            Utils::Java::Version
          end
        end
      end
    end
  end
end
