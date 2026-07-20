module AresMUSH
  module Inklings
    # A title is now mandatory for every kind (matching +inkling/new's
    # "<title>/<text>" syntax) - rolls are the only exception, since
    # they aren't a kind at all.
    #
    # Staff-initiated (require a target - any "staff" category type in
    # config, see game/config/inklings.yml):
    #   +inkling/hint <char>=<title>/<text>
    #   +inkling/vision <char>=<title>/<text>
    #   +inkling/nudge <char>=<title>/<text>
    #   +inkling/hook <char>=<title>/<text>
    #
    # Player or staff (no target = own character - any "shared"
    # category type, "secret" by default):
    #   +inkling/secret <title>/<text>
    #
    # Staff creating a shared-type thread for a player (args contain "="):
    #   +inkling/secret <char>=<title>/<text>
    #
    # Player-initiated (no target - always about themselves, any
    # "player" category type):
    #   +inkling/initiative <title>/<text>
    #   +inkling/request <title>/<text>
    #   +inkling/pitch <title>/<text>
    #   +inkling/goal <title>/<text>
    class InklingStartCmd
      include CommandHandler

      attr_accessor :kind, :target_name, :title, :text

      def parse_args
        self.kind = cmd.switch

        needs_target = Inklings.staff_kinds.include?(self.kind) ||
          (Inklings.shared_kinds.include?(self.kind) && cmd.args.to_s.include?("="))

        if needs_target
          args = cmd.parse_args(ArgParser.arg1_equals_arg2)
          self.target_name = titlecase_arg(args.arg1)
          remainder = args.arg2
        else
          remainder = cmd.args
        end

        # Title is mandatory: split on the first "/", same convention
        # as +inkling/new. required_args below rejects the command if
        # there's no "/" (title.blank?) rather than silently falling
        # back to an auto-generated title.
        title_and_text = remainder.to_s.split("/", 2)
        self.title = trim_arg(title_and_text[0])
        self.text = trim_arg(title_and_text[1])
      end

      def required_args
        base = self.target_name ? [self.target_name] : []
        base + [self.title, self.text]
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
        if Inklings.staff_kinds.include?(self.kind) ||
           (Inklings.shared_kinds.include?(self.kind) && self.target_name)
          return nil if Inklings.can_manage_inklings?(enactor)
          return t('dispatcher.not_allowed')
        end
        return nil
      end

      def handle
        if self.target_name
          ClassTargetFinder.with_a_character(self.target_name, client, enactor) do |model|
            start_thread(model, enactor)
          end
        else
          start_thread(enactor, enactor)
        end
      end

      def start_thread(subject, creator)
        staff_started = subject != creator

        inkling = Inkling.create(
          kind: self.kind,
          title: self.title,
          status: "open",
          character: subject,
          creator: creator,
          created_at: Time.now,
          player_unread: staff_started ? "true" : "false",
          locked: "false",
          approval_state: "draft",
          tags: "")

        InklingMessage.create(
          inkling: inkling,
          author: creator,
          text: self.text,
          created_at: Time.now,
          seq: Inklings.next_event_seq(inkling),
          is_staff: Inklings.can_manage_inklings?(creator) ? "true" : "false",
          is_private: "false",
          is_gm_note: "false",
          is_personal: "false",
          private_recipient_ids: "")

        notice = t('inklings.thread_started', :id => inkling.id)
        notice << " #{t('inklings.not_yet_submitted_notice', :id => inkling.id)}" unless staff_started
        client.emit_success notice
        warning = Inklings.staff_target_warning(subject, inkling.id) if Inklings.can_manage_inklings?(creator)
        client.emit warning if warning

        if staff_started
          Inklings.notify_new_message(subject, inkling)
        end
      end
    end
  end
end

