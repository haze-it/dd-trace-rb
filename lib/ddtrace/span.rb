require 'time'

# Datadog namespace
module Datadog
  # Span model that defines a logical unit of work that
  # composes a complete trace.
  class Span
    MAX_ID = 2**64 - 1

    attr_accessor :name, :service, :resource, :span_type,
                  :start_time, :end_time,
                  :span_id, :trace_id, :parent_id,
                  :meta, :status, :parent

    # Create a new span linked to the given tracer.
    def initialize(tracer, name, options = {})
      @tracer = tracer

      @name = name
      @service = options.fetch(:service, nil)
      @resource = options.fetch(:resource, name)
      @span_type = options.fetch(:span_type, nil)

      @span_id = Datadog.next_id()
      @parent_id = options.fetch(:parent_id, 0)
      @trace_id = options.fetch(:trace_id, @span_id)

      @meta = {}
      @status = 0

      @parent = nil

      @start_time = Time.now.utc
      @end_time = nil
    end

    def set_tag(key, value)
      @meta[key] = value
    end

    # Return the tag wth the given key, nil if it doesn't exist.
    def get_tag(key)
      @meta[key]
    end

    # Mark the span with the given error.
    def set_error(e)
      return if e.nil?
      @status = 1
      @meta['error.msg'] = e.message
      @meta['error.type'] = e.class.to_s
      @meta['error.stack'] = e.backtrace.join("\n")
    end

    # Mark the span finished at the current time and submit it.
    def finish
      finish_at(Time.now.utc)
    end

    # Mark the span finished at the given time and submit it.
    def finish_at(end_time)
      @end_time = end_time

      @tracer.record(self) unless @tracer.nil?

      self
    end

    # Return a string representation of the span.
    def to_s
      "Span(name:#{@name},sid:#{@span_id},tid:#{@trace_id},pid:#{@parent_id})"
    end

    # Set this span's parent, inheriting any properties not explicitly set.
    # If the parent is nil, set the span zero values.
    def set_parent(parent)
      @parent = parent

      if parent.nil?
        @trace_id = @span_id
        @parent_id = 0
      else
        @trace_id = parent.trace_id
        @parent_id = parent.span_id
        @service ||= parent.service
      end
    end

    def to_hash
      h = {
        span_id: @span_id,
        parent_id: @parent_id,
        trace_id: @trace_id,
        name: @name,
        service: @service,
        resource: @resource,
        type: @span_type,
        meta: @meta,
        error: @status
      }

      if !@start_time.nil? && !@end_time.nil?
        h[:start] = (@start_time.to_f * 1e9).to_i
        h[:duration] = ((@end_time - @start_time) * 1e9).to_i
      end

      h
    end
  end

  # Return a span id
  def self.next_id
    rand(Datadog::Span::MAX_ID)
  end
end