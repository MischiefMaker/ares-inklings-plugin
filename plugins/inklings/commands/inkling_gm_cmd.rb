module AresMUSH
  module Inklings
    # +inkling/gm <id>=<text>
    class InklingGmCmd
      include CommandHandler

      attr_accessor :id, :text

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.id = args.arg1
        self.text = trim_arg(args.arg2)
      end

      def required_args
        [self.id, self.text]
      end

      def check_valid_inkling
        return t('inklings.invalid_id') if !Inklings.find_inkling(self.id)
        nil
      end

      def check_permission
        return nil if Inklings.can_manage_inklings?(enactor)
        t('dispatcher.not_allowed')
      end

      def check_not_closed
        inkling = Inklings.find_inkling(self.id)
        return t('inklings.thread_is_closed') if inkling.status == "closed"
        nil
      end

      def handle
        inkling = Inklings.find_inkling(self.id)

        InklingMessage.create(
          inkling: inkling,
          author: enactor,
          text: self.text,
          created_at: Time.now,
          is_staff: "true",
          is_private: "false",
          is_gm_note: "true",
          private_recipient_ids: "")

        Inklings.mirror_to_job(inkling, "[GM] #{self.text}", enactor, true)
        client.emit_success t('inklings.gm_note_added')
      end
    end
  end
end
