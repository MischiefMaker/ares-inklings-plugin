require_relative 'spec_helper'

module AresMUSH
  describe "Inklings.submit_inkling" do
    # Regression coverage for v3 Bugs 003/004: both the web "Submit for
    # Review" button and MUSH's +inkling/submit route through this one
    # method, and both broke together when Jobs.create_job started
    # rejecting the configured job_category (see ensure_job). These specs
    # pin the two observable contracts that broke: a job-creation failure
    # must surface its real reason, and must never leave the thread
    # half-submitted.
    let(:submitter) { Fabricate(:character) }
    let(:inkling) do
      Inkling.create(
        kind: "secret",
        title: "Test Inkling",
        status: "open",
        character: submitter,
        creator: submitter,
        created_at: Time.now,
        player_unread: "false",
        locked: "false",
        approval_state: "draft",
        tags: "")
    end

    context "when the linked job is created successfully" do
      let(:job) { double("Job", id: 42, status: "open") }

      before do
        allow(Jobs).to receive(:create_job).and_return({ job: job, error: nil })
      end

      it "returns success with the job" do
        result = Inklings.submit_inkling(inkling, submitter)
        expect(result[:success]).to eq(true)
        expect(result[:job]).to eq(job)
      end

      it "locks the thread and marks it submitted" do
        Inklings.submit_inkling(inkling, submitter)
        expect(inkling.reload.locked).to eq("true")
        expect(inkling.reload.approval_state).to eq("submitted")
      end

      it "leaves a submission marker message referencing the job" do
        Inklings.submit_inkling(inkling, submitter)
        marker = InklingMessage.find(inkling_id: inkling.id).to_a.find { |m| m.message_type == "submitted" }
        expect(marker).not_to be_nil
        expect(marker.text).to include("##{job.id}")
      end
    end

    context "when Jobs.create_job fails (e.g. an unconfigured job category)" do
      before do
        allow(Jobs).to receive(:create_job)
          .and_return({ job: nil, error: "Invalid job category Plots. Valid options are: General." })
      end

      it "returns an error that includes the real underlying reason" do
        result = Inklings.submit_inkling(inkling, submitter)
        expect(result[:error]).to include("Invalid job category Plots")
      end

      it "does not lock the thread or change its approval state" do
        Inklings.submit_inkling(inkling, submitter)
        expect(inkling.reload.locked).to eq("false")
        expect(inkling.reload.approval_state).to eq("draft")
      end

      it "does not leave a submission marker message" do
        Inklings.submit_inkling(inkling, submitter)
        expect(InklingMessage.find(inkling_id: inkling.id).to_a).to be_empty
      end

      it "logs the failure server-side with the inkling and submitter for context" do
        expect(Global.logger).to receive(:error).with(/##{inkling.id}.*#{submitter.name}/)
        Inklings.submit_inkling(inkling, submitter)
      end
    end
  end
end
