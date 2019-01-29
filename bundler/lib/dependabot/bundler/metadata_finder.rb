# frozen_string_literal: true

require "excon"
require "dependabot/metadata_finders/base"

module Dependabot
  module Bundler
    class MetadataFinder < Dependabot::MetadataFinders::Base
      SOURCE_KEYS = %w(
        source_code_uri
        homepage_uri
        wiki_uri
        bug_tracker_uri
        documentation_uri
        changelog_uri
        mailing_list_uri
        download_uri
      ).freeze

      def homepage_url
        return super unless %w(default rubygems).include?(new_source_type)
        return super unless rubygems_api_response["homepage_uri"]

        rubygems_api_response["homepage_uri"]
      end

      private

      def look_up_source
        case new_source_type
        when "git" then find_source_from_git_url
        when "default", "rubygems" then find_source_from_rubygems
        else raise "Unexpected source type: #{new_source_type}"
        end
      end

      def new_source_type
        sources =
          dependency.requirements.map { |r| r.fetch(:source) }.uniq.compact

        return "default" if sources.empty?
        raise "Multiple sources! #{sources.join(', ')}" if sources.count > 1

        sources.first[:type] || sources.first.fetch("type")
      end

      def find_source_from_rubygems
        api_source = find_source_from_rubygems_api_response
        return api_source if api_source || new_source_type == "default"

        find_source_from_gemspec_download
      end

      def find_source_from_rubygems_api_response
        source_url = rubygems_api_response.
                     values_at(*SOURCE_KEYS).
                     compact.
                     find { |url| Source.from_url(url) }

        Source.from_url(source_url)
      end

      def find_source_from_git_url
        info = dependency.requirements.map { |r| r[:source] }.compact.first

        url = info[:url] || info.fetch("url")
        Source.from_url(url)
      end

      def find_source_from_gemspec_download
        github_urls = []
        return unless rubygems_marshalled_gemspec_response

        rubygems_marshalled_gemspec_response.scan(Source::SOURCE_REGEX) do
          github_urls << Regexp.last_match.to_s
        end

        source_url = github_urls.find do |url|
          repo = Source.from_url(url).repo
          repo.downcase.end_with?(dependency.name)
        end
        return unless source_url

        Source.from_url(source_url)
      end

      # Note: This response MUST NOT be unmarshalled
      # (as calling Marshal.load is unsafe)
      def rubygems_marshalled_gemspec_response
        if defined?(@rubygems_marshalled_gemspec_response)
          return @rubygems_marshalled_gemspec_response
        end

        gemspec_uri =
          "#{registry_url}quick/Marshal.4.8/"\
          "#{dependency.name}-#{dependency.version}.gemspec.rz"

        response =
          Excon.get(
            gemspec_uri,
            headers: registry_auth_headers,
            idempotent: true,
            **SharedHelpers.excon_defaults
          )

        if response.status >= 400
          return @rubygems_marshalled_gemspec_response = nil
        end

        @rubygems_marshalled_gemspec_response =
          Zlib::Inflate.inflate(response.body)
      rescue Zlib::DataError
        @rubygems_marshalled_gemspec_response = nil
      end

      def rubygems_api_response
        return @rubygems_api_response if defined?(@rubygems_api_response)

        response =
          Excon.get(
            "#{registry_url}api/v1/gems/#{dependency.name}.json",
            headers: registry_auth_headers,
            idempotent: true,
            **SharedHelpers.excon_defaults
          )
        return @rubygems_api_response = {} if response.status >= 400

        response_body = response.body
        response_body = augment_private_response_if_appropriate(response_body)

        @rubygems_api_response = JSON.parse(response_body)
        append_slash_to_source_code_uri(@rubygems_api_response)
      rescue JSON::ParserError, Excon::Error::Timeout
        @rubygems_api_response = {}
      end

      def append_slash_to_source_code_uri(listing)
        # We have to do this so that `Source.from_url(...)` doesn't prune the
        # last line off of the directory.
        return listing unless listing&.fetch("source_code_uri", nil)
        return listing if listing.fetch("source_code_uri").end_with?("/")

        listing["source_code_uri"] = listing["source_code_uri"] + "/"
        listing
      end

      def augment_private_response_if_appropriate(response_body)
        return response_body if new_source_type == "default"

        parsed_body = JSON.parse(response_body)
        return response_body if (SOURCE_KEYS - parsed_body.keys).none?

        digest = parsed_body.values_at("version", "authors", "info").hash

        source_url = parsed_body.
                     values_at(*SOURCE_KEYS).
                     compact.
                     find { |url| Source.from_url(url) }
        return response_body if source_url

        rubygems_response =
          Excon.get(
            "https://rubygems.org/api/v1/gems/#{dependency.name}.json",
            idempotent: true,
            **SharedHelpers.excon_defaults
          )
        parsed_rubygems_body = JSON.parse(rubygems_response.body)
        rubygems_digest =
          parsed_rubygems_body.values_at("version", "authors", "info").hash

        digest == rubygems_digest ? rubygems_response.body : response_body
      rescue JSON::ParserError, Excon::Error::Socket, Excon::Error::Timeout
        response_body
      end

      def registry_url
        return "https://rubygems.org/" if new_source_type == "default"

        info = dependency.requirements.map { |r| r[:source] }.compact.first
        info[:url] || info.fetch("url")
      end

      def registry_auth_headers
        return {} unless new_source_type == "rubygems"

        token =
          credentials.
          select { |cred| cred["type"] == "rubygems_server" }.
          find { |cred| registry_url.include?(cred["host"]) }&.
          fetch("token")

        return {} unless token

        token += ":" unless token.include?(":")
        encoded_token = Base64.encode64(token).delete("\n")
        { "Authorization" => "Basic #{encoded_token}" }
      end
    end
  end
end
