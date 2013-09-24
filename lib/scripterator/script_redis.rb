module Scripterator
  class ScriptRedis
    DEFAULT_EXPIRATION = 3 * 30 * 24 * 60 * 60 # 3 months

    def initialize(script_description, options = {})
      @key_prefix = "one_timer_script:#{script_description.downcase.split.join('_')}"
      @redis_expiration = options[:redis_expiration] || DEFAULT_EXPIRATION
    end

    def checked_ids
      redis.smembers(script_key(:checked)).map &:to_i
    end

    def failed_ids
      redis.smembers(script_key(:failed)).map &:to_i
    end

    def already_run_for?(id)
      redis.sismember script_key(:checked), id
    end

    def expire_redis_sets
      unless @redis_expiration <= 0
        %w(checked failed).each { |set| redis.expire script_key(set), @redis_expiration }
      end
    end

    def mark_as_failed_for(id)
      redis.sadd script_key(:failed), id
    end

    def mark_as_run_for(id)
      redis.sadd script_key(:checked), id
    end

    def script_key(set_name)
      "#{@key_prefix}:#{set_name}"
    end

    private

    def redis
      @redis ||= Scripterator.config.redis || Redis.new
    end
  end
end
