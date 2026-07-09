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
    # subject or the one who started it). Staff can always act on any
    # thread regardless of this check.
    def self.is_participant?(inkling, char)
      return true if inkling.character == char
      return true if inkling.creator == char
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
        job = Jobs.create_job(self.job_category, title, message, enactor)
        inkling.update(job: job)
        return job
      end
    end

    # Adds a comment to an inkling's already-existing linked job.
    # NOTE: Jobs.add_comment is a placeholder name/signature. The Jobs
    # plugin's real public API (plugins/jobs/public/jobs_api.rb) has a
    # confirmed Jobs.create_job and Jobs.close_job, but the method for
    # adding a reply to an EXISTING job isn't documented anywhere I could
    # verify - check that file for the actual method and swap it in here.
    # This is the only place that call needs to happen.
    def self.mirror_to_job(inkling, message, enactor)
      return if !inkling.job
      if Jobs.respond_to?(:add_comment)
        Jobs.add_comment(enactor, inkling.job, message, true)
      else
        Global.logger.warn("Inklings: Jobs.add_comment not found - reply not mirrored to job ##{inkling.job.id}. Update Inklings.mirror_to_job in inklings.rb to match your Jobs API.")
      end
    end

    def self.notify_player(char, message)
      Login.emit_ooc_if_logged_in(char, message)
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

    def self.get_event_handler(event_name)
      case event_name
      # NOTE: "JobReplyAddedEvent" is a placeholder event name. Check
      # plugins/jobs/public/*.rb in your install for the actual event
      # class the Jobs plugin fires when a reply/comment is added to a
      # job (via job/respond or job/discuss), and update this - and the
      # field names read in JobReplyEventHandler#on_event - to match.
      when "JobReplyAddedEvent"
        return JobReplyEventHandler
      end
      nil
    end
  end
end
