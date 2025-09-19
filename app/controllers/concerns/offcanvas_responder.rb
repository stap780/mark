module OffcanvasResponder
  extend ActiveSupport::Concern

  private

  # Returns a standard set of Turbo Streams to:
  # - render the flash via render_turbo_flash helper
  # - close the offcanvas panel by clearing its frame content
  # Usage: render turbo_stream: turbo_close_offcanvas_flash + [your extra streams]
  def turbo_close_offcanvas_flash
    [
      render_turbo_flash,
      turbo_stream.update(:offcanvas, "")
    ]
  end
end
