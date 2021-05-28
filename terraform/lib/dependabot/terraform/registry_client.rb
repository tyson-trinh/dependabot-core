# frozen_string_literal: true

require "dependabot/dependency"
require "dependabot/source"
require "dependabot/terraform/version"

module Dependabot
  module Terraform
    # Terraform::RegistryClient is a basic API client to interact with a
    # terraform registry: https://www.terraform.io/docs/registry/api.html
    class RegistryClient
      PUBLIC_HOSTNAME = "registry.terraform.io"

      def initialize(hostname: PUBLIC_HOSTNAME, credentials: [])
        @hostname = hostname
        @tokens = credentials.each_with_object({}) do |item, memo|
          memo[item["host"]] = item["token"] if item["type"] == "terraform_registry"
        end
      end

      # Fetch all the versions of a provider, and return a Version
      # representation of them.
      #
      # @param identifier [String] the identifier for the dependency, i.e:
      # "hashicorp/aws"
      # @return [Array<Dependabot::Terraform::Version>]
      # @raise [RuntimeError] when the versions cannot be retrieved
      def all_provider_versions(identifier:)
        response = get(endpoint: "providers/#{identifier}/versions")

        JSON.parse(response).
          fetch("versions").
          map { |release| version_class.new(release.fetch("version")) }
      end

      # Fetch all the versions of a module, and return a Version
      # representation of them.
      #
      # @param identifier [String] the identifier for the dependency, i.e:
      # "hashicorp/consul/aws"
      # @return [Array<Dependabot::Terraform::Version>]
      # @raise [RuntimeError] when the versions cannot be retrieved
      def all_module_versions(identifier:)
        base_url = base_url_for(hostname, 'modules.v1')
        response = http_get!(URI.join(base_url, "#{identifier}/versions"))

        JSON.parse(response.body).
          fetch("modules").first.fetch("versions").
          map { |release| version_class.new(release.fetch("version")) }
      end

      # Fetch the "source" for a module or provider. We use the API to fetch
      # the source for a dependency, this typically points to a source code
      # repository, and then instantiate a Dependabot::Source object that we
      # can use to fetch Metadata about a specific version of the dependency.
      #
      # @param dependency [Dependabot::Dependency] the dependency who's source
      # we're attempting to find
      # @return Dependabot::Source
      # @raise [RuntimeError] when the source cannot be retrieved
      def source(dependency:)
        type = dependency.requirements.first[:source][:type]
        endpoint = if type == "registry"
                     "modules/#{dependency.name}/#{dependency.version}"
                   elsif type == "provider"
                     "providers/#{dependency.name}/#{dependency.version}"
                   else
                     raise "Invalid source type"
                   end
        response = get(endpoint: endpoint)

        source_url = JSON.parse(response).fetch("source")
        Source.from_url(source_url) if source_url
      end

      private

      attr_reader :hostname, :tokens

      def get(endpoint:)
        url = "https://#{hostname}/v1/#{endpoint}"

        response = Excon.get(
          url,
          idempotent: true,
          **SharedHelpers.excon_defaults(headers: headers_for(hostname))
        )

        raise "Response from registry was #{response.status}" unless response.status == 200

        response.body
      end

      def version_class
        Version
      end

      def headers_for(hostname)
        token = tokens[hostname]
        token ? { "Authorization" => "Bearer #{token}" } : {}
      end

      def base_url_for(hostname, key)
        response = http_get("https://#{hostname}/.well-known/terraform.json", headers_for(hostname))
        if response.status == 200
          json = JSON.parse(response.body)
          "https://#{hostname}#{json[key]}"
        else
          "https://#{hostname}/"
        end
      end

      def http_get(url, headers: {})
        Excon.get(url.to_s, idempotent: true, **SharedHelpers.excon_defaults(headers: headers))
      end

      def http_get!(url, headers: {})
        response = http_get(url, headers: headers)

        raise "Response from registry was #{response.status}" unless response.status == 200
        response
      end
    end
  end
end
