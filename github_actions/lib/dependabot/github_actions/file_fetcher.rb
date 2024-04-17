# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

require "dependabot/file_fetchers"
require "dependabot/file_fetchers/base"

module Dependabot
  module GithubActions
    class FileFetcher < Dependabot::FileFetchers::Base
      extend T::Sig
      extend T::Helpers

      FILENAME_PATTERN = /\.ya?ml$/

      sig { override.params(filenames: T::Array[String]).returns(T::Boolean) }
      def self.required_files_in?(filenames)
        filenames.any? { |f| f.match?(FILENAME_PATTERN) }
      end

      sig { override.returns(String) }
      def self.required_files_message
        "Repo must contain a .github/workflows directory with YAML files or an action.yml file"
      end

      sig do
        override
          .params(
            source: Dependabot::Source,
            credentials: T::Array[Dependabot::Credential],
            repo_contents_path: T.nilable(String),
            options: T::Hash[String, String]
          )
          .void
      end
      def initialize(source:, credentials:, repo_contents_path: nil, options: {})
        @workflow_files = T.let([], T::Array[DependencyFile])
        super(source: source, credentials: credentials, repo_contents_path: repo_contents_path, options: options)
      end

      sig { override.returns(T::Array[DependencyFile]) }
      def fetch_files
        fetched_files = []
        fetched_files += correctly_encoded_workflow_files

        return fetched_files if fetched_files.any?

        if incorrectly_encoded_workflow_files.none?
          expected_paths =
            if directory == "/"
              File.join(directory, "action.yml") + " or /.github/workflows/<anything>.yml"
            else
              File.join(directory, "<anything>.yml")
            end

          raise(
            Dependabot::DependencyFileNotFound,
            expected_paths
          )
        else
          raise(
            Dependabot::DependencyFileNotParseable,
            T.must(incorrectly_encoded_workflow_files.first).path
          )
        end
      end

      private

      sig { returns(T::Array[DependencyFile]) }
      def workflow_files
        return @workflow_files unless @workflow_files.empty?

        # In the special case where the root directory is defined we also scan
        # the .github/workflows/ folder.
        if directory == "/"
          @workflow_files += [fetch_file_if_present("action.yml"), fetch_file_if_present("action.yaml")].compact

          workflows_dir = ".github/workflows"
        else
          workflows_dir = "."
        end

        @workflow_files +=
          repo_contents(dir: workflows_dir, raise_errors: false)
          .select { |f| f.type == "file" && f.name.match?(FILENAME_PATTERN) }
          .map { |f| fetch_file_from_host("#{workflows_dir}/#{f.name}") }
      end

      sig { returns(T::Array[DependencyFile]) }
      def correctly_encoded_workflow_files
        workflow_files.select { |f| f.content&.valid_encoding? }
      end

      sig { returns(T::Array[DependencyFile]) }
      def incorrectly_encoded_workflow_files
        workflow_files.reject { |f| f.content&.valid_encoding? }
      end
    end
  end
end

Dependabot::FileFetchers
  .register("github_actions", Dependabot::GithubActions::FileFetcher)
