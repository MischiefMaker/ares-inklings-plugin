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
          # Query explicitly by character_id rather than using
          # model.inklings (a reverse-collection macro). That macro was
          # found to sometimes return the enactor's own threads instead
          # of the target's, so an explicit query removes any ambiguity
          # about which character's threads we're pulling.
          inklings = Inkling.find(character_id: model.id).to_a
            .sort_by { |i| Inklings.time_value(i.created_at) }.reverse
          inklings.each { |i| Inklings.sync_job_replies(i) }

          drafts = model.is_approved? ? [] : Inklings.chargen_drafts(model)

          if inklings.empty? && drafts.empty?
            client.emit_success t('inklings.no_inklings_for', :name => model.name)
            return
          end

          list = []

          # Show chargen drafts first if any exist (unapproved characters only)
          if drafts.any?
            list << "%xh%cy--- CHARGEN DRAFTS (not yet approved) ---%xn"
            drafts.each do |d|
              list << "  [#{Inklings.color_type(d[:kind].upcase)}] #{Inklings.color_title(d[:title].to_s.blank? ? d[:label] : d[:title])} %xh%cy(DRAFT)%xn"
            end
            list << nil  # Blank line separator
          end

          # Show real inklings
          inkling_lines = inklings.map do |i|
            job_ref = i.job ? "job ##{i.job.id} [#{i.job.status}]" : t('inklings.no_linked_job')
            title = i.title.to_s.blank? ? Inklings.kind_label(i.kind) : i.title
            unread = i.player_unread == "true"
            count_text = "#{i.messages.to_a.size} msg(s)#{unread ? "%xh*%xn" : ""}"
            lock_text = i.locked == "true" ? " %xh%crLOCKED%xn" : ""
            "##{i.id} [#{Inklings.color_type(i.kind.upcase)}] #{Inklings.color_title(title)} (#{i.status}) #{Inklings.format_time(i.created_at, '%m/%d')} #{job_ref} - #{count_text}#{lock_text}"
          end
          list.concat(inkling_lines)

          template = BorderedPagedListTemplate.new list, cmd.page, 25,
            t('inklings.inklings_title_for', :name => model.name)
          client.emit template.render
        end
      end
    end
  end
end
