require "redis" unless defined? Redis

require "scripterator/version"
require "scripterator/configuration"
require "scripterator/runner"

module Scripterator
  class << self
    def configure
      yield config
    end

    def config
      @config ||= Scripterator::Configuration.new
    end

    def run(description, &block)
      options = {}.tap do |o|
        o[:start_id]         = ENV['START'].try(:to_i)
        o[:end_id]           = ENV['END'].try(:to_i)
        o[:redis_expiration] = ENV['REDIS_EXPIRATION'].try(:to_i)
      end

      Runner.new(description, &block).run(options)
    end

    %w(already_run_for? checked_ids failed_ids).each do |runner_method|
      define_method(runner_method) do |description, *args|
        Runner.new(description).send(runner_method, *args)
      end
    end
  end
end
