# frozen_string_literal: true

module CouchbaseOrm
  module Relation
    extend ActiveSupport::Concern

    class CouchbaseOrm_Relation
      def initialize(model:, where: where = nil, order: order = nil, limit: limit = nil, _not: _not = false)
        CouchbaseOrm.logger.debug "CouchbaseOrm_Relation init: #{model} where:#{where.inspect} not:#{_not.inspect} order:#{order.inspect} limit: #{limit}"
        @model = model
        @limit = limit
        @where = []
        @order = {}
        @order = merge_order(**order) if order
        @where = merge_where(where, _not) if where
        CouchbaseOrm.logger.debug "- #{self}"
      end

      def to_s
        "CouchbaseOrm_Relation: #{@model} where:#{@where.inspect} order:#{@order.inspect} limit: #{@limit}"
      end

      # Constructs a N1QL query string for Couchbase to select document IDs based on defined criteria.
      #
      # N1QL (Non-first Normal Form Query Language) is a powerful query language for Couchbase
      # that allows you to perform complex queries on your data.
      # For more details, see the [Couchbase N1QL Documentation](https://docs.couchbase.com/server/current/n1ql/n1ql-intro/index.html).
      #
      # @return [String] The constructed N1QL query string.
      #
      # @example Construct a N1QL query to find document IDs with specific criteria
      #   class User < Couchbase::Base
      #     attribute :active, type: :bool
      #   end
      #
      #   user_query = User.where(active: true)
      #                    .to_n1ql
      #   # user_query => "select raw meta().id from `bucket_name` where type = 'user' and active = true"
      def to_n1ql
        bucket_name = @model.bucket.name
        where = build_where
        order = build_order
        limit = build_limit
        "select raw meta().id from `#{bucket_name}` where #{where} order by #{order} #{limit}"
      end

      # Executes a N1QL query on the Couchbase cluster and returns the results.
      #
      # This method runs the provided N1QL query using the Couchbase cluster associated with the model.
      # It ensures the query is executed with a consistent view of the data.
      # The results are logged and returned wrapped in a `N1qlProxy` object.
      #
      # @param n1ql_query [String] The N1QL query to be executed.
      # @return [N1qlProxy] The results of the query wrapped in a `N1qlProxy` object.
      #
      # @example Execute a N1QL query to find active users
      #   class User < CouchbaseOrm::Base
      #
      #     def self.active_users
      #       n1ql_query = where(active: true)
      #                       .order(created_at: :desc)
      #                       .limit(10)
      #                       .to_n1ql
      #       execute(n1ql_query)
      #     end
      #   end
      #
      #   results = User.active_users
      #   # This will execute the N1QL query and return the results wrapped in a `N1qlProxy` object.
      #   # You can iterate over the results, access specific fields, etc.
      def execute(n1ql_query)
        result = @model.cluster.query(n1ql_query, Couchbase::Options::Query.new(scan_consistency: :request_plus))
        CouchbaseOrm.logger.debug { "Relation query: #{n1ql_query} return #{result.rows.to_a.length} rows" }
        N1qlProxy.new(result)
      end

      # Constructs and executes a N1QL query for Couchbase based on the current state of the instance.
      #
      # @return [N1qlProxy] The results of the query wrapped in a `N1qlProxy` object.
      #
      # @example Execute a query to find active users
      #   class User < CouchbaseOrm::Base
      #
      #     def self.active_users
      #       where(active: true)
      #         .order(created_at: :desc)
      #         .limit(10)
      #         .query
      #     end
      #   end
      #
      #   results = User.active_users
      #   # This will execute the N1QL query and return the results wrapped in a `N1qlProxy` object.
      #   # You can iterate over the results, access specific fields, etc.
      def query
        CouchbaseOrm.logger.debug("Query: #{self}")
        n1ql_query = to_n1ql
        execute(n1ql_query)
      end

      # Updates all documents in the Couchbase bucket that match the specified conditions.
      #
      # This method constructs and executes a N1QL query to update documents in the Couchbase bucket
      # based on the specified conditions. It logs the query execution and returns the results.
      #
      # @param cond [Hash] The conditions to update the documents with.
      # @return [N1qlProxy] The results of the update operation wrapped in a `N1qlProxy` object.
      #
      # @example Update the 'active' status of users created before a certain date
      #   class User < CouchbaseOrm::Base
      #    # attributes
      #   end
      #
      #   results = User.where("created_at < '2023-01-01'").update_all(active: false)
      #   # This will construct and execute the N1QL query to update all users created before 2023-01-01
      #   # to have 'active' set to false.
      #   # You can iterate over the results, check the status, etc.
      def update_all(**cond)
        bucket_name = @model.bucket.name
        where = build_where
        limit = build_limit
        update = build_update(**cond)
        n1ql_query = "update `#{bucket_name}` set #{update} where #{where} #{limit}"
        execute(n1ql_query)
      end

      # Executes the current query and returns the result as an array of document IDs.
      #
      # This method constructs and executes a N1QL query based on the current state of the instance,
      # and converts the result to an array of document IDs.
      #
      # @return [Array<String>] An array of document IDs.
      #
      # @example Retrieve IDs of active users created before a certain date
      #   class User < CouchbaseOrm::Base
      #
      #     def self.active_users
      #       where(active: true)
      #         .order(created: :desc)
      #         .limit(10)
      #         .ids
      #     end
      #   end
      #
      #   user_ids = User.active_user_ids
      #   # This will construct and execute the N1QL query to retrieve the IDs of active users
      #   # created before a certain date, and return the result as an array of document IDs.
      #   # You can iterate over the IDs, fetch specific documents by ID, etc.
      def ids
        query.to_a
      end

      # Retrieves the first document that matches the current query conditions.
      #
      # This method modifies the current query to limit the result to 1 document, executes the query,
      # and returns the first document that matches the query conditions.
      #
      # @return [Object, nil] The first document that matches the query conditions, or nil if no documents match.
      def first
        result = @model.cluster.query(self.limit(1).to_n1ql,
                                      Couchbase::Options::Query.new(scan_consistency: :request_plus))
        first_id = result.rows.to_a.first
        @model.find(first_id) if first_id
      end

      # Retrieves the last document that matches the current query conditions.
      #
      # This method executes the query,
      # and returns the last document that matches the query conditions.
      #
      # @return [Object, nil] The last document that matches the query conditions, or nil if no documents match.
      def last
        result = @model.cluster.query(to_n1ql, Couchbase::Options::Query.new(scan_consistency: :request_plus))
        last_id = result.rows.to_a.last
        @model.find(last_id) if last_id
      end

      # Retrieves the count of documents that match the current query conditions.
      #
      # This method constructs and executes a N1QL query based on the current state of the instance
      # and returns the count of documents that match the query conditions.
      #
      # @return [Integer] The count of documents that match the query conditions.
      def count
        query.count
      end

      # Checks if there are any documents that match the current query conditions.
      #
      # This method constructs and executes a N1QL query with a limit of 1 document
      # and returns true if no documents match the query conditions.
      #
      # @return [Boolean] True if no documents match the query conditions, false otherwise.
      def empty?
        limit(1).count.zero?
      end

      # Retrieves specific fields from the documents that match the current query conditions.
      #
      # This method constructs and executes a N1QL query to retrieve the specified fields
      # from the documents that match the current query conditions.
      #
      # @param fields [Array<Symbol>] The fields to retrieve from the documents.
      # @return [Array<Object>] An array of field values for each document.
      #
      # @example Retrieve the names of all active users
      #   class User < Couchbase::Base
      #
      #     def self.active_user_names
      #       where(active: true).pluck(:name)
      #     end
      #   end
      #
      #   active_user_names = User.active_user_names
      #   # This will construct and execute the N1QL query to retrieve the names of all active users
      #   # and return an array of names.
      def pluck(*fields)
        map do |model|
          if fields.length == 1
            model.send(fields.first)
          else
            fields.map do |field|
              model.send(field)
            end
          end
        end
      end

      alias size count
      alias length count

      # Converts the results of the current query into an array of model instances.
      #
      # This method executes the current query to get the IDs of the matching documents,
      # fetches the documents using the model's `find` method, and returns them as an array.
      #
      # @return [Array<Object>] An array of model instances that match the query conditions.
      #
      # @example Retrieve all active users as an array
      #   class User < Couchbase::Base
      #
      #     def self.active_users
      #       where(active: true).to_ary
      #     end
      #   end
      #
      #   active_users = User.active_users
      #   # This will construct and execute the N1QL query to retrieve the IDs of all active users,
      #   # fetch the corresponding documents, and return them as an array of user instances.
      def to_ary
        ids = query.results
        return [] if ids.empty?

        Array(ids && @model.find(ids))
      end

      alias to_a to_ary

      delegate :each, :map, :collect, :find, :filter, :reduce, to: :to_ary

      def [](*args)
        to_ary[*args]
      end

      # Deletes all documents that match the current query conditions.
      #
      # This method constructs and executes a N1QL query to get the IDs of the matching documents
      # and then deletes them using the model's `remove_multi` method.
      #
      # @return [void]
      #
      # @example Delete all inactive users
      #   class User < Couchbase::Base
      #
      #     def self.delete_inactive_users
      #       where(active: false).delete_all
      #     end
      #   end
      #
      #   User.delete_inactive_users
      #   # This will construct and execute the N1QL query to retrieve the IDs of all inactive users
      #   # and delete the corresponding documents.
      def delete_all
        CouchbaseOrm.logger.debug{ "Delete all: #{self}" }
        ids = query.to_a
        @model.collection.remove_multi(ids) unless ids.empty?
      end

      # Adds conditions to the query.
      #
      # This method allows you to specify query conditions using a string and/or a hash.
      # It returns a new `CouchbaseOrm_Relation` instance with the updated conditions.
      #
      # @param [String, nil] string_cond Additional conditions in a string format (optional).
      # @param [Hash] conds Conditions as key-value pairs (optional).
      # @return [CouchbaseOrm_Relation] A new relation instance with the updated conditions.
      #
      # @example Find all active users with a specific role
      #   class User < Couchbase::Base
      #
      #     def self.active_with_role(role)
      #       where(active: true).where(role: role)
      #     end
      #   end
      #
      #   active_admins = User.active_with_role('admin')
      #   # This will create a query with conditions for active users with the role 'admin'
      #   # and return a new `CouchbaseOrm_Relation` instance with these conditions.
      def where(string_cond = nil, **conds)
        CouchbaseOrm_Relation.new(**initializer_arguments.merge(where: merge_where(conds) + string_where(string_cond)))
      end

      # Finds the first record that matches the given conditions.
      #
      # This method constructs a query with the specified conditions and returns the first matching record.
      #
      # @param [Hash] conds Conditions as key-value pairs.
      # @return [Object, nil] The first record that matches the conditions, or nil if no record matches.
      #
      # @example Find a user by email
      #   class User < Couchbase::Base
      #
      #     def self.find_by_email(email)
      #       find_by(email: email)
      #     end
      #   end
      #   user = User.find_by_email('example@example.com')
      #   # This will create a query with the condition for email and return the first matching user.
      def find_by(**conds)
        CouchbaseOrm_Relation.new(**initializer_arguments.merge(where: merge_where(conds))).first
      end

      # Adds negation conditions to the query.
      #
      # This method allows you to specify conditions that should not be matched by the query.
      # It returns a new `CouchbaseOrm_Relation` instance with the updated conditions.
      #
      # @param [Hash] conds Conditions as key-value pairs that should be negated.
      # @return [CouchbaseOrm_Relation] A new relation instance with the negated conditions.
      #
      # @example Exclude users with a specific role
      #   class User < Couchbase::Base
      #
      #     def self.exclude_role(role)
      #       not(role: role)
      #     end
      #   end
      #
      #   non_admins = User.exclude_role('admin')
      #   # This will create a query excluding users with the 'admin' role.
      def not(**conds)
        CouchbaseOrm_Relation.new(**initializer_arguments.merge(where: merge_where(conds, _not: true)))
      end

      # Specifies the order of the results for the query.
      #
      # This method allows for the specification of how query results should be ordered,
      # using both positional and named arguments. It returns a new `CouchbaseOrm_Relation` instance
      # with the updated order conditions.
      #
      # @param lorder [Array<String, Symbol>] Positional ordering parameters.
      # @param horder [Hash] Named ordering parameters with directions.
      # @return [CouchbaseOrm_Relation] A new relation instance with the updated ordering.
      #
      # @example Order users by creation date in descending order
      #   class User < Couchbase::Base
      #
      #     def self.order_by_creation_desc
      #       order(created_at: :desc)
      #     end
      #   end
      #
      #   ordered_users = User.order_by_creation_desc
      #   # This will create a query with an order condition for users ordered by 'created_at' descending.
      def order(*lorder, **horder)
        CouchbaseOrm_Relation.new(**initializer_arguments.merge(order: merge_order(*lorder, **horder)))
      end

      # Sets a limit on the number of results to be returned by the query.
      #
      # This method updates the query configuration to include a specified limit, controlling
      # the amount of data retrieved from the database. It returns a new `CouchbaseOrm_Relation`
      # instance with the updated configuration.
      #
      # @param limit [Integer] The maximum number of records to return.
      # @return [CouchbaseOrm_Relation] A new relation instance with the specified limit.
      #
      # @example Retrieve only 5 users
      #   class User < Couchbase::Base
      #
      #     def self.find_top_five
      #       limit(5)
      #     end
      #   end
      #
      #   top_five_users = User.find_top_five
      #   # This will return only the first five user records from the query.
      def limit(limit)
        CouchbaseOrm_Relation.new(**initializer_arguments.merge(limit: limit))
      end

      # Initializes a new query relation to fetch all records from the database.
      #
      # This method creates a new `CouchbaseOrm_Relation` instance, setting the stage for a query that can
      # fetch all records. It serves as a base that can be extended with further conditions, limits, orders, etc.
      #
      # @return [CouchbaseOrm_Relation] A new relation instance ready to fetch all records.
      #
      # @example Fetch all users and apply additional query conditions
      #   class User < Couchbase::Base
      #
      #     def self.fetch_all_active_users
      #       all.where(active: true).order(created_at: :desc)
      #     end
      #   end
      #
      #   active_users = User.fetch_all_active_users
      #   # This initializes a query to fetch all users, then narrows it down to active users,
      #   # and orders them by their creation date in descending order.
      def all
        CouchbaseOrm_Relation.new(**initializer_arguments)
      end

      # Temporarily modifies the query scope within a block of code in a thread-safe manner.
      #
      # This method is used to apply temporary query conditions which are only meant to last
      # during the execution of the given block. It ensures that the scope is added before
      # the block is executed and properly removed afterward, even if an exception occurs.
      #
      # @yield The block during which the temporary scope should be applied.
      # @return [Object] The result of the block execution.
      #
      # @example Apply a temporary scope to increase salary for specific calculations
      #   class Employee  < Couchbase::Base
      #
      #     def self.temporary_increase(factor)
      #       scoping do
      #         where(salary: salary.map { |s| s * factor })
      #         # Other operations that depend on this temporary scope
      #       end
      #     end
      #   end
      #
      #   Employee.temporary_increase(1.10)
      #   # This will temporarily increase the salary by 10% within the block, for whatever operations are needed.
      def scoping
        scopes = (Thread.current[@model.name] ||= [])
        scopes.push(self)
        result = yield
      ensure
        scopes.pop
        result
      end

      private

      def build_limit
        @limit ? "limit #{@limit}" : ''
      end

      def initializer_arguments
        { model: @model, order: @order, where: @where, limit: @limit }
      end

      def merge_order(*lorder, **horder)
        raise ArgumentError.new("invalid order passed by list: #{lorder.inspect}, must be symbols") unless lorder.all? { |o|
                                                                                                             o.is_a? Symbol
                                                                                                           }
        raise ArgumentError.new("Invalid order passed by hash: #{horder.inspect}, must be symbol -> :asc|:desc") unless horder.all? { |k, v|
                                                                                                                          k.is_a?(Symbol) && [
:asc, :desc
].include?(v)
                                                                                                                        }

        @order
          .merge(Array.wrap(lorder).map{ |o| [o, :asc] }.to_h)
          .merge(horder)
      end

      def merge_where(conds, _not = false)
        @where + (_not ? conds.to_a.map{ |k, v| [k, v, :not] } : conds.to_a)
      end

      def string_where(string_cond, _not = false)
        return [] unless string_cond

        cond = "(#{string_cond})"
        [(_not ? [nil, cond, :not] : [nil, cond])]
      end

      def build_order
        order = @order.map do |key, value|
          "#{key} #{value}"
        end.join(', ')
        order.empty? ? 'meta().id' : order
      end

      def build_where
        build_conds([[:type, @model.design_document]] + @where)
      end

      def build_conds(conds)
        conds.map do |key, value, opt|
          if key
            opt == :not ?
                @model.build_not_match(key, value) :
                @model.build_match(key, value)
          else
            value
          end
        end.join(' AND ')
      end

      def build_update(**cond)
        cond.map do |key, value|
          for_clause = ''
          if value.is_a?(Hash) && value[:_for]
            path_clause = value.delete(:_for)
            var_clause = path_clause.to_s.split('.').last.singularize

            _when = value.delete(:_when)
            when_clause = _when ? build_conds(_when.to_a) : ''

            _set = value.delete(:_set)
            value = _set if _set

            for_clause = " for #{var_clause} in #{path_clause} when #{when_clause} end"
          end
          if value.is_a?(Hash)
            value.map do |k, v|
              "#{key}.#{k} = #{v}"
            end.join(', ') + for_clause
          else
            "#{key} = #{@model.quote(value)}#{for_clause}"
          end
        end.join(', ')
      end

      def method_missing(method, *args, &block)
        if @model.respond_to?(method)
          scoping {
            @model.public_send(method, *args, &block)
          }
        else
          super
        end
      end
    end

    module ClassMethods
      def relation
        Thread.current[self.name]&.last || CouchbaseOrm_Relation.new(model: self)
      end

      delegate :ids, :update_all, :delete_all, :count, :empty?, :filter, :reduce, :find_by, to: :all

      delegate :where, :not, :order, :limit, :all, to: :relation
    end
  end
end
