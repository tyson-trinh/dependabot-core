# typed: true
# frozen_string_literal: true

require "spec_helper"
require "dependabot/source"
require "dependabot/nuget/file_parser"
require "dependabot/nuget/file_updater"
require "dependabot/nuget/version"
require_relative "github_helpers"
require_relative "nuget_search_stubs"
require "json"
require_common_spec "file_updaters/shared_examples_for_file_updaters"

RSpec.describe Dependabot::Nuget::FileUpdater do
  RSpec.configure do |config|
    config.include(NuGetSearchStubs)
  end

  let(:repo_contents_path) { nuget_build_tmp_repo(project_name) }
  let(:previous_requirements) do
    [{ file: "dirs.proj", requirement: "1.0.0", groups: [], source: nil }]
  end
  let(:requirements) do
    [{ file: "dirs.proj", requirement: "1.1.1", groups: [], source: nil }]
  end
  let(:dependency_previous_version) { "1.0.0" }
  let(:dependency_version) { "1.1.1" }
  let(:dependency_name) { "Microsoft.Extensions.DependencyModel" }
  let(:dependency) do
    Dependabot::Dependency.new(
      name: dependency_name,
      version: dependency_version,
      previous_version: dependency_previous_version,
      requirements: requirements,
      previous_requirements: previous_requirements,
      package_manager: "nuget"
    )
  end
  # project_dependency files comes back with directory files first, we need the closest project at the top
  let(:dependency_files) { nuget_project_dependency_files(project_name, directory: directory).reverse }
  let(:directory) { "/" }
  let(:project_name) { "file_updater_dirsproj" }
  let(:dependencies) { [dependency] }
  let(:source) do
    Dependabot::Source.new(
      provider: "github",
      repo: "gocardless/bump",
      directory: "/"
    )
  end
  let(:file_updater_instance) do
    Dependabot::Nuget::FileParser.new(dependency_files: dependency_files,
                                      source: source,
                                      repo_contents_path: repo_contents_path).parse
    described_class.new(
      dependency_files: dependency_files,
      dependencies: dependencies,
      credentials: [{
        "type" => "git_source",
        "host" => "github.com"
      }],
      repo_contents_path: repo_contents_path
    )
  end

  before do
    stub_search_results_with_versions_v3("microsoft.extensions.dependencymodel", ["1.0.0", "1.1.1"])
    stub_request(:get, "https://api.nuget.org/v3-flatcontainer/" \
                       "microsoft.extensions.dependencymodel/1.0.0/" \
                       "microsoft.extensions.dependencymodel.nuspec")
      .to_return(status: 200, body: fixture("nuspecs", "Microsoft.Extensions.DependencyModel.1.0.0.nuspec"))
  end

  it_behaves_like "a dependency file updater"

  describe "#updated_dependency_files" do
    subject(:updated_files) { file_updater_instance.updated_dependency_files }

    context "with a dirs.proj" do
      it "does not repeatedly update the same project" do
        puts dependency_files.map(&:name)
        expect(updated_files.map(&:name)).to contain_exactly("Proj1/Proj1/Proj1.csproj")

        expect(file_updater_instance.send(:testonly_update_tooling_calls)).to eq(
          {
            "#{repo_contents_path}/Proj1/Proj1/Proj1.csprojMicrosoft.Extensions.DependencyModel" => 1
          }
        )
      end

      context "when the file has only deleted lines" do
        before do
          allow(File).to receive(:read)
            .and_call_original
          allow(File).to receive(:read)
            .with("#{repo_contents_path}/Proj1/Proj1/Proj1.csproj")
            .and_return("")
        end

        it "does not update the project" do
          expect(updated_files.map(&:name)).to be_empty
        end
      end
    end
  end

  describe "#updated_dependency_files_with_wildcard" do
    subject(:updated_files) { file_updater_instance.updated_dependency_files }

    let(:project_name) { "file_updater_dirsproj_wildcards" }
    let(:dependency_files) { nuget_project_dependency_files(project_name, directory: directory).reverse }
    let(:dependency_name) { "Microsoft.Extensions.DependencyModel" }
    let(:dependency_version) { "1.1.1" }
    let(:dependency_previous_version) { "1.0.0" }

    it "updates the wildcard project" do
      expect(updated_files.map(&:name)).to contain_exactly("Proj1/Proj1/Proj1.csproj", "Proj2/Proj2.csproj")

      expect(file_updater_instance.send(:testonly_update_tooling_calls)).to eq(
        {
          "#{repo_contents_path}/Proj1/Proj1/Proj1.csprojMicrosoft.Extensions.DependencyModel" => 1,
          "#{repo_contents_path}/Proj2/Proj2.csprojMicrosoft.Extensions.DependencyModel" => 1
        }
      )
    end
  end
end
