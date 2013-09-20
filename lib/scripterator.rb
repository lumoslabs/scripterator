require "redis" unless defined? Redis

require "scripterator/version"
require "scripterator/runner"

module Scripterator
  class << self
    def run(description, &block)
      options = {}.tap do |o|
        o[:start_id]         = ENV['START'].try(:to_i)
        o[:end_id]           = ENV['END'].try(:to_i)
        o[:redis_expiration] = ENV['REDIS_EXPIRATION'].try(:to_i)
      end

      Runner.new(description, &block).run(options)
    end

    def checked_ids_for(description)
      Runner.new(description).checked_ids
    end

    def failed_ids_for(description)
      Runner.new(description).failed_ids
    end
  end
end
