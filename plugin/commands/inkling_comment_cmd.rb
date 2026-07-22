module AresMUSH
  module Inklings
    # +inkling/comment <ref> - jumps straight to a single numbered entry
    # (message or roll) using the "<inkling_id>.<seq>" reference format
    # already shown next to every entry in the thread view (see
    # Inklings.event_ref) - e.g. +inkling/comment 3.4 shows entry #4 on
    # inkling #3, without displaying the rest of the thread around it.
    #
    # MUSH-only by design - see the "MUSH-only commands" note under
    # Core Philosophy #4 in the dev guide for why this and bare
    # +inkling/new (InklingNewUnreadCmd) are the two documented
    # exceptions to the MUSH/web parity rule.
    #
    # Deliberately does NOT touch read state (Inkling#player_unread or
    # the per-character read receipt - see Inklings.mark_read): looking
    # up one specific entry by number isn't the same as having read the
    # whole thread, unlike +inkling <id> / +inkling/new (see
    # Inklings.show_inkling).
    class InklingCommentCmd
      include CommandHandler

      attr_accessor :ref

      REF_FORMAT = /\A\d+\.\d+\z/

      def parse_args
        self.ref = cmd.args.to_s.strip
      end

      # No required_args - a blank ref used to fall through to the
      # framework's generic failure message pointing at a nonexistent
      # "help inkling/comment" topic (v4 Bug 001) before check_valid_format
      # below ever ran. The regex here already rejects blank input too,
      # so removing required_args means every malformed case - blank or
      # not - gets this command's own, more useful message instead.
      def check_valid_format
        return t('inklings.comment_invalid_format') unless self.ref.to_s =~ REF_FORMAT
        nil
      end

      def inkling_id
        self.ref.to_s.split(".", 2)[0]
      end

      def seq
        self.ref.to_s.split(".", 2)[1].to_i
      end

      # Memoized so check_valid_inkling, check_approved, check_can_view,
      # and handle don't each independently re-fetch the same record.
      def inkling
        @inkling ||= Inklings.find_inkling(inkling_id)
      end

      def check_valid_inkling
        # Checks run in alphabetical order by method name, not
        # declaration order, so check_valid_format may not have run
        # yet - re-check the format here rather than crashing on a
        # malformed ref.
        return nil unless self.ref.to_s =~ REF_FORMAT
        return t('inklings.invalid_id') if !inkling
        nil
      end

      def check_approved
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if inkling && inkling.character == enactor
        return t('inklings.char_not_approved') unless enactor.is_approved?
        nil
      end

      def check_can_view
        return nil if Inklings.can_view_or_reply?(inkling, enactor)
        t('dispatcher.not_allowed')
      end

      def handle
        header = Inklings.inkling_short_header(inkling)

        message = inkling.messages.to_a.find { |m| m.seq.to_i == seq }
        if message
          if Inklings.can_see_message?(message, enactor)
            client.emit "#{header}\n\n#{Inklings.format_view_message_block(inkling, message)}"
          else
            client.emit_failure t('dispatcher.not_allowed')
          end
          return
        end

        roll = inkling.rolls.to_a.find { |r| r.seq.to_i == seq }
        if roll
          if Inklings.can_see_roll?(roll, enactor)
            client.emit "#{header}\n\n#{Inklings.format_view_roll_block(inkling, roll)}"
          else
            client.emit_failure t('dispatcher.not_allowed')
          end
          return
        end

        client.emit_failure t('inklings.comment_not_found', :seq => seq, :id => inkling.id)
      end
    end
  end
end
