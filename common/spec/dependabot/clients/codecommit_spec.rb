# frozen_string_literal: true

require "aws-sdk-codecommit"
require "spec_helper"
require "dependabot/clients/codecommit"

RSpec.describe Dependabot::Clients::CodeCommit do
  let(:branch) { "master" }
  let(:repo) { "gocardless" }
  let(:credentials) do
    [{
      "type" => "git_source",
      "region" => "us-east-1",
      "username" => "AWS_ACCESS_KEY_ID",
      "password" => "AWS_SECRET_ACCESS_KEY"
    }]
  end
  let(:source) { Dependabot::Source.from_url("codecommit") }
  let(:client) do
    described_class.for_source(source: source, credentials: credentials)
  end

  describe "#fetch_commit" do
    subject { client.fetch_commit(nil, branch) }

    context "when a response is returned" do
      before do
        client.
          stub_responses(
            :get_branch,
            branch:
              {
                branch_name: "master",
                commit_id: "9c8376e9b2e943c2c72fac4b239876f377f0305a"
              }
          )
      end

      specify { expect { subject }.to_not raise_error }

      it { is_expected.to eq("9c8376e9b2e943c2c72fac4b239876f377f0305a") }
    end

    context "when the target branch does not exist" do
      before do
        client.stub_responses(:get_branch, "BranchDoesNotExistException")
      end

      it "raises a helpful error" do
        expect { subject }.to raise_error(
          Aws::CodeCommit::Errors::BranchDoesNotExistException
        )
      end
    end
  end
end
