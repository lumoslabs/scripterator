require 'forwardable'
require_relative 'script_redis'

module Scripterator
  class Runner
    extend Forwardable
    def_delegators :script_redis,
      :already_run_for?, :checked_ids, :expire_redis_sets, :failed_ids,
      :mark_as_failed_for, :mark_as_run_for, :script_key

    def initialize(description, &config_block)
      @script_description = description

      self.instance_eval(&config_block) if config_block
    end

    def run(options = {})
      unless options[:start_id] || options[:end_id]
        raise 'You must provide either a start ID or end ID'
      end
      @start_id         = options[:start_id] || 1
      @end_id           = options[:end_id]   || User.last.try(:id) || 0
      @redis_expiration = options[:redis_expiration]
      @output_stream    = options[:output_stream] || $stdout

      raise 'No per_record code defined' unless @per_record

      init_vars
      run_blocks
      output_stats
    end

    %w(before per_record after).each do |callback|
      define_method callback do |&block|
        instance_variable_set "@#{callback}", block
      end
    end

    def method_missing(name, *args, &block)
      if /find_(.*?)_by/ =~ name
        @find_record_by = block
      else
        super
      end
    end

    private

    def init_vars
      @success_count = 0
      @total_checked = 0
      @already_done  = 0
      @errors        = []
    end

    def output_progress(id)
      if id % 10000 == 0
        output "#{Time.now}: Checked #{@total_checked} rows, #{@success_count} migrated."
      end
    end

    def output_stats
      output "Total rows migrated: #{@success_count} / #{@total_checked}"
      output "#{@already_done} rows previously migrated and skipped"
      output "#{@errors.count} errors"
      if @errors.count > 0
        output "  Retrieve failed IDs with redis: SMEMBERS #{script_key(:failed)}"
      end
    end

    def output(*args)
      @output_stream.puts(*args)
    end

    def run_blocks
      self.instance_eval(&@before) if @before

      output "Starting at #{Time.now}..."
      run_loop
      output 'done'
      output "Finished at #{Time.now}...\n\n"

      self.instance_eval(&@after) if @after
    end

    def run_loop
      (@start_id..@end_id).each do |id|
        output_progress(id)

        run_single_row_block @find_record_by.call(id)
      end
      expire_redis_sets
    end

    def run_single_row_block(row)
      return if row.nil?

      if already_run_for? row.id
        @already_done += 1
      else
        mark_as_run_for row.id
        @total_checked += 1
        @success_count += 1 if self.instance_exec row, &@per_record
      end
    rescue
      errmsg = "Row #{row.id}: #{$!}"
      output "Error: #{errmsg}"
      @errors << errmsg
      mark_as_failed_for row.id
    end

    def script_redis
      @script_redis ||= ScriptRedis.new(@script_description, redis_expiration: @redis_expiration)
    end
  end
end
