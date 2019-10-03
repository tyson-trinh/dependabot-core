# frozen_string_literal: true

require "strscan"
require "dependabot/pull_request_creator/message_builder"

module Dependabot
  class PullRequestCreator
    class MessageBuilder
      class LinkAndMentionSanitizer
        GITHUB_USERNAME = /[a-z0-9]+(-[a-z0-9]+)*/i.freeze
        GITHUB_REF_REGEX = %r{
          (?:https?://)?
          github\.com/(?<repo>#{GITHUB_USERNAME}/[^/\s]+)/
          (?:issue|pull)s?/(?<number>\d+)
        }x.freeze
        CODEBLOCK_REGEX = /```|~~~/.freeze
        # End of string
        EOS_REGEX = /\z/.freeze

        attr_reader :github_redirection_service

        def initialize(github_redirection_service:)
          @github_redirection_service = github_redirection_service
        end

        def sanitize_links_and_mentions(text:)
          # We don't want to sanitize any links or mentions that are contained
          # within code blocks, so we split the text on "```" or "~~~"
          lines = []
          scan = StringScanner.new(text)
          until scan.eos?
            line = scan.scan_until(CODEBLOCK_REGEX) ||
                   scan.scan_until(EOS_REGEX)
            delimiter = line.match(CODEBLOCK_REGEX)&.to_s
            unless delimiter && lines.count { |l| l.include?(delimiter) }.odd?
              line = sanitize_mentions(line)
              line = sanitize_links(line)
            end
            lines << line
          end
          lines.join
        end

        private

        def sanitize_mentions(text)
          text.gsub(%r{(?<![A-Za-z0-9`~])@#{GITHUB_USERNAME}/?}) do |mention|
            next mention if mention.end_with?("/")

            last_match = Regexp.last_match

            sanitized_mention = mention.gsub("@", "@&#8203;")
            if last_match.pre_match.chars.last == "[" &&
               last_match.post_match.chars.first == "]"
              sanitized_mention
            else
              "[#{sanitized_mention}]"\
              "(https://github.com/#{mention.tr('@', '')})"
            end
          end
        end

        def sanitize_links(text)
          text.gsub(GITHUB_REF_REGEX) do |ref|
            last_match = Regexp.last_match
            previous_char = last_match.pre_match.chars.last
            next_char = last_match.post_match.chars.first

            sanitized_url =
              ref.gsub("github.com", github_redirection_service || "github.com")
            if (previous_char.nil? || previous_char.match?(/\s/)) &&
               (next_char.nil? || next_char.match?(/\s/))
              number = last_match.named_captures.fetch("number")
              repo = last_match.named_captures.fetch("repo")
              "[#{repo}##{number}]"\
              "(#{sanitized_url})"
            else
              sanitized_url
            end
          end
        end
      end
    end
  end
end
