module AresMUSH
  module Inklings
    # +inkling/create <kind>=<title>/<text>
    class InklingCreateCmd
      include CommandHandler

      attr_accessor :kind, :title, :text

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.kind = trim_arg(args.arg1).to_s.downcase

        title_and_text = args.arg2.to_s.split("/", 2)
        self.title = trim_arg(title_and_text[0])
        self.text = trim_arg(title_and_text[1])
      end

      # No required_args - the framework's own generic failure message
      # points at "help inkling/create", which doesn't exist as a help
      # topic (the real one is `help inklings`). See check_valid_format.
      def required_args
        []
      end

      def check_valid_format
        return t('dispatcher.invalid_syntax', :cmd => 'inklings') if self.kind.blank? || self.title.blank? || self.text.blank?
        nil
      end

      def check_approved
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if Inklings.chargen_kinds.include?(self.kind)
        return t('inklings.char_not_approved') unless enactor.is_approved?
        nil
      end

      def check_valid_kind
        return nil if Inklings.valid_kind?(self.kind)
        return t('inklings.invalid_kind')
      end

      def check_permission
        return nil if !Inklings.staff_kinds.include?(self.kind)
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
          player_unread: "false",
          locked: "false",
          approval_state: "draft",
          tags: "")

        InklingMessage.create(
          inkling: inkling,
          author: enactor,
          text: self.text,
          created_at: Time.now,
          seq: Inklings.next_event_seq(inkling),
          is_staff: Inklings.can_manage_inklings?(enactor) ? "true" : "false",
          is_private: "false",
          is_gm_note: "false",
          is_personal: "false",
          private_recipient_ids: "")

        notice = t('inklings.thread_started', :id => inkling.id)
        notice << " #{t('inklings.not_yet_submitted_notice', :id => inkling.id)}" unless Inklings.can_manage_inklings?(enactor)
        client.emit_success notice
        warning = Inklings.staff_target_warning(enactor, inkling.id) if Inklings.can_manage_inklings?(enactor)
        client.emit warning if warning
      end
    end
  end
end
