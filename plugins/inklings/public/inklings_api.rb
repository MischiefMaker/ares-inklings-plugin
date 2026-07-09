module AresMUSH
  module Inklings
    class InklingApi
      # GET /api/characters/:char_id/inklings
      # Returns list of inklings for a character, visible only to the character,
      # staff, and players the character has shared inklings with.
      # Supports ?status=open|closed|all (defaults to open).
      def self.get_inklings(char_id, viewer_id, status_filter: "open")
        char = Character[char_id]
        return { error: "Character not found" } if !char

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

        # Only the character themselves or staff can view their inklings
        unless viewer.id == char.id || Inklings.can_manage_inklings?(viewer)
          return { error: "Not authorized" }
        end

        # Non-staff players must be approved to browse inklings
        unless Inklings.can_manage_inklings?(viewer) || viewer.is_approved?
          return { error: "Your character must be approved to access inklings." }
        end

        own = char.inklings.to_a
        shared = InklingParticipant.find(character_id: viewer.id)
          .map(&:inkling).compact
        inklings = (own + shared).uniq(&:id)

        inklings = case status_filter
          when "closed" then inklings.select { |i| i.status == "closed" }
          when "all"    then inklings
          else               inklings.select { |i| i.status == "open" }
          end

        inklings = inklings.sort_by { |i| i.created_at }.reverse

        {
          inklings: inklings.map { |i| format_inkling_summary(i) }
        }
      end

      # POST /api/characters/:char_id/inklings
      # Create a new inkling
      def self.create_inkling(char_id, viewer_id, kind, text)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

        # Only the character themselves or staff can create inklings for them
        unless viewer.id == char.id || Inklings.can_manage_inklings?(viewer)
          return { error: "Not authorized" }
        end

        # Non-staff players must be approved, except for chargen kinds
        unless Inklings.can_manage_inklings?(viewer) || viewer.is_approved? || Inklings::CHARGEN_KINDS.include?(kind)
          return { error: "Your character must be approved to create inklings." }
        end

        # Validate kind and enforce staff-only kinds
        unless Inklings::ALL_KINDS.include?(kind)
          return { error: "Invalid inkling kind" }
        end

        if Inklings::STAFF_KINDS.include?(kind) && !Inklings.can_manage_inklings?(viewer)
          return { error: "Not authorized" }
        end

        # Validate text is not empty
        if text.blank?
          return { error: "Inkling text cannot be empty" }
        end

        # Create the inkling
        inkling = Inkling.create(
          kind: kind,
          status: "open",
          character: char,
          creator: viewer,
          created_at: Time.now,
          player_unread: (viewer.id == char.id) ? "false" : "true"
        )

        # Add the initial message
        InklingMessage.create(
          inkling: inkling,
          author: viewer,
          text: text,
          created_at: Time.now,
          is_staff: Inklings.can_manage_inklings?(viewer) ? "true" : "false"
        )

        # If player created this, staff need to know
        if viewer.id == char.id
          Inklings.ensure_job(inkling,
            "#{viewer.name} - #{kind.titleize}",
            text,
            viewer)
        end

        {
          inkling: format_inkling_detail(inkling, viewer)
        }
      end

      # GET /api/characters/:char_id/inklings/:inkling_id
      # Get full detail of an inkling with all messages
      def self.get_inkling(char_id, inkling_id, viewer_id)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

        # Verify this inkling belongs to the character
        unless inkling.character == char
          return { error: "Inkling does not belong to this character" }
        end

        # Only the character themselves or staff can view their inklings
        unless viewer.id == char.id || Inklings.can_manage_inklings?(viewer)
          return { error: "Not authorized" }
        end

        # Sync job replies if there's a linked job
        Inklings.sync_job_replies(inkling)

        # Mark as read if the character is viewing their own inkling
        if viewer.id == char.id
          inkling.update(player_unread: "false")
        end

        {
          inkling: format_inkling_detail(inkling, viewer)
        }
      end

      # POST /api/characters/:char_id/inklings/:inkling_id/reply
      # Add a reply to an inkling
      def self.reply_to_inkling(char_id, inkling_id, viewer_id, text, is_private: false)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

        # Verify this inkling belongs to the character
        unless inkling.character == char
          return { error: "Inkling does not belong to this character" }
        end

        # Only the character themselves or staff can reply
        unless viewer.id == char.id || Inklings.can_manage_inklings?(viewer)
          return { error: "Not authorized" }
        end

        unless Inklings.can_manage_inklings?(viewer) || viewer.is_approved?
          return { error: "Your character must be approved to reply to inklings." }
        end
        if inkling.status == "closed"
          return { error: "This inkling is closed" }
        end

        # Validate text is not empty
        if text.blank?
          return { error: "Reply text cannot be empty" }
        end

        is_staff = Inklings.can_manage_inklings?(viewer)

        # Auto-private: if staff reply and last message is private,
        # inherit its privacy and recipients.
        if is_staff && !is_private
          last_msg = inkling.messages.to_a.sort_by { |m| m.created_at }.last
          if last_msg && last_msg.is_private.to_s == "true"
            is_private = true
          end
        end

        recipient_ids = ""
        if is_private
          if is_staff
            recipient_ids = inkling.messages.to_a.sort_by { |m| m.created_at }.last&.private_recipient_ids.to_s.presence || inkling.character.id
          end
          # player private: recipient_ids stays empty (author + staff only)
        end

        # Create the message
        message = InklingMessage.create(
          inkling: inkling,
          author: viewer,
          text: text,
          created_at: Time.now,
          is_staff: is_staff ? "true" : "false",
          is_private: is_private ? "true" : "false",
          private_recipient_ids: recipient_ids
        )

        job_text = is_private ? "[Private] #{text}" : text

        if is_staff
          inkling.update(player_unread: "true")
          Inklings.mirror_to_job(inkling, job_text, viewer)
          Inklings.notify_player(inkling.character, "<inklings> You have a new inkling message. Use +inklings to view it.")
        else
          Inklings.ensure_job(inkling,
            "#{viewer.name} replied - #{inkling.kind.titleize}",
            job_text,
            viewer)
        end

        {
          message: format_message(message)
        }
      end

      # PUT /api/characters/:char_id/inklings/:inkling_id/close
      # Close an inkling
      def self.close_inkling(char_id, inkling_id, viewer_id)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

        # Verify this inkling belongs to the character
        unless inkling.character == char
          return { error: "Inkling does not belong to this character" }
        end

        # Only the character themselves or staff can close
        unless viewer.id == char.id || Inklings.can_manage_inklings?(viewer)
          return { error: "Not authorized" }
        end

        unless Inklings.can_manage_inklings?(viewer) || viewer.is_approved?
          return { error: "Your character must be approved to close inklings." }
        end

        if inkling.job
          Jobs.close_job(viewer, inkling.job, "Inkling closed from web portal")
        end

        {
          inkling: format_inkling_summary(inkling)
        }
      end

      # DELETE /api/characters/:char_id/inklings/:inkling_id
      def self.delete_inkling(char_id, inkling_id, viewer_id)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

        unless inkling.character == char
          return { error: "Inkling does not belong to this character" }
        end

        unless viewer.id == char.id || Inklings.can_manage_inklings?(viewer)
          return { error: "Not authorized" }
        end

        unless Inklings.can_manage_inklings?(viewer) || viewer.is_approved?
          return { error: "Your character must be approved to delete inklings." }
        end

        unless Inklings.can_manage_inklings?(viewer)
          transcript = inkling.messages.map { |m| "#{m.author ? m.author.name : "?"}: #{m.text}" }.join(" / ")
          Inklings.ensure_job(inkling,
            "#{viewer.name} deleted a #{inkling.kind.titleize}",
            "The player deleted this inkling. Its contents were: #{transcript}",
            viewer)
        end

        inkling.messages.each { |m| m.delete }
        inkling.rolls.each { |r| r.delete }
        InklingParticipant.find(inkling_id: inkling.id).each { |p| p.delete }
        inkling.delete

        { success: true }
      end

      # POST /api/characters/:char_id/inklings/:inkling_id/share
      def self.share_inkling(char_id, inkling_id, viewer_id, target_name)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        inkling = Inklings.find_inkling(inkling_id)
        return { error: "Inkling not found" } if !inkling

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

        unless inkling.character == char
          return { error: "Inkling does not belong to this character" }
        end

        unless viewer.id == char.id || Inklings.can_manage_inklings?(viewer)
          return { error: "Not authorized" }
        end

        unless Inklings.can_manage_inklings?(viewer) || viewer.is_approved?
          return { error: "Your character must be approved to share inklings." }
        end

        return { error: "Cannot share a closed inkling" } if inkling.status == "closed"

        target = Character.find_one_by_name(target_name)
        return { error: "Character '#{target_name}' not found" } if !target

        if Inklings.is_participant?(inkling, target)
          return { error: "#{target.name} already has access to this inkling" }
        end

        InklingParticipant.create(
          inkling: inkling,
          character: target,
          added_at: Time.now)

        Inklings.notify_player(target,
          "<inklings> #{viewer.name} has shared an inkling with you. Use +inkling #{inkling.id} to view it.")

        { success: true, target_name: target.name }
      end

      private

      def self.format_inkling_summary(inkling)
        {
          id: inkling.id,
          kind: inkling.kind,
          status: inkling.status,
          created_at: inkling.created_at,
          message_count: inkling.messages.size,
          player_unread: inkling.player_unread == "true",
          linked_job: inkling.job ? { id: inkling.job.id, status: inkling.job.status } : nil
        }
      end

      def self.format_inkling_detail(inkling, viewer = nil)
        messages = inkling.messages.sort_by { |m| m.created_at }
        if viewer
          messages = messages.select { |m| Inklings.can_see_message?(m, viewer) }
        end
        format_inkling_summary(inkling).merge(
          messages: messages.map { |m| format_message(m) }
        )
      end

      def self.format_message(message)
        {
          id: message.id,
          author: message.author ? message.author.name : "Unknown",
          author_id: message.author ? message.author.id : nil,
          text: message.text,
          created_at: message.created_at,
          is_staff: message.is_staff == "true",
          is_private: message.is_private == "true",
          private_recipient_ids: message.is_private == "true" ?
            message.private_recipient_ids.to_s.split(",").map(&:strip).reject(&:empty?) : []
        }
      end
    end
  end
end
