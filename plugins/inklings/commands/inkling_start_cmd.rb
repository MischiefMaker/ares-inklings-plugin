module AresMUSH
  module Inklings
    # Staff-initiated (require a target):
    #   +inkling/hint <char>=<text>
    #   +inkling/vision <char>=<text>
    #   +inkling/nudge <char>=<text>
    #   +inkling/hook <char>=<text>
    #
    # Player or staff (no target = own character):
    #   +inkling/secret <text>
    #
    # Staff creating a secret for a player (args contain "="):
    #   +inkling/secret <char>=<text>
    #
    # Player-initiated (no target - always about themselves):
    #   +inkling/action <text>
    #   +inkling/research <text>
    #   +inkling/request <text>
    #   +inkling/update <text>
    #   +inkling/pitch <text>
    #   +inkling/goal <text>
    class InklingStartCmd
      include CommandHandler

      attr_accessor :kind, :target_name, :text

      def parse_args
        self.kind = cmd.switch

        needs_target = Inklings::STAFF_KINDS.include?(self.kind) ||
          (self.kind == "secret" && cmd.args.to_s.include?("="))

        if needs_target
          args = cmd.parse_args(ArgParser.arg1_equals_arg2)
          self.target_name = titlecase_arg(args.arg1)
          self.text = args.arg2
        else
          self.text = trim_arg(cmd.args)
        end
      end

      def required_args
        self.target_name ? [self.target_name, self.text] : [self.text]
      end

      def check_valid_kind
        return nil if Inklings::ALL_KINDS.include?(self.kind)
        return t('inklings.invalid_kind')
      end

      def check_permission
        if Inklings::STAFF_KINDS.include?(self.kind) ||
           (self.kind == "secret" && self.target_name)
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
          status: "open",
          character: subject,
          creator: creator,
          created_at: Time.now,
          player_unread: staff_started ? "true" : "false")

        InklingMessage.create(
          inkling: inkling,
          author: creator,
          text: self.text,
          created_at: Time.now,
          is_staff: Inklings.can_manage_inklings?(creator) ? "true" : "false")

        if !staff_started
          # Player started this thread themselves - staff need to know.
          Inklings.ensure_job(inkling,
            "#{creator.name} - #{t("inklings.kind_#{self.kind}")}",
            self.text, creator)
        end

        client.emit_success t('inklings.thread_started', :id => inkling.id)

        if staff_started
          Inklings.notify_player(subject, t('inklings.new_message_notice'))
        end
      end
    end
  end
end
