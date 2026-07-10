module AresMUSH
  module Inklings
    # +inkling/delete <id>
    #
    # Staff can delete any thread outright. If a player deletes their own
    # thread, staff are notified via a job (creating one if the thread
    # didn't already have one), since the content is gone once this runs.
    class InklingDeleteCmd
      include CommandHandler

      attr_accessor :id

      def parse_args
        self.id = cmd.args
      end

      def required_args
        [self.id]
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

      def check_can_delete
        inkling = Inklings.find_inkling(self.id)
        # Checks run in alphabetical order by method name, not
        # declaration order, so check_valid_inkling may not have run
        # yet. Bail out quietly here and let check_valid_inkling report
        # the real "invalid ID" error instead of crashing on nil.
        return nil if !inkling
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if inkling.character == enactor
        return t('dispatcher.not_allowed')
      end

      def handle
        inkling = Inklings.find_inkling(self.id)
        is_staff = Inklings.can_manage_inklings?(enactor)

        if !is_staff
          transcript = inkling.messages.map { |m| "#{m.author ? m.author.name : "?"}: #{m.text}" }.join(" / ")
          Inklings.ensure_job(inkling,
            "#{enactor.name} deleted a #{t("inklings.kind_#{inkling.kind}")}",
            t('inklings.deleted_notice_body', :text => transcript),
            enactor)
        end

        inkling.messages.each { |m| m.delete }
        inkling.rolls.each { |r| r.delete }
        InklingParticipant.find(inkling_id: inkling.id).each { |p| p.delete }
        inkling.delete

        client.emit_success t('inklings.inkling_deleted')
      end
    end
  end
end
