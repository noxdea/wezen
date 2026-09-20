# frozen_string_literal: true

require "json"

module Wezen
  module Cast
    Event = Data.define(:time, :kind, :data)

    module_function

    def encode(width:, height:, events:, title: nil, env: {})
      width = Integer(width); height = Integer(height)
      raise ArgumentError, "invalid terminal dimensions" unless width.positive? && height.positive?
      header = { "version" => 2, "width" => width, "height" => height, "timestamp" => 0, "env" => env.transform_keys(&:to_s).transform_values(&:to_s) }
      header["title"] = title.to_s if title
      lines = [JSON.generate(header)]
      last_time = 0.0
      Array(events).each do |event|
        event = event.is_a?(Event) ? event : Event.new(*event)
        event = Event.new(Float(event.time), event.kind.to_sym, event.data.to_s)
        raise ArgumentError, "cast events must be chronological" if event.time < last_time
        raise ArgumentError, "event time must be non-negative" if event.time.negative?
        raise ArgumentError, "unknown cast event: #{event.kind}" unless %i[output input resize].include?(event.kind)
        kind = { output: "o", input: "i", resize: "r" }.fetch(event.kind)
        lines << JSON.generate([event.time, kind, event.data])
        last_time = event.time
      end
      lines.join("\n") + "\n"
    end

    def write(path, **options)
      File.write(path, encode(**options), mode: "wb")
      path
    end
  end
end
