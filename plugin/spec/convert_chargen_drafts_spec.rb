require_relative 'spec_helper'

module AresMUSH
  describe "Inklings.convert_chargen_drafts" do
    let(:char) { Fabricate(:character, is_approved: true) }

    describe "with chargen disabled" do
      before { allow(Inklings).to receive(:chargen_enabled?).and_return(false) }

      it "does nothing when chargen is disabled" do
        char.update(inkling_secret_text: "My secret")
        char.update(inkling_goal_text: "My goal")

        expect(Inkling).not_to receive(:create)
        Inklings.convert_chargen_drafts(char)
      end
    end

    describe "with chargen enabled" do
      before do
        allow(Inklings).to receive(:chargen_enabled?).and_return(true)
        allow(Inklings).to receive(:chargen_required_types).and_return(["secret", "goal"])
      end

      context "single populated field" do
        before do
          char.update(inkling_secret_title: "My Secret", inkling_secret_text: "This is my secret")
          char.update(inkling_goal_title: nil, inkling_goal_text: nil)
        end

        it "creates inkling for populated secret field" do
          expect(Inklings::InklingApi).to receive(:create_inkling)
            .with(char.id, char, "secret", "This is my secret", "My Secret")
            .and_return({})  # Success (no error key)

          Inklings.convert_chargen_drafts(char)
        end

        it "clears draft fields after successful creation" do
          allow(Inklings::InklingApi).to receive(:create_inkling).and_return({})
          Inklings.convert_chargen_drafts(char)

          expect(char.reload.inkling_secret_title).to be_nil
          expect(char.reload.inkling_secret_text).to be_nil
        end
      end

      context "both fields populated" do
        before do
          char.update(inkling_secret_title: "Secret", inkling_secret_text: "Secret text")
          char.update(inkling_goal_title: "Goal", inkling_goal_text: "Goal text")
        end

        it "creates inklings for both populated fields" do
          expect(Inklings::InklingApi).to receive(:create_inkling)
            .with(char.id, char, "secret", "Secret text", "Secret")
            .and_return({})

          expect(Inklings::InklingApi).to receive(:create_inkling)
            .with(char.id, char, "goal", "Goal text", "Goal")
            .and_return({})

          Inklings.convert_chargen_drafts(char)
        end

        it "creates two inklings when both fields are populated" do
          allow(Inklings::InklingApi).to receive(:create_inkling).and_return({})
          allow(Inkling).to receive(:create).and_return(double(id: 1))

          Inklings.convert_chargen_drafts(char)

          expect(Inklings::InklingApi).to have_received(:create_inkling).twice
        end
      end

      context "blank and whitespace-only fields" do
        before do
          char.update(inkling_secret_title: nil, inkling_secret_text: "")
          char.update(inkling_goal_title: "   ", inkling_goal_text: nil)
        end

        it "skips blank fields" do
          expect(Inklings::InklingApi).not_to receive(:create_inkling)
          Inklings.convert_chargen_drafts(char)
        end
      end

      context "mixed populated and blank" do
        before do
          char.update(inkling_secret_title: "Secret", inkling_secret_text: "Secret text")
          char.update(inkling_goal_title: nil, inkling_goal_text: "")
        end

        it "creates only for populated fields" do
          expect(Inklings::InklingApi).to receive(:create_inkling)
            .with(char.id, char, "secret", "Secret text", "Secret")
            .and_return({})

          expect(Inklings::InklingApi).not_to receive(:create_inkling)
            .with(char.id, char, "goal", anything, anything)

          Inklings.convert_chargen_drafts(char)
        end
      end

      context "API error handling" do
        before do
          char.update(inkling_secret_title: "Secret", inkling_secret_text: "Secret text")
          char.update(inkling_goal_title: "Goal", inkling_goal_text: "Goal text")
        end

        it "logs error and preserves draft when creation fails" do
          # Secret creation fails with API error
          allow(Inklings::InklingApi).to receive(:create_inkling) do |char_id, viewer, kind, *|
            kind == "secret" ? { error: "Invalid kind" } : {}
          end

          expect(AresMUSH::Coder).to receive(:log_error)
            .with(/Error creating chargen inkling/, anything)

          Inklings.convert_chargen_drafts(char)

          # Secret draft should be preserved since creation failed
          expect(char.reload.inkling_secret_title).to eq("Secret")
          expect(char.reload.inkling_secret_text).to eq("Secret text")

          # Goal draft should be cleared since creation succeeded
          expect(char.reload.inkling_goal_title).to be_nil
          expect(char.reload.inkling_goal_text).to be_nil
        end

        it "does not clear draft if API returns error" do
          allow(Inklings::InklingApi).to receive(:create_inkling)
            .and_return({ error: "Character not found" })

          expect(AresMUSH::Coder).to receive(:log_error)

          Inklings.convert_chargen_drafts(char)

          # Draft should be preserved
          expect(char.reload.inkling_secret_title).to eq("My Secret")
          expect(char.reload.inkling_secret_text).to eq("Secret text")
        end
      end

      context "exception handling" do
        before do
          char.update(inkling_secret_title: "Secret", inkling_secret_text: "Secret text")
        end

        it "logs exception and preserves draft on rescue" do
          allow(Inklings::InklingApi).to receive(:create_inkling)
            .and_raise(StandardError.new("DB error"))

          expect(AresMUSH::Coder).to receive(:log_error)
            .with(/Exception creating chargen inkling/, anything)

          Inklings.convert_chargen_drafts(char)

          # Draft should be preserved after exception
          expect(char.reload.inkling_secret_title).to eq("Secret")
          expect(char.reload.inkling_secret_text).to eq("Secret text")
        end
      end

      context "idempotency" do
        before do
          char.update(inkling_secret_title: "Secret", inkling_secret_text: "Secret text")
          char.update(inkling_goal_title: "Goal", inkling_goal_text: "Goal text")
        end

        it "does not create duplicates on second run" do
          allow(Inklings::InklingApi).to receive(:create_inkling).and_return({})

          # First run
          Inklings.convert_chargen_drafts(char)

          # Second run - drafts are now empty
          expect(Inklings::InklingApi).not_to receive(:create_inkling)
          Inklings.convert_chargen_drafts(char)
        end
      end

      context "missing character attribute declarations" do
        before do
          allow(char).to receive(:respond_to?).with("inkling_secret_title").and_return(false)
          allow(char).to receive(:respond_to?).with("inkling_goal_title").and_return(true)
          char.update(inkling_goal_title: "Goal", inkling_goal_text: "Goal text")
        end

        it "skips fields with missing respond_to declarations" do
          expect(Inklings::InklingApi).to receive(:create_inkling)
            .with(char.id, char, "goal", "Goal text", "Goal")
            .and_return({})

          expect(Inklings::InklingApi).not_to receive(:create_inkling)
            .with(anything, anything, "secret", anything, anything)

          Inklings.convert_chargen_drafts(char)
        end
      end

      context "nil character" do
        it "returns early if character is nil" do
          expect(Inklings::InklingApi).not_to receive(:create_inkling)
          Inklings.convert_chargen_drafts(nil)
        end
      end
    end
  end
end
