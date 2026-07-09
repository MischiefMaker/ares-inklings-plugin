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

      def check_valid_inkling
        return t('inklings.invalid_id') if !Inklings.find_inkling(self.id)
        return nil
      end

      def check_can_delete
        inkling = Inklings.find_inkling(self.id)
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if Inklings.is_participant?(inkling, enactor)
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
        inkling.delete

        client.emit_success t('inklings.inkling_deleted')
      end
    end
  end
end
