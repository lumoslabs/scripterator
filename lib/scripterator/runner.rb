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

      @model ||= Proc.new { eval("#{@inferred_model_name}") } # constantize
    end

    def run(options = {})
      unless (options[:start_id] || options[:end_id]) || options[:id_list]
        raise 'You must provide either a start ID or end ID, or a comma-delimited id list'
      end
      @id_list          = options[:id_list] || []
      @start_id         = options[:start_id] || 1
      @end_id           = options[:end_id]
      @redis_expiration = options[:redis_expiration]
      @output_stream    = options[:output_stream] || $stdout

      raise 'No per_record code defined' unless @per_record

      output_init_details
      init_vars
      run_blocks
      output_stats
    end

    %w(model before per_record after).each do |callback|
      define_method callback do |&block|
        instance_variable_set "@#{callback}", block
      end
    end

    def method_missing(method_name, *args, &block)
      if model_name = /for_each_(.+)/.match(method_name)[1]
        @per_record          = block
        @inferred_model_name = model_name.split('_').map(&:capitalize).join
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

    def fetch_record(id)
      model_finder.find_by_id(id)
    end

    def model_finder
      @model_finder ||= self.instance_eval(&@model)
    end

    def output_progress
      if (@total_checked + @already_done) % 10000 == 0
        output "#{Time.now}: Checked #{@total_checked} rows, #{@success_count} migrated."
      end
    end

    def output_stats
      output "Total rows migrated: #{@success_count} / #{@total_checked}"
      output "#{@already_done} rows previously migrated and skipped"
      output "#{@errors.count} errors"
      if @errors.count > 0 && !failed_ids.empty?
        output "  Retrieve failed IDs with redis: SMEMBERS #{script_key(:failed)}"
      end
    end

    def output_init_details
      output " Checked IDs being stored in redis list: #{script_key(:checked)}"
      output " Failed IDs being stored in redis list: #{script_key(:failed)}"
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
      if @id_list.count > 0
        run_for_id_list
      elsif @end_id
        @id_list = (@start_id..@end_id)
        run_for_id_list
      else
        model_finder.find_each(start: @start_id) { |record| transform_one_record(record) }
      end

      expire_redis_sets
    end

    def run_for_id_list
      @id_list.each { |id| transform_one_record(fetch_record(id)) }
    end

    def transform_one_record(record)
      return if record.nil?

      output_progress

      if already_run_for? record.id
        @already_done += 1
      else
        mark_as_run_for record.id
        @total_checked += 1
        @success_count += 1 if self.instance_exec record, &@per_record
      end
    rescue
      errmsg = "Record #{record.id}: #{$!}"
      output "Error: #{errmsg}"
      @errors << errmsg
      mark_as_failed_for record.id
    end

    def script_redis
      @script_redis ||= ScriptRedis.new(@script_description, redis_expiration: @redis_expiration)
    end
  end
end
