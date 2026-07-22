require_relative 'spec_helper'

module AresMUSH
  describe "Inklings.approve_inkling" do
    # Regression coverage for v5 Bug 001: approving with a comment showed
    # the same text twice - once as the canonical [Approved] entry, once
    # again as a generic [staff] reply. Root cause: Jobs.close_job posts
    # the close message as a JobReply (a job comment) as a side effect,
    # and sync_job_replies (called whenever the inkling is viewed) mirrors
    # any not-yet-mirrored JobReply into the thread as a new message. The
    # fix links the JobReply Jobs.close_job just created to the approval
    # message already made, so sync_job_replies' own dedup check
    # (InklingMessage.find(source_job_reply_id:)) skips it.
    let(:staff) { Fabricate(:character) }
    let(:owner) { Fabricate(:character) }
    let(:job) { Fabricate(:job) }
    let(:inkling) do
      Inkling.create(
        kind: "secret",
        title: "Test Inkling",
        status: "open",
        character: owner,
        creator: owner,
        created_at: Time.now,
        player_unread: "false",
        locked: "true",
        approval_state: "submitted",
        tags: "",
        job: job)
    end

    before do
      # Simulate Jobs.close_job's real side effect (confirmed against
      # AresMUSH core source: it posts the message as a JobReply via
      # Jobs.comment) without depending on the real Jobs plugin being
      # loaded in this spec environment.
      allow(Jobs).to receive(:close_job) do |_enactor, target_job, message|
        JobReply.create(job: target_job, author: staff, message: message, admin_only: "false")
        target_job.update(status: "closed")
      end
    end

    context "with a comment" do
      it "creates exactly one InklingMessage for the approval" do
        Inklings.approve_inkling(inkling, staff, "Okay.")
        approved_messages = InklingMessage.find(inkling_id: inkling.id).to_a.select { |m| m.message_type == "approved" }
        expect(approved_messages.length).to eq(1)
        expect(approved_messages.first.text).to eq("Okay.")
      end

      it "does not leave the job's mirrored comment as a second, unlinked message" do
        Inklings.approve_inkling(inkling, staff, "Okay.")
        # Simulate the inkling being viewed again, which is what actually
        # created the duplicate before the fix.
        Inklings.sync_job_replies(inkling)

        expect(InklingMessage.find(inkling_id: inkling.id).to_a.length).to eq(1)
      end

      it "leaves no generic (non-approved) staff message behind" do
        Inklings.approve_inkling(inkling, staff, "Okay.")
        Inklings.sync_job_replies(inkling)

        generic_staff_messages = InklingMessage.find(inkling_id: inkling.id).to_a.reject { |m| m.message_type == "approved" }
        expect(generic_staff_messages).to be_empty
      end
    end

    context "without a comment" do
      it "creates exactly one system approval message and no duplicate on later view" do
        Inklings.approve_inkling(inkling, staff, nil)
        Inklings.sync_job_replies(inkling)

        expect(InklingMessage.find(inkling_id: inkling.id).to_a.length).to eq(1)
      end
    end

    it "updates the inkling's status and approval_state exactly once" do
      Inklings.approve_inkling(inkling, staff, "Okay.")
      expect(inkling.reload.approval_state).to eq("approved")
      expect(inkling.reload.locked).to eq("false")
    end
  end
end
