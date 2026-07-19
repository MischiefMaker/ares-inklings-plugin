module AresMUSH
  module Inklings
    # +inkling/secret <title>/<text>
    # +inkling/goal <title>/<text>
    #
    # The MUSH-side equivalent of the web chargen "Secret & Goal" tab, for
    # players who prefer typing commands over the web portal. Only reachable
    # pre-approval, for the chargen-required kinds themselves, with no
    # target - see the routing in Inklings.get_cmd_handler. Writes the same
    # draft attributes the web form writes (char.inkling_<kind>_title/text -
    # see plugin/models/character_inkling_fields.rb), NOT a real Inkling.
    # Running it again before approval overwrites the previous draft, same
    # as re-submitting the web form. On approval, Inklings.character_approved
    # converts each populated draft into a real Inkling and clears it.
    #
    # Once a character is approved, this command is no longer reachable for
    # that kind - +inkling/secret and +inkling/goal then behave like any
    # other shared-kind command and go through InklingStartCmd, creating a
    # real Inkling immediately.
    class InklingChargenDraftCmd
      include CommandHandler

      attr_accessor :kind, :title, :text

      def parse_args
        self.kind = cmd.switch

        title_and_text = cmd.args.to_s.split("/", 2)
        self.title = trim_arg(title_and_text[0])
        self.text = trim_arg(title_and_text[1])
      end

      def required_args
        [self.title, self.text]
      end

      def check_valid_kind
        return nil if Inklings.chargen_required_types.include?(self.kind)
        return t('inklings.chargen_draft_unavailable')
      end

      def handle
        enactor.update(
          "inkling_#{self.kind}_title".to_sym => self.title,
          "inkling_#{self.kind}_text".to_sym => self.text)

        label = Inklings.kind_label(self.kind)
        client.emit_success t('inklings.chargen_draft_saved', :label => label)
      end
    end
  end
end
