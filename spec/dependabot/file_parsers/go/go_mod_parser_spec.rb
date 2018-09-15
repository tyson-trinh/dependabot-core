# frozen_string_literal: true

require "dependabot/dependency_file"
require "dependabot/file_parsers/go/go_mod_parser"
require_relative "../shared_examples_for_file_parsers"

RSpec.describe Dependabot::FileParsers::Go::GoModParser do
  let(:parser) { described_class.new(dependency_files: files) }

  let(:files) { [go_mod] }
  let(:go_mod) do
    Dependabot::DependencyFile.new(
      name: "go.mod",
      content: fixture("go", "go_mods", go_mod_fixture_name)
    )
  end
  let(:go_mod_fixture_name) { "go.mod" }

  describe "dependency_set" do
    subject(:dependencies) { parser.dependency_set.dependencies }

    its(:length) { is_expected.to eq(5) }

    describe "top level dependencies" do
      subject(:dependencies) { parser.dependency_set.dependencies.select(&:top_level?) }

      its(:length) { is_expected.to eq(2) }

      describe "a dependency that uses go modules" do
        subject(:dependency) do
          dependencies.find { |d| d.name == "rsc.io/quote" }
        end

        it "has the right details" do
          expect(dependency).to be_a(Dependabot::Dependency)
          expect(dependency.name).to eq("rsc.io/quote")
          expect(dependency.version).to eq("v1.4.0")
          expect(dependency.requirements).to eq(
            [{
              requirement: "v1.4.0",
              file: "go.mod",
              groups: [],
              source: {
                type: "default",
                source: "rsc.io/quote"
              }
            }]
          )
        end
      end

      describe "a dependency that doesn't use go modules" do
        subject(:dependency) do
          dependencies.find { |d| d.name == "github.com/fatih/color" }
        end

        it "has the right details" do
          expect(dependency).to be_a(Dependabot::Dependency)
          expect(dependency.name).to eq("github.com/fatih/color")
          expect(dependency.version).to eq("v1.7.0")
          expect(dependency.requirements).to eq(
            [{
              requirement: "v1.7.0",
              file: "go.mod",
              groups: [],
              source: {
                type: "default",
                source: "github.com/fatih/color"
              }
            }]
          )
        end
      end
    end
  end
end
