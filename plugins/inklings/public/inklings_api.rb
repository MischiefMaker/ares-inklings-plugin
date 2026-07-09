module AresMUSH
  module Inklings
    class InklingApi
      # GET /api/characters/:char_id/inklings
      # Returns list of inklings for a character, visible only to the character
      # and staff
      def self.get_inklings(char_id, viewer_id)
        char = Character[char_id]
        return { error: "Character not found" } if !char

        viewer = Character[viewer_id]
        return { error: "Viewer not found" } if !viewer

        # Only the character themselves or staff can view their inklings
        unless viewer.id == char.id || Inklings.can_manage_inklings?(viewer)
          return { error: "Not authorized" }
        end

        inklings = char.inklings.to_a.sort_by { |i| i.created_at }.reverse

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

        # Validate kind
        unless Inklings::ALL_KINDS.include?(kind)
          return { error: "Invalid inkling kind" }
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
          inkling: format_inkling_detail(inkling)
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
          inkling: format_inkling_detail(inkling)
        }
      end

      # POST /api/characters/:char_id/inklings/:inkling_id/reply
      # Add a reply to an inkling
      def self.reply_to_inkling(char_id, inkling_id, viewer_id, text)
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

        # Check inkling is not closed
        if inkling.status == "closed"
          return { error: "This inkling is closed" }
        end

        # Validate text is not empty
        if text.blank?
          return { error: "Reply text cannot be empty" }
        end

        is_staff = Inklings.can_manage_inklings?(viewer)

        # Create the message
        message = InklingMessage.create(
          inkling: inkling,
          author: viewer,
          text: text,
          created_at: Time.now,
          is_staff: is_staff ? "true" : "false"
        )

        if is_staff
          inkling.update(player_unread: "true")
          # Mirror to job if it exists
          Inklings.mirror_to_job(inkling, text, viewer)
          # Notify player
          Inklings.notify_player(inkling.character, "<inklings> You have a new inkling message. Use +inklings to view it.")
        else
          # Player replied - staff need to know
          Inklings.ensure_job(inkling,
            "#{viewer.name} replied - #{inkling.kind.titleize}",
            text,
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

        inkling.update(status: "closed")

        if inkling.job
          Jobs.close_job(viewer, inkling.job, "Inkling closed from web portal")
        end

        {
          inkling: format_inkling_summary(inkling)
        }
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

      def self.format_inkling_detail(inkling)
        format_inkling_summary(inkling).merge(
          messages: inkling.messages.sort_by { |m| m.created_at }.map { |m| format_message(m) }
        )
      end

      def self.format_message(message)
        {
          id: message.id,
          author: message.author ? message.author.name : "Unknown",
          author_id: message.author ? message.author.id : nil,
          text: message.text,
          created_at: message.created_at,
          is_staff: message.is_staff == "true"
        }
      end
    end
  end
end
