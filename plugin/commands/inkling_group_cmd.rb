module AresMUSH
  module Inklings
    # +inkling/group <id>=<group>,<group>
    class InklingGroupCmd
      include CommandHandler

      attr_accessor :id, :group_names

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.id = args.arg1
        self.group_names = Inklings.split_list(args.arg2)
      end

      def required_args
        [self.id] + self.group_names
      end

      def check_approved
        return nil if Inklings.can_manage_inklings?(enactor)
        return t('inklings.char_not_approved') unless enactor.is_approved?
        nil
      end

      def check_valid_inkling
        return t('inklings.invalid_id') if !Inklings.find_inkling(self.id)
        nil
      end

      def check_can_share
        inkling = Inklings.find_inkling(self.id)
        return nil if Inklings.can_manage_inklings?(enactor)
        return nil if inkling.character == enactor
        t('dispatcher.not_allowed')
      end

      def check_not_closed
        inkling = Inklings.find_inkling(self.id)
        return t('inklings.thread_is_closed') if inkling.status == "closed"
        nil
      end

      def handle
        inkling = Inklings.find_inkling(self.id)
        added = []
        missing = []
        skipped = []

        self.group_names.each do |group_name|
          chars = Inklings.find_matching_group_chars(group_name)
          chars = chars.reject { |c| c.id == enactor.id }

          if chars.empty?
            missing << group_name
            next
          end

          chars.each do |char|
            result = Inklings.add_participant(inkling, char, enactor)
            added << char.name if result == :added
            skipped << char.name if result == :already_shared
          end
        end

        if added.empty?
          if missing.any?
            client.emit_failure t('inklings.group_not_found', :name => missing.join(", "))
          else
            client.emit_failure t('inklings.already_shared')
          end
          return
        end

        notice = t('inklings.group_shared', :names => added.uniq.sort.join(", "))
        notice << " #{t('inklings.group_not_found', :name => missing.join(", "))}" if missing.any?
        client.emit_success notice
      end
    end
  end
end
