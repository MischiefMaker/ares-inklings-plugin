module AresMUSH
  module Inklings
    # +inkling/untag <id>=<tag>
    # Remove a tag from an inkling.
    class InklingUntagCmd
      include CommandHandler

      attr_accessor :id, :tag

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.id = args.arg1
        self.tag = args.arg2
      end

      # No required_args - see v4 Bug 001 audit; points at the real
      # `help inklings` topic instead of a nonexistent per-switch one.
      def check_valid_format
        return t('dispatcher.invalid_syntax', :cmd => 'inklings') if self.id.blank? || self.tag.blank?
        nil
      end

      def inkling
        @inkling ||= Inklings.find_inkling(self.id)
      end

      def check_valid_inkling
        return t('inklings.invalid_id') if !inkling
        return nil
      end

      def check_can_manage
        return nil if Inklings.owner_or_staff?(inkling, enactor)
        t('dispatcher.not_allowed')
      end

      def handle
        tag = self.tag.to_s.strip.downcase

        if tag.empty?
          client.emit_failure t('inklings.invalid_tag')
          return
        end

        existing_tags = Inklings.get_tags(inkling)
        unless existing_tags.include?(tag)
          client.emit_failure t('inklings.tag_not_found', :tag => tag)
          return
        end

        Inklings.remove_tag(inkling, tag)
        client.emit_success t('inklings.tag_removed', :tag => tag)
      end
    end
  end
end
