# frozen_string_literal: true

module Wezen
  Frame = Data.define(:rgba, :delay_ms)

  class Animation
    include Enumerable

    attr_reader :width, :height, :loop

    def initialize(width:, height:, loop: 0)
      @width = Integer(width)
      @height = Integer(height)
      @loop = Integer(loop)
      raise ArgumentError, "invalid animation dimensions" unless @width.positive? && @height.positive?
      raise ArgumentError, "loop must be non-negative" if @loop.negative?

      @frames = []
    end

    def add(rgba, delay_ms:)
      pixels = String(rgba).b
      delay = Integer(delay_ms)
      raise ArgumentError, "invalid RGBA frame" unless pixels.bytesize == @width * @height * 4
      raise ArgumentError, "delay_ms must be non-negative" if delay.negative?

      if (last = @frames.last) && last.rgba == pixels
        @frames[-1] = Frame.new(last.rgba, last.delay_ms + delay)
      else
        @frames << Frame.new(pixels.freeze, delay)
      end
      self
    end

    def <<(frame)
      raise ArgumentError, "expected Wezen::Frame" unless frame.respond_to?(:rgba) && frame.respond_to?(:delay_ms)

      add(frame.rgba, delay_ms: frame.delay_ms)
    end

    def size = @frames.size
    def duration_ms = @frames.sum(&:delay_ms)
    def each(&block) = block ? @frames.each(&block) : @frames.each

    def coalesce(tolerance: 0)
      tolerance = Integer(tolerance)
      raise ArgumentError, "tolerance must be non-negative" if tolerance.negative?

      result = self.class.new(width: @width, height: @height, loop: @loop)
      @frames.each do |frame|
        frames = result.instance_variable_get(:@frames)
        if (last = frames.last) && same?(last.rgba, frame.rgba, tolerance)
          frames[-1] = Frame.new(last.rgba, last.delay_ms + frame.delay_ms)
        else
          result << frame
        end
      end
      result
    end

    def scale(to_width:, to_height:)
      result = self.class.new(width: to_width, height: to_height, loop: @loop)
      each { |frame| result.add(Image.scale(frame.rgba, @width, @height, to_width: to_width, to_height: to_height), delay_ms: frame.delay_ms) }
      result
    end

    def crop(bounds)
      x, y, width, height = Image.bounds(bounds)
      result = self.class.new(width: width, height: height, loop: @loop)
      each { |frame| result.add(Image.crop(frame.rgba, @width, @height, [x, y, width, height]), delay_ms: frame.delay_ms) }
      result
    end

    def drop_to(fps:)
      fps = Float(fps)
      raise ArgumentError, "fps must be positive" unless fps.positive?
      interval = 1000.0 / fps
      result = self.class.new(width: @width, height: @height, loop: @loop)
      elapsed = 0.0
      next_sample = 0.0
      each do |frame|
        frame_start = elapsed
        frame_end = elapsed + frame.delay_ms
        while next_sample < frame_end || (result.size.zero? && next_sample == frame_start)
          result.add(frame.rgba, delay_ms: interval.round)
          next_sample += interval
        end
        elapsed = frame_end
      end
      result
    end

    private

    def same?(left, right, tolerance)
      return true if left == right
      return false unless tolerance.positive? && left.bytesize == right.bytesize

      left.bytes.zip(right.bytes).all? { |a, b| (a - b).abs <= tolerance }
    end
  end
end
