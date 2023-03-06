# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency_change"
require "dependabot/job"

RSpec.describe Dependabot::DependencyChange do
  subject(:dependency_change) do
    described_class.new(
      job: job,
      dependencies: dependencies,
      updated_dependency_files: updated_dependency_files
    )
  end

  let(:job) do
    instance_double(Dependabot::Job)
  end

  let(:dependencies) do
    [
      Dependabot::Dependency.new(
        name: "business",
        package_manager: "bundler",
        version: "1.8.0",
        previous_version: "1.7.0",
        requirements: [
          { file: "Gemfile", requirement: "~> 1.8.0", groups: [], source: nil }
        ],
        previous_requirements: [
          { file: "Gemfile", requirement: "~> 1.7.0", groups: [], source: nil }
        ]
      )
    ]
  end

  let(:updated_dependency_files) do
    [
      Dependabot::DependencyFile.new(
        name: "Gemfile",
        content: fixture("bundler/original/Gemfile"),
        directory: "/"
      ),
      Dependabot::DependencyFile.new(
        name: "Gemfile.lock",
        content: fixture("bundler/original/Gemfile.lock"),
        directory: "/"
      )
    ]
  end

  describe "#pr_message" do
    let(:github_source) do
      {
        "provider" => "github",
        "repo" => "dependabot-fixtures/dependabot-test-ruby-package",
        "directory" => "/",
        "branch" => nil,
        "api-endpoint" => "https://api.github.com/",
        "hostname" => "github.com"
      }
    end

    let(:job_credentials) do
      [
        {
          "type" => "git_source",
          "host" => "github.com",
          "username" => "x-access-token",
          "password" => "github-token"
        },
        { "type" => "random", "secret" => "codes" }
      ]
    end

    let(:commit_message_options) do
      {
        include_scope: true,
        prefix: "[bump]",
        prefix_development: "[bump-dev]"
      }
    end

    let(:message_builder_mock) do
      instance_double(Dependabot::PullRequestCreator::MessageBuilder, message: "Hello World!")
    end

    before do
      allow(job).to receive(:source).and_return(github_source)
      allow(job).to receive(:credentials).and_return(job_credentials)
      allow(job).to receive(:commit_message_options).and_return(commit_message_options)
      allow(Dependabot::PullRequestCreator::MessageBuilder).to receive(:new).and_return(message_builder_mock)
    end

    context "when the change is for a new pull request" do
      before do
        allow(job).to receive(:updating_a_pull_request?).and_return(false)
      end

      it "delegates to the Dependabot::PullRequestCreator::MessageBuilder with the correct configuration" do
        expect(Dependabot::PullRequestCreator::MessageBuilder).
          to receive(:new).with(
            source: github_source,
            files: updated_dependency_files,
            dependencies: dependencies,
            credentials: job_credentials,
            commit_message_options: commit_message_options,
            github_redirection_service: "github-redirect.dependabot.com"
          )

        expect(dependency_change.pr_message).to eql("Hello World!")
      end
    end

    context "when the change is updating an existing pull request" do
      before do
        allow(job).to receive(:updating_a_pull_request?).and_return(true)
      end

      it "it does not invoke Dependabot::PullRequestCreator::MessageBuilder" do
        expect(Dependabot::PullRequestCreator::MessageBuilder).not_to receive(:new)

        expect(dependency_change.pr_message).to be_nil
      end
    end
  end
end
