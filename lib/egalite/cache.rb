
=begin
キャッシュテーブルのデータ定義:

CREATE TABLE controller_cache (
  id SERIAL PRIMARY KEY,
  inner_path TEXT NOT NULL,
  query_string TEXT,
  language TEXT,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  content TEXT NOT NULL
);
=end

module Egalite
  module ControllerCache
    class <<self
      attr_accessor :table
      
      def create_table(db, opts = {})
        table = opts[:table_name] || :controller_cache
        
        create_table_without_query(db, opts)
        db.alter_table(table) {
          add_column :query_string, :varchar
        }
      end
      def create_table_without_query(db, opts = {})
        table = opts[:table_name] || :controller_cache
        
        db.create_table(table) {
          primary_key :id, :integer, :auto_increment => true
          column :inner_path, :varchar
          column :language, :varchar
          column :updated_at, :timestamp
          column :content, :varchar
        }
      end
    end
    module ClassMethods
      attr_reader :controller_cache_actions
      def cache_action(action, options)
        @controller_cache_actions ||= {}
        @controller_cache_actions[action.to_s] = options
      end
    end
    def self.included(base)
      base.extend(ClassMethods)
    end
    def __controller_cache__dataset(options)
      table = Egalite::ControllerCache.table
      dataset = table.filter(:inner_path => req.inner_path)
      if options[:with_query]
        dataset = dataset.filter(:query_string => __query_string(options))
      end
      if req.language
        dataset = dataset.filter(:language => req.language)
      end
      dataset
    end
    def __query_string(options)
      return nil unless options[:with_query] and not req.rack_request.query_string.empty?
      req.rack_request.query_string
    end
    def before_filter
      cache = self.class.controller_cache_actions[req.action_method]
      if cache and Egalite::ControllerCache.table
        result = super
        if result != true
          return result
        end
        dataset = __controller_cache__dataset(cache)
        record = dataset.first
        return true unless record
        return true if record[:updated_at] < (Time.now - cache[:expire])
        record[:content]
      else
        super
      end
    end
    def after_filter_html(html)
      html = super(html)
      cache = self.class.controller_cache_actions[req.action_method]
      if cache and Egalite::ControllerCache.table
        dataset = __controller_cache__dataset(cache)
        data = {
          :inner_path => req.inner_path,
          :language => req.language,
          :updated_at => Time.now,
          :content => html,
        }
        if cache[:with_query]
          data[:query_string] = __query_string(cache)
        end
        if dataset.count > 0
          dataset.update(data)
        else
          Egalite::ControllerCache.table.insert(data)
        end
      end
      return html
    end
  end
end
