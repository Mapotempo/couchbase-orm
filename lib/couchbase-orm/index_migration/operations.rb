# frozen_string_literal: true

module CouchbaseOrm
  class IndexMigration
    module Operations
      class CreateIndex
        attr_reader :index_definition

        def initialize(index_definition)
          @index_definition = index_definition
        end

        def execute(migration)
          migration.execute_query(migration.query_builder.create_index(index_definition))
        end

        def inverse
          RemoveIndex.new(index_definition.name)
        end
      end

      class BuildIndexes
        attr_reader :index_names, :wait

        def initialize(index_names, wait: false)
          @index_names = Array(index_names).flatten
          @wait = wait
          raise ArgumentError.new('At least one index name is required') if @index_names.empty?
        end

        def execute(migration)
          migration.execute_query(migration.query_builder.build_indexes(index_names))
          migration.wait_for_indexes_online(index_names) if wait
        end

        def inverse
          raise IrreversibleMigration.new('build_indexes is not reversible. Define down explicitly.')
        end
      end

      class RemoveIndex
        attr_reader :name

        def initialize(name)
          @name = name
        end

        def execute(migration)
          migration.execute_query(migration.query_builder.remove_index(name))
        end

        def inverse
          raise IrreversibleMigration.new('remove_index is not reversible. Define down explicitly.')
        end
      end

      AddIndex = CreateIndex
    end
  end
end
