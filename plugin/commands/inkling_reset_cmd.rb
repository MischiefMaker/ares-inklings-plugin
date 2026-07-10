module AresMUSH
  module Inklings
    # +inkling/reset
    #
    # Permanently deletes every inkling thread, message, roll, and
    # participant record. Restricted to the "manage_game" permission
    # (normally just Coders/Admins), since this is destructive and
    # irreversible - it is deliberately a higher bar than
    # can_manage_inklings?, which many ordinary staff have.
    #
    # Requires the command to be entered twice within a short window as
    # a safety check: the first entry arms it and warns what will
    # happen, the second (typed again within CONFIRM_WINDOW_SECONDS)
    # actually performs the wipe. Linked jobs are left alone - only the
    # inkling side of things is deleted.
    class InklingResetCmd
      include CommandHandler

      CONFIRM_WINDOW_SECONDS = 60

      # Pending confirmations, keyed by character id, holding the time
      # the first entry was made. Intentionally in-memory only - a
      # server restart clears anything pending, which is the safer
      # default for a destructive command.
      @pending_confirmations = {}

      class << self
        attr_accessor :pending_confirmations
      end

      def check_permission
        return nil if Inklings.can_reset_system?(enactor)
        t('dispatcher.not_allowed')
      end

      def handle
        pending_at = self.class.pending_confirmations[enactor.id]

        if pending_at && (Time.now - pending_at) <= CONFIRM_WINDOW_SECONDS
          self.class.pending_confirmations.delete(enactor.id)
          perform_reset
        else
          self.class.pending_confirmations[enactor.id] = Time.now
          client.emit_success t('inklings.reset_confirm_needed', :seconds => CONFIRM_WINDOW_SECONDS)
        end
      end

      def perform_reset
        thread_count = Inkling.all.to_a.size

        Global.logger.warn("Inklings: #{enactor.name} reset the entire inklings system (#{thread_count} threads).")

        InklingParticipant.all.each { |p| p.delete }
        InklingRoll.all.each { |r| r.delete }
        InklingMessage.all.each { |m| m.delete }
        Inkling.all.each { |i| i.delete }

        client.emit_success t('inklings.reset_complete', :count => thread_count)
      end
    end
  end
end
