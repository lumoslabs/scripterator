require "redis" unless defined? Redis

require "scripterator/version"
require "scripterator/runner"

module Scripterator
  def self.run(description, &block)
    options = {}.tap do |o|
      o[:start_id]         = ENV['START'].try(:to_i)
      o[:end_id]           = ENV['END'].try(:to_i)
      o[:redis_expiration] = ENV['REDIS_EXPIRATION'].try(:to_i)
    end

    Runner.new(description, options, &block).run
  end
end
