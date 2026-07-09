module AresMUSH
  module Inklings
    def self.plugin_dir
      File.dirname(__FILE__)
    end

    def self.shortcuts
      Global.read_config("inklings", "shortcuts")
    end

    # Whether this character can manage inklings as staff (send hints,
    # visions, nudges, hooks; audit/delete other people's threads).
    # NOTE: Adjust this to whatever permission convention your game uses -
    # e.g. enactor.has_permission?('inklings') if you have a granular
    # permissions system. is_staff? is used here as a placeholder.
    def self.can_manage_inklings?(enactor)
      enactor.is_staff?
    end

    STAFF_KINDS = ["hint", "vision", "nudge", "hook"]
    PLAYER_KINDS = ["action", "research", "request", "update", "pitch", "goal"]
    SHARED_KINDS = ["secret"]
    ALL_KINDS = STAFF_KINDS + PLAYER_KINDS + SHARED_KINDS

    def self.find_inkling(id)
      Inkling.find_one_by_id(id)
    end

    # Whether char is meaningfully attached to this thread (as its
    # subject, the one who started it, or an explicitly added participant).
    # Staff can always act on any thread regardless of this check.
    def self.is_participant?(inkling, char)
      return true if inkling.character == char
      return true if inkling.creator == char
      return true if InklingParticipant.find(inkling_id: inkling.id, character_id: char.id).any?
      false
    end

    # Fixed job category so inkling-linked jobs land on their own board.
    # Create this category in-game with: job/category create INKLINGS
    # (override in inklings.yml if you want a different category name).
    def self.job_category
      Global.read_config("inklings", "job_category") || "INKLINGS"
    end

    # Makes sure the given inkling has a linked job, so staff are
    # notified. Creates one if it doesn't have one yet; otherwise mirrors
    # the message onto the existing job as a comment.
    def self.ensure_job(inkling, title, message, enactor)
      if inkling.job
        mirror_to_job(inkling, message, enactor)
        return inkling.job
      else
        result = Jobs.create_job(self.job_category, title, message, enactor)
        if result[:error]
          Global.logger.error("Inklings: Failed to create job for inkling ##{inkling.id} - #{result[:error]}")
          return nil
        end
        job = result[:job]
        inkling.update(job: job)
        return job
      end
    end

    # Adds a comment to an inkling's already-existing linked job.
    # admin_only is false because this is a message the player submitted
    # (or is meant to see), not an internal staff note.
    def self.mirror_to_job(inkling, message, enactor)
      return if !inkling.job
      Jobs.comment(inkling.job, enactor, message, false)
    end

    # There's no event fired when a JobReply is added, so instead of
    # pushing job replies into Inklings, we pull: call this whenever an
    # inkling is displayed, and it copies over any JobReply on the linked
    # job that hasn't been mirrored into the thread yet. admin_only
    # replies (internal staff notes on the job) are intentionally
    # skipped - those aren't meant for the player to see.
    def self.sync_job_replies(inkling)
      return if !inkling.job

      new_messages = false

      JobReply.find(job_id: inkling.job.id).to_a.each do |reply|
        next if reply.admin_only.to_s == "true"
        next if InklingMessage.find(source_job_reply_id: reply.id).any?

        InklingMessage.create(
          inkling: inkling,
          author: reply.author,
          text: reply.message,
          created_at: reply.respond_to?(:created_at) ? reply.created_at : Time.now,
          is_staff: "true",
          source_job_reply: reply)

        new_messages = true
      end

      if new_messages
        inkling.update(player_unread: "true")
        # NOTE: t() is a CommandHandler helper and isn't available here,
        # since this runs from a plain module method, not a command
        # instance. Using a plain string instead - swap in your game's
        # actual locale lookup (e.g. Global.locales.t(...)) if you want
        # this localized.
        Inklings.notify_player(inkling.character, "<inklings> You have a new inkling message. Use +inklings to view it.")
      end
    end

    def self.notify_player(char, message)
      Login.emit_ooc_if_logged_in(char, message)
    end

    # Whether a viewer is allowed to see a specific message.
    # Non-private messages are always visible. Private messages are
    # visible to: staff, the message author, and any character IDs
    # listed in private_recipient_ids.
    def self.can_see_message?(message, viewer)
      return true if message.is_private.to_s != "true"
      return true if Inklings.can_manage_inklings?(viewer)
      return true if message.author && message.author.id == viewer.id
      ids = message.private_recipient_ids.to_s.split(",").map(&:strip).reject(&:empty?)
      ids.include?(viewer.id)
    end

    def self.get_cmd_handler(client, cmd, enactor)
      case cmd.root
      when "inkling"
        if cmd.switch_is?("list")
          return InklingListCmd
        elsif cmd.switch_is?("delete")
          return InklingDeleteCmd
        elsif cmd.switch_is?("reply")
          return InklingReplyCmd
        elsif cmd.switch_is?("private")
          return InklingPrivateCmd
        elsif cmd.switch_is?("share")
          return InklingShareCmd
        elsif cmd.switch_is?("close")
          return InklingCloseCmd
        elsif ALL_KINDS.any? { |k| cmd.switch_is?(k) }
          return InklingStartCmd
        else
          return InklingViewCmd
        end
      when "inklings"
        return InklingsCmd
      end
      return nil
    end
  end
end
