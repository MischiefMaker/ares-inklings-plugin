module AresMUSH
  module Inklings
    # NOTE: This is scaffolding, not a confirmed working implementation.
    # "JobReplyAddedEvent" and the field names read below (job_id,
    # char_id, message) are placeholders based on the general Ares event
    # convention (events pass ids, not objects - see Event Handling in
    # the coding tutorials). Check plugins/jobs/public/*.rb in your
    # install for:
    #   1. The actual event class Jobs fires when a reply is added via
    #      job/respond or job/discuss (it may only fire on job/respond,
    #      since job/discuss replies are staff-only and never seen by
    #      the submitter - which may be exactly what you want here).
    #   2. The actual field names on that event object.
    # Then update the event name in Inklings.get_event_handler and the
    # event.* calls below to match.
    class JobReplyEventHandler
      def on_event(event)
        job = Job[event.job_id]
        return if !job

        inkling = Inkling.find(job_id: job.id).first
        return if !inkling

        author = (event.respond_to?(:char_id) && event.char_id) ? Character[event.char_id] : nil
        message_text = event.respond_to?(:message) ? event.message : event.text

        InklingMessage.create(
          inkling: inkling,
          author: author,
          text: message_text,
          created_at: Time.now,
          is_staff: "true")

        inkling.update(player_unread: "true")
        Inklings.notify_player(inkling.character,
          "<inklings> You have a new inkling message. Use +inkling #{inkling.id} to view it.")
      end
    end
  end
end
