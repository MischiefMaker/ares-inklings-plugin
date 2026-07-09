module AresMUSH
  module Inklings
    # +inkling/new <kind>=<title>/<text>
    class InklingNewCmd
      include CommandHandler

      attr_accessor :kind, :title, :text

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.kind = trim_arg(args.arg1).to_s.downcase

        title_and_text = args.arg2.to_s.split("/", 2)
        self.title = trim_arg(title_and_text[0])
        self.text = trim_arg(title_and_text[1])
      end

      def required_args
        [self.kind, self.title, self.text]
      end

      def check_approved
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if Inklings::CHARGEN_KINDS.include?(self.kind)
        return t('inklings.char_not_approved') unless enactor.is_approved?
        nil
      end

      def check_valid_kind
        return nil if Inklings::ALL_KINDS.include?(self.kind)
        return t('inklings.invalid_kind')
      end

      def check_permission
        return nil if !Inklings::STAFF_KINDS.include?(self.kind)
        return nil if Inklings.can_manage_inklings?(enactor)
        return t('dispatcher.not_allowed')
      end

      def handle
        inkling = Inkling.create(
          kind: self.kind,
          title: self.title,
          status: "open",
          character: enactor,
          creator: enactor,
          created_at: Time.now,
          player_unread: "false")

        InklingMessage.create(
          inkling: inkling,
          author: enactor,
          text: self.text,
          created_at: Time.now,
          is_staff: Inklings.can_manage_inklings?(enactor) ? "true" : "false",
          is_private: "false",
          is_gm_note: "false")

        if !Inklings.can_manage_inklings?(enactor)
          Inklings.ensure_job(inkling,
            "#{enactor.name} - #{self.title}",
            self.text,
            enactor)
        end

        client.emit_success t('inklings.thread_started', :id => inkling.id)
      end
    end
  end
end
