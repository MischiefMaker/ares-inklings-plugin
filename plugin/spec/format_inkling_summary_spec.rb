require_relative 'spec_helper'

module AresMUSH
  describe "Inklings::InklingApi.format_inkling_summary" do
    # Regression coverage for v4 Bug 003: the web modal's staff review
    # controls (Approve/Needs Changes), its "Request Unlock" button, and
    # staff's own "Unlock" button all gate on this.detail.approval_state -
    # a field format_inkling_summary silently never included. Since a
    # missing/undefined value in a Handlebars {{#if (eq ...)}} just
    # renders nothing (no error, no console warning - see Lesson 24), the
    # controls looked entirely absent rather than broken. This pins the
    # field's presence so that regression can't silently recur, and
    # format_inkling_detail (which merges on top of this) inherits the
    # same coverage since it delegates here.
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
        locked: "true",
        approval_state: "submitted",
        tags: "")
    end

    it "includes the inkling's real approval_state" do
      summary = Inklings::InklingApi.format_inkling_summary(inkling, staff)
      expect(summary[:approval_state]).to eq("submitted")
    end

    it "reflects a changed approval_state after update" do
      inkling.update(approval_state: "approved", locked: "false")
      summary = Inklings::InklingApi.format_inkling_summary(inkling, staff)
      expect(summary[:approval_state]).to eq("approved")
    end

    it "is also present on the merged detail payload used by the web modal" do
      detail = Inklings::InklingApi.format_inkling_detail(inkling, staff)
      expect(detail[:approval_state]).to eq("submitted")
    end
  end
end
