module AresMUSH
  module Inklings
    # +inkling/private <id>=<name>/<text>
    # Players can omit the name. Staff may include a target participant
    # name to direct the private note to that specific player.
    class InklingPrivateCmd
      include CommandHandler

      attr_accessor :id, :raw_text

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.id = args.arg1
        self.raw_text = trim_arg(args.arg2)
      end

      def required_args
        [self.id, self.raw_text]
      end

      def check_approved
        return nil if Inklings.can_manage_inklings?(enactor)
        return t('inklings.char_not_approved') unless enactor.is_approved?
        nil
      end

      def check_valid_inkling
        return t('inklings.invalid_id') if !Inklings.find_inkling(self.id)
        return nil
      end

      def check_can_reply
        inkling = Inklings.find_inkling(self.id)
        # Checks run in alphabetical order by method name, not
        # declaration order, so check_valid_inkling may not have run
        # yet. Bail out quietly here and let check_valid_inkling report
        # the real "invalid ID" error instead of crashing on nil.
        return nil if !inkling
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if Inklings.is_participant?(inkling, enactor)
        return t('dispatcher.not_allowed')
      end

      def check_not_closed
        inkling = Inklings.find_inkling(self.id)
        return nil if !inkling
        return t('inklings.thread_is_closed') if inkling.status == "closed"
        return nil
      end

      def handle
        inkling = Inklings.find_inkling(self.id)
        is_staff = Inklings.can_manage_inklings?(enactor)
        target = nil
        text = self.raw_text

        if is_staff && self.raw_text.include?("/")
          possible_name, possible_text = self.raw_text.split("/", 2).map(&:strip)
          possible_target = Character.find_one_by_name(titlecase_arg(possible_name))

          if possible_target
            if !Inklings.is_participant?(inkling, possible_target)
              client.emit_failure t('inklings.not_a_participant', :name => possible_target.name)
              return
            end

            target = possible_target
            text = possible_text
          end
        end

        if text.blank?
          client.emit_failure t('dispatcher.invalid_syntax')
          return
        end

        recipient_ids = is_staff ? (target ? target.id : inkling.character.id) : ""

        InklingMessage.create(
          inkling: inkling,
          author: enactor,
          text: text,
          created_at: Time.now,
          seq: Inklings.next_event_seq(inkling),
          is_staff: is_staff ? "true" : "false",
          is_private: "true",
          is_gm_note: "false",
          private_recipient_ids: recipient_ids)

        if is_staff
          inkling.update(player_unread: "true")
          Inklings.mirror_to_job(inkling, "[Private] #{text}", enactor)
          Inklings.notify_player(target || inkling.character, t('inklings.new_message_notice'))
        else
          Inklings.ensure_job(inkling,
            "#{enactor.name} private reply - #{t("inklings.kind_#{inkling.kind}")}",
            "[Private] #{text}", enactor)
        end

        client.emit_success t('inklings.private_reply_added')
      end
    end
  end
end
