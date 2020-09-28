# frozen_string_literal: true

require "dependabot/file_fetchers"
require "dependabot/file_fetchers/base"

module Dependabot
  module GoModules
    class FileFetcher < Dependabot::FileFetchers::Base
      def self.required_files_in?(filenames)
        filenames.include?("go.mod")
      end

      def self.required_files_message
        "Repo must contain a go.mod."
      end

      private

      def fetch_files
        # Ensure we always check out the full repo contents for go_module
        # updates.
        SharedHelpers.reset_git_repo(clone_repo_contents)

        unless go_mod
          raise(
            Dependabot::DependencyFileNotFound,
            File.join(directory, "go.mod")
          )
        end

        fetched_files = [go_mod]

        # Fetch the (optional) go.sum
        fetched_files << go_sum if go_sum

        # Fetch the main.go file if present, as this will later identify
        # this repo as an app.
        fetched_files << main if main

        fetched_files
      end

      def go_mod
        @go_mod ||= fetch_file_if_present("go.mod")
      end

      def go_sum
        @go_sum ||= fetch_file_if_present("go.sum")
      end

      def fetch_file_if_present(filename)
        path = Pathname.new(File.join(repo_contents_path, filename)).
               cleanpath.to_path
        content = File.read(path) if File.exist?(path)
        cleaned_path = path.gsub(%r{^/}, "")
        type = @linked_paths.key?(cleaned_path) ? "symlink" : type

        DependencyFile.new(
          name: Pathname.new(filename).cleanpath.to_path,
          directory: directory,
          type: type,
          content: content,
          symlink_target: @linked_paths.dig(cleaned_path, :path)
        )
      end

      def main
        return @main if @main

        go_files = Dir.glob("*.go")

        go_files.each do |filename|
          file_content = File.read(filename)
          next unless file_content.match?(/\s*package\s+main/)

          return @main = DependencyFile.new(
            name: filename,
            directory: "/",
            type: "file",
            support_file: true,
            content: file_content
          )
        end

        nil
      end
    end
  end
end

Dependabot::FileFetchers.
  register("go_modules", Dependabot::GoModules::FileFetcher)
