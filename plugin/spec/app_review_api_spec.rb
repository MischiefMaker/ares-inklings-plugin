require_relative 'spec_helper'

module AresMUSH
  describe Inklings::AppReviewApi do
    let(:char) { Fabricate(:character) }

    describe "app_review_lines" do
      context "chargen disabled" do
        before { allow(Inklings).to receive(:chargen_enabled?).and_return(false) }

        it "returns empty array when chargen is disabled" do
          result = Inklings::AppReviewApi.app_review_lines(char)
          expect(result).to eq([])
        end
      end

      context "no required types" do
        before do
          allow(Inklings).to receive(:chargen_enabled?).and_return(true)
          allow(Inklings).to receive(:chargen_required_types).and_return([])
        end

        it "returns empty array when there are no chargen types" do
          result = Inklings::AppReviewApi.app_review_lines(char)
          expect(result).to eq([])
        end
      end

      context "chargen enabled, all fields filled" do
        before do
          allow(Inklings).to receive(:chargen_enabled?).and_return(true)
          allow(Inklings).to receive(:chargen_required_types).and_return(["secret", "goal"])
          allow(Global).to receive(:read_config).with("inklings", "chargen_required").and_return(true)
          char.update(inkling_secret_text: "My secret")
          char.update(inkling_goal_text: "My goal")
          allow(Inklings).to receive(:kind_label).with("secret").and_return("Secret")
          allow(Inklings).to receive(:kind_label).with("goal").and_return("Goal")
        end

        it "returns empty array when all required fields are complete" do
          result = Inklings::AppReviewApi.app_review_lines(char)
          expect(result).to eq([])
        end
      end

      context "chargen required, secret missing" do
        before do
          allow(Inklings).to receive(:chargen_enabled?).and_return(true)
          allow(Inklings).to receive(:chargen_required_types).and_return(["secret", "goal"])
          allow(Global).to receive(:read_config).with("inklings", "chargen_required").and_return(true)
          char.update(inkling_secret_text: nil)
          char.update(inkling_goal_text: "My goal")
          allow(Inklings).to receive(:kind_label).with("secret").and_return("Secret")
          allow(Inklings).to receive(:kind_label).with("goal").and_return("Goal")
          allow(Chargen).to receive(:format_review_status) { |severity, msg| "#{severity}: #{msg}" }
        end

        it "returns red error when required field is blank" do
          result = Inklings::AppReviewApi.app_review_lines(char)
          expect(result).not_to be_empty
          expect(result[0]).to include("error:")
        end
      end

      context "chargen optional, secret missing" do
        before do
          allow(Inklings).to receive(:chargen_enabled?).and_return(true)
          allow(Inklings).to receive(:chargen_required_types).and_return(["secret", "goal"])
          allow(Global).to receive(:read_config).with("inklings", "chargen_required").and_return(false)
          char.update(inkling_secret_text: "")
          char.update(inkling_goal_text: "My goal")
          allow(Inklings).to receive(:kind_label).with("secret").and_return("Secret")
          allow(Inklings).to receive(:kind_label).with("goal").and_return("Goal")
          allow(Chargen).to receive(:format_review_status) { |severity, msg| "#{severity}: #{msg}" }
        end

        it "returns yellow warning when optional field is blank" do
          result = Inklings::AppReviewApi.app_review_lines(char)
          expect(result).not_to be_empty
          expect(result[0]).to include("warning:")
        end
      end

      context "both fields missing, required" do
        before do
          allow(Inklings).to receive(:chargen_enabled?).and_return(true)
          allow(Inklings).to receive(:chargen_required_types).and_return(["secret", "goal"])
          allow(Global).to receive(:read_config).with("inklings", "chargen_required").and_return(true)
          char.update(inkling_secret_text: nil)
          char.update(inkling_goal_text: nil)
          allow(Inklings).to receive(:kind_label).with("secret").and_return("Secret")
          allow(Inklings).to receive(:kind_label).with("goal").and_return("Goal")
          allow(Chargen).to receive(:format_review_status) { |severity, msg| "#{severity}: #{msg}" }
        end

        it "returns single error line for multiple missing fields" do
          result = Inklings::AppReviewApi.app_review_lines(char)
          expect(result.length).to eq(1)
          expect(result[0]).to include("error:")
          expect(result[0]).to include("Secret")
          expect(result[0]).to include("Goal")
        end
      end

      context "whitespace-only text" do
        before do
          allow(Inklings).to receive(:chargen_enabled?).and_return(true)
          allow(Inklings).to receive(:chargen_required_types).and_return(["secret", "goal"])
          allow(Global).to receive(:read_config).with("inklings", "chargen_required").and_return(true)
          char.update(inkling_secret_text: "   ")
          char.update(inkling_goal_text: "My goal")
          allow(Inklings).to receive(:kind_label).with("secret").and_return("Secret")
          allow(Inklings).to receive(:kind_label).with("goal").and_return("Goal")
          allow(Chargen).to receive(:format_review_status) { |severity, msg| "#{severity}: #{msg}" }
        end

        it "treats whitespace-only as missing" do
          result = Inklings::AppReviewApi.app_review_lines(char)
          expect(result).not_to be_empty
          expect(result[0]).to include("error:")
        end
      end

      context "missing custom field declarations" do
        before do
          allow(Inklings).to receive(:chargen_enabled?).and_return(true)
          allow(Inklings).to receive(:chargen_required_types).and_return(["secret", "goal"])
          allow(Global).to receive(:read_config).with("inklings", "chargen_required").and_return(true)
          allow(char).to receive(:respond_to?).with("inkling_secret_text").and_return(false)
          allow(char).to receive(:respond_to?).with("inkling_goal_text").and_return(true)
          char.update(inkling_goal_text: "My goal")
          allow(Inklings).to receive(:kind_label).with("goal").and_return("Goal")
          allow(Chargen).to receive(:format_review_status) { |severity, msg| "#{severity}: #{msg}" }
        end

        it "skips fields with missing respond_to declarations" do
          result = Inklings::AppReviewApi.app_review_lines(char)
          # Should only check goal, secret declaration is missing
          expect(result).to eq([])
        end
      end
    end
  end
end
