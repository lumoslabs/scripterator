module Scripterator
  class Configuration
    attr_accessor :redis_expiration
    attr_reader   :redis

    # set config.redis = nil to use NilRedis implementation
    def redis=(r)
      @redis = r || Scripterator::NilRedis.new
    end
  end

  class NilRedis
    def smembers(*args)
      []
    end

    %w(expire sadd).each do |redis_method|
      define_method(redis_method) { |*args| nil }
    end
  end
end
