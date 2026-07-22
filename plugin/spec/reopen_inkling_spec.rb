require_relative 'spec_helper'

module AresMUSH
  describe "Inklings.reopen_inkling" do
    # Regression coverage for v5 Bug 002: reopening a closed inkling.
    # Both InklingReopenCmd (MUSH) and InklingApi.reopen_inkling (web)
    # call this one canonical service.
    let(:staff) { Fabricate(:character) }
    let(:owner) { Fabricate(:character) }
    let(:job) { Fabricate(:job) }
    let(:inkling) do
      Inkling.create(
        kind: "secret",
        title: "Test Inkling",
        status: "closed",
        character: owner,
        creator: owner,
        created_at: Time.now,
        player_unread: "false",
        locked: "false",
        approval_state: "approved",
        tags: "",
        job: job)
    end

    before do
      allow(Jobs).to receive(:closed_statuses).and_return(["closed"])
      allow(Jobs).to receive(:change_job_status) do |_enactor, target_job, status, message|
        JobReply.create(job: target_job, author: staff, message: message, admin_only: "false")
        target_job.update(status: status)
      end
      allow(Jobs).to receive(:comment) do |target_job, author, message, admin_only|
        JobReply.create(job: target_job, author: author, message: message, admin_only: admin_only.to_s)
      end
      job.update(status: "closed")
    end

    it "restores the inkling's status to open" do
      Inklings.reopen_inkling(inkling, staff)
      expect(inkling.reload.status).to eq("open")
    end

    it "does not touch locked or approval_state" do
      Inklings.reopen_inkling(inkling, staff)
      expect(inkling.reload.locked).to eq("false")
      expect(inkling.reload.approval_state).to eq("approved")
    end

    it "adds exactly one reopen audit entry" do
      Inklings.reopen_inkling(inkling, staff)
      reopened_messages = InklingMessage.find(inkling_id: inkling.id).to_a.select { |m| m.message_type == "reopened" }
      expect(reopened_messages.length).to eq(1)
      expect(reopened_messages.first.text).to include(staff.name)
    end

    it "does not delete or alter prior messages" do
      InklingMessage.create(
        inkling: inkling, author: owner, text: "Earlier note", created_at: Time.now,
        seq: Inklings.next_event_seq(inkling), is_staff: "false", is_private: "false",
        is_gm_note: "false", is_personal: "false", private_recipient_ids: "")

      Inklings.reopen_inkling(inkling, staff)

      expect(InklingMessage.find(inkling_id: inkling.id).to_a.map(&:text)).to include("Earlier note")
    end

    context "when the linked job is closed" do
      it "reopens the same job rather than creating a new one" do
        original_job_id = inkling.job.id
        Inklings.reopen_inkling(inkling, staff)

        expect(inkling.reload.job.id).to eq(original_job_id)
        expect(inkling.reload.job.status).not_to eq("closed")
      end

      it "does not create a duplicate mirrored reply when the inkling is later viewed" do
        Inklings.reopen_inkling(inkling, staff)
        Inklings.sync_job_replies(inkling)

        expect(InklingMessage.find(inkling_id: inkling.id).to_a.length).to eq(1)
      end
    end

    context "when no default job status is configured" do
      before do
        allow(Global).to receive(:read_config).and_call_original
        allow(Global).to receive(:read_config).with("jobs", "default_status").and_return(nil)
      end

      it "still reopens the inkling and logs a diagnostic instead of guessing a job status" do
        expect(Global.logger).to receive(:error).with(/default_status/)
        Inklings.reopen_inkling(inkling, staff)
        expect(inkling.reload.status).to eq("open")
      end

      it "does not create a duplicate mirrored reply for the diagnostic job comment either" do
        allow(Global.logger).to receive(:error)
        Inklings.reopen_inkling(inkling, staff)
        Inklings.sync_job_replies(inkling)

        expect(InklingMessage.find(inkling_id: inkling.id).to_a.length).to eq(1)
      end
    end
  end
end
