module AresMUSH
  module Inklings
    # +inkling/list <char>
    class InklingListCmd
      include CommandHandler

      attr_accessor :target_name

      def parse_args
        self.target_name = titlecase_arg(cmd.args)
      end

      def required_args
        [self.target_name]
      end

      def check_can_view
        return nil if Inklings.can_manage_inklings?(enactor)
        return t('dispatcher.not_allowed')
      end

      def handle
        ClassTargetFinder.with_a_character(self.target_name, client, enactor) do |model|
          inklings = model.inklings.sort_by { |i| i.created_at }.reverse

          if inklings.empty?
            client.emit_success t('inklings.no_inklings_for', :name => model.name)
            return
          end

          list = inklings.map do |i|
            job_ref = i.job ? "job ##{i.job.id} [#{i.job.status}]" : t('inklings.no_linked_job')
            "##{i.id} [#{i.kind.upcase}] (#{i.status}) #{i.created_at.strftime('%m/%d')} #{job_ref} - #{i.messages.to_a.size} msg(s)"
          end

          template = BorderedPagedListTemplate.new list, cmd.page, 25,
            t('inklings.inklings_title_for', :name => model.name)
          client.emit template.render
        end
      end
    end
  end
end
