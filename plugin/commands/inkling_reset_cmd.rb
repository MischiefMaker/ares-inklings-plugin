module AresMUSH
  module Inklings
    # +inkling/reset
    #
    # Permanently deletes every inkling thread, message, roll,
    # participant record, and read receipt. Restricted to the
    # "manage_game" permission
    # (normally just Coders/Admins), since this is destructive and
    # irreversible - it is deliberately a higher bar than
    # can_manage_inklings?, which many ordinary staff have.
    #
    # Uses a one-time token confirmation: first run displays a token to
    # copy, second run with that token performs the wipe. Linked jobs
    # are left alone - only the inkling side of things is deleted.
    class InklingResetCmd
      include CommandHandler

      CONFIRM_EXPIRY_SECONDS = 300

      # Pending confirmations: { char_id => { token: 'ABC123', time: Time.now } }
      # Intentionally in-memory only - a server restart clears pending
      # confirmations, which is the safer default for a destructive command.
      @pending_confirmations = {}

      class << self
        attr_accessor :pending_confirmations
      end

      attr_accessor :confirmation_token

      def parse_args
        self.confirmation_token = cmd.args.to_s.strip
      end

      def check_permission
        return nil if Inklings.can_reset_system?(enactor)
        t('dispatcher.not_allowed')
      end

      def handle
        pending = self.class.pending_confirmations[enactor.id]

        if confirmation_token.present?
          # User provided a token - validate it
          unless pending
            return client.emit_failure t('inklings.reset_no_pending_confirmation')
          end

          if Time.now - pending[:time] > CONFIRM_EXPIRY_SECONDS
            self.class.pending_confirmations.delete(enactor.id)
            return client.emit_failure t('inklings.reset_token_expired')
          end

          unless pending[:token] == confirmation_token
            return client.emit_failure t('inklings.reset_invalid_token')
          end

          self.class.pending_confirmations.delete(enactor.id)
          perform_reset
        else
          # No token provided - generate and display one
          token = generate_token
          self.class.pending_confirmations[enactor.id] = { token: token, time: Time.now }
          client.emit_success t('inklings.reset_confirm_with_token', :token => token, :seconds => CONFIRM_EXPIRY_SECONDS)
        end
      end

      private

      def generate_token
        SecureRandom.alphanumeric(8).upcase
      end

      def perform_reset
        thread_count = Inkling.all.to_a.size

        Global.logger.warn("Inklings: #{enactor.name} reset the entire inklings system (#{thread_count} threads).")

        InklingReadReceipt.all.each { |r| r.delete }
        InklingParticipant.all.each { |p| p.delete }
        InklingRoll.all.each { |r| r.delete }
        InklingMessage.all.each { |m| m.delete }
        Inkling.all.each { |i| i.delete }

        client.emit_success t('inklings.reset_complete', :count => thread_count)
      end
    end
  end
end
