require_relative 'spec_helper'

module AresMUSH
  describe "Inklings::InklingApi.format_message" do
    # Regression coverage discovered while wiring up the REOPENED badge
    # for v5 Bug 002: format_message never included message_type in its
    # output at all, so the SUBMITTED/APPROVED/NEEDS CHANGES/REWARD
    # badges (and now REOPENED) in the web modal have silently never
    # rendered - same missing-serialized-field failure shape as the
    # approval_state bug fixed in v4 Bug 003 (see Lesson 28).
    let(:staff) { Fabricate(:character) }
    let(:owner) { Fabricate(:character) }
    let(:inkling) do
      Inkling.create(
        kind: "secret",
        title: "Test Inkling",
        status: "open",
        character: owner,
        creator: owner,
        created_at: Time.now,
        player_unread: "false",
        locked: "false",
        approval_state: "approved",
        tags: "")
    end

    it "includes the message's real message_type" do
      message = InklingMessage.create(
        inkling: inkling, author: staff, text: "Approved.", created_at: Time.now,
        seq: Inklings.next_event_seq(inkling), is_staff: "true", is_private: "false",
        is_gm_note: "false", message_type: "approved")

      formatted = Inklings::InklingApi.format_message(message)
      expect(formatted[:message_type]).to eq("approved")
    end

    it "is nil (not omitted) for an ordinary reply with no special type" do
      message = InklingMessage.create(
        inkling: inkling, author: staff, text: "Just a reply.", created_at: Time.now,
        seq: Inklings.next_event_seq(inkling), is_staff: "true", is_private: "false",
        is_gm_note: "false")

      formatted = Inklings::InklingApi.format_message(message)
      expect(formatted).to have_key(:message_type)
      expect(formatted[:message_type]).to be_nil
    end
  end
end
