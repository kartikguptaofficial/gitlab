# frozen_string_literal: true

module Gitlab
  module Database
    module SchemaValidation
      module Validators
        class ExtraTables < BaseValidator
          ERROR_MESSAGE = "The table %s is present in the database, but not in the structure.sql file"

          def execute
            database.tables.filter_map do |database_table|
              next if structure_sql.table_exists?(database_table.name)

              build_inconsistency(self.class, nil, database_table)
            end
          end
        end
      end
    end
  end
end
