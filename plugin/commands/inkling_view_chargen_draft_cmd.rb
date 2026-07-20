module AresMUSH
  module Inklings
    # +inkling/view-secret
    # +inkling/view-goal
    #
    # View the current chargen draft for secret or goal (unapproved characters only).
    # Pre-approval, these show the draft text saved via +inkling/secret or +inkling/goal.
    # Post-approval, the drafts are converted to real Inklings, so this command becomes
    # unavailable (the kind is no longer in chargen_required_types).
    class InklingViewChargenDraftCmd
      include CommandHandler

      attr_accessor :kind

      def parse_args
        self.kind = cmd.switch
      end

      def check_chargen_only
        return nil unless enactor.is_approved?
        return t('inklings.chargen_draft_already_approved')
      end

      def check_valid_kind
        return nil if Inklings.chargen_required_types.include?(self.kind)
        return t('inklings.chargen_draft_unavailable')
      end

      def check_draft_exists
        title = enactor.respond_to?("inkling_#{self.kind}_title") ? enactor.send("inkling_#{self.kind}_title") : nil
        text = enactor.respond_to?("inkling_#{self.kind}_text") ? enactor.send("inkling_#{self.kind}_text") : nil
        return nil if title.present? || text.present?
        label = Inklings.kind_label(self.kind)
        return t('inklings.no_chargen_draft', :label => label.downcase)
      end

      def handle
        title = enactor.respond_to?("inkling_#{self.kind}_title") ? enactor.send("inkling_#{self.kind}_title") : nil
        text = enactor.respond_to?("inkling_#{self.kind}_text") ? enactor.send("inkling_#{self.kind}_text") : nil

        separator = "-" * 60
        label = Inklings.kind_label(self.kind)
        header_title = title.to_s.blank? ? label : title
        title_line = "%xh#{Inklings.color_title(header_title)} %xh%cy(DRAFT)%xn"

        content = text.to_s.blank? ? "(no content)" : text.to_s
        body = content

        template = BorderedDisplayTemplate.new body, title_line
        client.emit template.render
      end
    end
  end
end
