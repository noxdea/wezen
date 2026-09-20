# frozen_string_literal: true

require "zlib"
require_relative "wezen/version"

# Ruby 3.2 added Data. Keep the gem usable on the minimum supported Ruby too.
unless defined?(Data) && Data.respond_to?(:define)
  Object.send(:remove_const, :Data) if defined?(Data)
  Data = Struct
  def Data.define(*members, &block)
    Struct.new(*members) do
      members.each { |member| undef_method :"#{member}=" }
      define_method(:initialize) do |*values, **keywords|
        values = members.map { |member| keywords.fetch(member) } if values.empty? && keywords.any?
        raise ArgumentError, "wrong number of members" unless values.length == members.length

        super(*values)
        freeze
      end
      define_method(:with) { |**changes| self.class.new(**to_h.merge(changes)) }
      class_eval(&block) if block
    end
  end
end

require_relative "wezen/animation"
require_relative "wezen/image"
require_relative "wezen/palette"
require_relative "wezen/quantize"
require_relative "wezen/png"
require_relative "wezen/apng"
require_relative "wezen/gif"
require_relative "wezen/cast"

module Wezen
  class Error < StandardError; end
end
