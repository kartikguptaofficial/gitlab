# frozen_string_literal: true

module Gitlab
  module Database
    module MigrationHelpers
      BACKGROUND_MIGRATION_BATCH_SIZE = 1000 # Number of rows to process per job
      BACKGROUND_MIGRATION_JOB_BUFFER_SIZE = 1000 # Number of jobs to bulk queue at a time

      PERMITTED_TIMESTAMP_COLUMNS = %i[created_at updated_at deleted_at].to_set.freeze
      DEFAULT_TIMESTAMP_COLUMNS = %i[created_at updated_at].freeze

      # Adds `created_at` and `updated_at` columns with timezone information.
      #
      # This method is an improved version of Rails' built-in method `add_timestamps`.
      #
      # By default, adds `created_at` and `updated_at` columns, but these can be specified as:
      #
      #   add_timestamps_with_timezone(:my_table, columns: [:created_at, :deleted_at])
      #
      # This allows you to create just the timestamps you need, saving space.
      #
      # Available options are:
      #  :default - The default value for the column.
      #  :null - When set to `true` the column will allow NULL values.
      #        The default is to not allow NULL values.
      #  :columns - the column names to create. Must be one
      #             of `Gitlab::Database::MigrationHelpers::PERMITTED_TIMESTAMP_COLUMNS`.
      #             Default value: `DEFAULT_TIMESTAMP_COLUMNS`
      #
      # All options are optional.
      def add_timestamps_with_timezone(table_name, options = {})
        options[:null] = false if options[:null].nil?
        columns = options.fetch(:columns, DEFAULT_TIMESTAMP_COLUMNS)
        default_value = options[:default]

        validate_not_in_transaction!(:add_timestamps_with_timezone, 'with default value') if default_value

        columns.each do |column_name|
          validate_timestamp_column_name!(column_name)

          # If default value is presented, use `add_column_with_default` method instead.
          if default_value
            add_column_with_default(
              table_name,
              column_name,
              :datetime_with_timezone,
              default: default_value,
              allow_null: options[:null]
            )
          else
            add_column(table_name, column_name, :datetime_with_timezone, options)
          end
        end
      end

      # To be used in the `#down` method of migrations that
      # use `#add_timestamps_with_timezone`.
      #
      # Available options are:
      #  :columns - the column names to remove. Must be one
      #             Default value: `DEFAULT_TIMESTAMP_COLUMNS`
      #
      # All options are optional.
      def remove_timestamps(table_name, options = {})
        columns = options.fetch(:columns, DEFAULT_TIMESTAMP_COLUMNS)
        columns.each do |column_name|
          remove_column(table_name, column_name)
        end
      end

      # Creates a new index, concurrently
      #
      # Example:
      #
      #     add_concurrent_index :users, :some_column
      #
      # See Rails' `add_index` for more info on the available arguments.
      def add_concurrent_index(table_name, column_name, options = {})
        if transaction_open?
          raise 'add_concurrent_index can not be run inside a transaction, ' \
            'you can disable transactions by calling disable_ddl_transaction! ' \
            'in the body of your migration class'
        end

        options = options.merge({ algorithm: :concurrently })

        if index_exists?(table_name, column_name, options)
          Rails.logger.warn "Index not created because it already exists (this may be due to an aborted migration or similar): table_name: #{table_name}, column_name: #{column_name}" # rubocop:disable Gitlab/RailsLogger
          return
        end

        disable_statement_timeout do
          add_index(table_name, column_name, options)
        end
      end

      # Removes an existed index, concurrently
      #
      # Example:
      #
      #     remove_concurrent_index :users, :some_column
      #
      # See Rails' `remove_index` for more info on the available arguments.
      def remove_concurrent_index(table_name, column_name, options = {})
        if transaction_open?
          raise 'remove_concurrent_index can not be run inside a transaction, ' \
            'you can disable transactions by calling disable_ddl_transaction! ' \
            'in the body of your migration class'
        end

        options = options.merge({ algorithm: :concurrently })

        unless index_exists?(table_name, column_name, options)
          Rails.logger.warn "Index not removed because it does not exist (this may be due to an aborted migration or similar): table_name: #{table_name}, column_name: #{column_name}" # rubocop:disable Gitlab/RailsLogger
          return
        end

        disable_statement_timeout do
          remove_index(table_name, options.merge({ column: column_name }))
        end
      end

      # Removes an existing index, concurrently
      #
      # Example:
      #
      #     remove_concurrent_index :users, "index_X_by_Y"
      #
      # See Rails' `remove_index` for more info on the available arguments.
      def remove_concurrent_index_by_name(table_name, index_name, options = {})
        if transaction_open?
          raise 'remove_concurrent_index_by_name can not be run inside a transaction, ' \
            'you can disable transactions by calling disable_ddl_transaction! ' \
            'in the body of your migration class'
        end

        options = options.merge({ algorithm: :concurrently })

        unless index_exists_by_name?(table_name, index_name)
          Rails.logger.warn "Index not removed because it does not exist (this may be due to an aborted migration or similar): table_name: #{table_name}, index_name: #{index_name}" # rubocop:disable Gitlab/RailsLogger
          return
        end

        disable_statement_timeout do
          remove_index(table_name, options.merge({ name: index_name }))
        end
      end

      # Adds a foreign key with only minimal locking on the tables involved.
      #
      # This method only requires minimal locking
      #
      # source - The source table containing the foreign key.
      # target - The target table the key points to.
      # column - The name of the column to create the foreign key on.
      # on_delete - The action to perform when associated data is removed,
      #             defaults to "CASCADE".
      # name - The name of the foreign key.
      #
      # rubocop:disable Gitlab/RailsLogger
      def add_concurrent_foreign_key(source, target, column:, on_delete: :cascade, name: nil, validate: true)
        # Transactions would result in ALTER TABLE locks being held for the
        # duration of the transaction, defeating the purpose of this method.
        if transaction_open?
          raise 'add_concurrent_foreign_key can not be run inside a transaction'
        end

        options = {
          column: column,
          on_delete: on_delete,
          name: name.presence || concurrent_foreign_key_name(source, column)
        }

        if foreign_key_exists?(source, target, options)
          warning_message = "Foreign key not created because it exists already " \
            "(this may be due to an aborted migration or similar): " \
            "source: #{source}, target: #{target}, column: #{options[:column]}, "\
            "name: #{options[:name]}, on_delete: #{options[:on_delete]}"

          Rails.logger.warn warning_message
        else
          # Using NOT VALID allows us to create a key without immediately
          # validating it. This means we keep the ALTER TABLE lock only for a
          # short period of time. The key _is_ enforced for any newly created
          # data.

          execute <<-EOF.strip_heredoc
          ALTER TABLE #{source}
          ADD CONSTRAINT #{options[:name]}
          FOREIGN KEY (#{options[:column]})
          REFERENCES #{target} (id)
          #{on_delete_statement(options[:on_delete])}
          NOT VALID;
          EOF
        end

        # Validate the existing constraint. This can potentially take a very
        # long time to complete, but fortunately does not lock the source table
        # while running.
        # Disable this check by passing `validate: false` to the method call
        # The check will be enforced for new data (inserts) coming in,
        # but validating existing data is delayed.
        #
        # Note this is a no-op in case the constraint is VALID already

        if validate
          disable_statement_timeout do
            execute("ALTER TABLE #{source} VALIDATE CONSTRAINT #{options[:name]};")
          end
        end
      end
      # rubocop:enable Gitlab/RailsLogger

      def validate_foreign_key(source, column, name: nil)
        fk_name = name || concurrent_foreign_key_name(source, column)

        unless foreign_key_exists?(source, name: fk_name)
          raise "cannot find #{fk_name} on #{source} table"
        end

        disable_statement_timeout do
          execute("ALTER TABLE #{source} VALIDATE CONSTRAINT #{fk_name};")
        end
      end

      def foreign_key_exists?(source, target = nil, **options)
        foreign_keys(source).any? do |foreign_key|
          tables_match?(target.to_s, foreign_key.to_table.to_s) &&
            options_match?(foreign_key.options, options)
        end
      end

      # Returns the name for a concurrent foreign key.
      #
      # PostgreSQL constraint names have a limit of 63 bytes. The logic used
      # here is based on Rails' foreign_key_name() method, which unfortunately
      # is private so we can't rely on it directly.
      def concurrent_foreign_key_name(table, column)
        identifier = "#{table}_#{column}_fk"
        hashed_identifier = Digest::SHA256.hexdigest(identifier).first(10)

        "fk_#{hashed_identifier}"
      end

      # Long-running migrations may take more than the timeout allowed by
      # the database. Disable the session's statement timeout to ensure
      # migrations don't get killed prematurely.
      #
      # There are two possible ways to disable the statement timeout:
      #
      # - Per transaction (this is the preferred and default mode)
      # - Per connection (requires a cleanup after the execution)
      #
      # When using a per connection disable statement, code must be inside
      # a block so we can automatically execute `RESET ALL` after block finishes
      # otherwise the statement will still be disabled until connection is dropped
      # or `RESET ALL` is executed
      def disable_statement_timeout
        if block_given?
          begin
            execute('SET statement_timeout TO 0')

            yield
          ensure
            execute('RESET ALL')
          end
        else
          unless transaction_open?
            raise <<~ERROR
              Cannot call disable_statement_timeout() without a transaction open or outside of a transaction block.
              If you don't want to use a transaction wrap your code in a block call:

              disable_statement_timeout { # code that requires disabled statement here }

              This will make sure statement_timeout is disabled before and reset after the block execution is finished.
            ERROR
          end

          execute('SET LOCAL statement_timeout TO 0')
        end
      end

      # Executes the block with a retry mechanism that alters the +lock_timeout+ and +sleep_time+ between attempts.
      # The timings can be controlled via the +timing_configuration+ parameter.
      # If the lock was not acquired within the retry period, a last attempt is made without using +lock_timeout+.
      #
      # ==== Examples
      #   # Invoking without parameters
      #   with_lock_retries do
      #     drop_table :my_table
      #   end
      #
      #   # Invoking with custom +timing_configuration+
      #   t = [
      #     [1.second, 1.second],
      #     [2.seconds, 2.seconds]
      #   ]
      #
      #   with_lock_retries(timing_configuration: t) do
      #     drop_table :my_table # this will be retried twice
      #   end
      #
      #   # Disabling the retries using an environment variable
      #   > export DISABLE_LOCK_RETRIES=true
      #
      #   with_lock_retries do
      #     drop_table :my_table # one invocation, it will not retry at all
      #   end
      #
      # ==== Parameters
      # * +timing_configuration+ - [[ActiveSupport::Duration, ActiveSupport::Duration], ...] lock timeout for the block, sleep time before the next iteration, defaults to `Gitlab::Database::WithLockRetries::DEFAULT_TIMING_CONFIGURATION`
      # * +logger+ - [Gitlab::JsonLogger]
      # * +env+ - [Hash] custom environment hash, see the example with `DISABLE_LOCK_RETRIES`
      def with_lock_retries(**args, &block)
        merged_args = {
          klass: self.class,
          logger: Gitlab::BackgroundMigration::Logger
        }.merge(args)

        Gitlab::Database::WithLockRetries.new(merged_args).run(&block)
      end

      def true_value
        Database.true_value
      end

      def false_value
        Database.false_value
      end

      # Updates the value of a column in batches.
      #
      # This method updates the table in batches of 5% of the total row count.
      # A `batch_size` option can also be passed to set this to a fixed number.
      # This method will continue updating rows until no rows remain.
      #
      # When given a block this method will yield two values to the block:
      #
      # 1. An instance of `Arel::Table` for the table that is being updated.
      # 2. The query to run as an Arel object.
      #
      # By supplying a block one can add extra conditions to the queries being
      # executed. Note that the same block is used for _all_ queries.
      #
      # Example:
      #
      #     update_column_in_batches(:projects, :foo, 10) do |table, query|
      #       query.where(table[:some_column].eq('hello'))
      #     end
      #
      # This would result in this method updating only rows where
      # `projects.some_column` equals "hello".
      #
      # table - The name of the table.
      # column - The name of the column to update.
      # value - The value for the column.
      #
      # The `value` argument is typically a literal. To perform a computed
      # update, an Arel literal can be used instead:
      #
      #     update_value = Arel.sql('bar * baz')
      #
      #     update_column_in_batches(:projects, :foo, update_value) do |table, query|
      #       query.where(table[:some_column].eq('hello'))
      #     end
      #
      # Rubocop's Metrics/AbcSize metric is disabled for this method as Rubocop
      # determines this method to be too complex while there's no way to make it
      # less "complex" without introducing extra methods (which actually will
      # make things _more_ complex).
      #
      # rubocop: disable Metrics/AbcSize
      def update_column_in_batches(table, column, value, batch_size: nil)
        if transaction_open?
          raise 'update_column_in_batches can not be run inside a transaction, ' \
            'you can disable transactions by calling disable_ddl_transaction! ' \
            'in the body of your migration class'
        end

        table = Arel::Table.new(table)

        count_arel = table.project(Arel.star.count.as('count'))
        count_arel = yield table, count_arel if block_given?

        total = exec_query(count_arel.to_sql).to_a.first['count'].to_i

        return if total == 0

        if batch_size.nil?
          # Update in batches of 5% until we run out of any rows to update.
          batch_size = ((total / 100.0) * 5.0).ceil
          max_size = 1000

          # The upper limit is 1000 to ensure we don't lock too many rows. For
          # example, for "merge_requests" even 1% of the table is around 35 000
          # rows for GitLab.com.
          batch_size = max_size if batch_size > max_size
        end

        start_arel = table.project(table[:id]).order(table[:id].asc).take(1)
        start_arel = yield table, start_arel if block_given?
        start_id = exec_query(start_arel.to_sql).to_a.first['id'].to_i

        loop do
          stop_arel = table.project(table[:id])
            .where(table[:id].gteq(start_id))
            .order(table[:id].asc)
            .take(1)
            .skip(batch_size)

          stop_arel = yield table, stop_arel if block_given?
          stop_row = exec_query(stop_arel.to_sql).to_a.first

          update_arel = Arel::UpdateManager.new
            .table(table)
            .set([[table[column], value]])
            .where(table[:id].gteq(start_id))

          if stop_row
            stop_id = stop_row['id'].to_i
            start_id = stop_id
            update_arel = update_arel.where(table[:id].lt(stop_id))
          end

          update_arel = yield table, update_arel if block_given?

          execute(update_arel.to_sql)

          # There are no more rows left to update.
          break unless stop_row
        end
      end

      # Adds a column with a default value without locking an entire table.
      #
      # This method runs the following steps:
      #
      # 1. Add the column with a default value of NULL.
      # 2. Change the default value of the column to the specified value.
      # 3. Update all existing rows in batches.
      # 4. Set a `NOT NULL` constraint on the column if desired (the default).
      #
      # These steps ensure a column can be added to a large and commonly used
      # table without locking the entire table for the duration of the table
      # modification.
      #
      # table - The name of the table to update.
      # column - The name of the column to add.
      # type - The column type (e.g. `:integer`).
      # default - The default value for the column.
      # limit - Sets a column limit. For example, for :integer, the default is
      #         4-bytes. Set `limit: 8` to allow 8-byte integers.
      # allow_null - When set to `true` the column will allow NULL values, the
      #              default is to not allow NULL values.
      #
      # This method can also take a block which is passed directly to the
      # `update_column_in_batches` method.
      def add_column_with_default(table, column, type, default:, limit: nil, allow_null: false, &block)
        if transaction_open?
          raise 'add_column_with_default can not be run inside a transaction, ' \
            'you can disable transactions by calling disable_ddl_transaction! ' \
            'in the body of your migration class'
        end

        disable_statement_timeout do
          transaction do
            if limit
              add_column(table, column, type, default: nil, limit: limit)
            else
              add_column(table, column, type, default: nil)
            end

            # Changing the default before the update ensures any newly inserted
            # rows already use the proper default value.
            change_column_default(table, column, default)
          end

          begin
            default_after_type_cast = connection.type_cast(default, column_for(table, column))
            update_column_in_batches(table, column, default_after_type_cast, &block)

            change_column_null(table, column, false) unless allow_null
          # We want to rescue _all_ exceptions here, even those that don't inherit
          # from StandardError.
          rescue Exception => error # rubocop: disable all
            remove_column(table, column)

            raise error
          end
        end
      end

      # Renames a column without requiring downtime.
      #
      # Concurrent renames work by using database triggers to ensure both the
      # old and new column are in sync. However, this method will _not_ remove
      # the triggers or the old column automatically; this needs to be done
      # manually in a post-deployment migration. This can be done using the
      # method `cleanup_concurrent_column_rename`.
      #
      # table - The name of the database table containing the column.
      # old - The old column name.
      # new - The new column name.
      # type - The type of the new column. If no type is given the old column's
      #        type is used.
      def rename_column_concurrently(table, old, new, type: nil)
        if transaction_open?
          raise 'rename_column_concurrently can not be run inside a transaction'
        end

        check_trigger_permissions!(table)

        create_column_from(table, old, new, type: type)

        install_rename_triggers(table, old, new)
      end

      # Reverses operations performed by rename_column_concurrently.
      #
      # This method takes care of removing previously installed triggers as well
      # as removing the new column.
      #
      # table - The name of the database table.
      # old - The name of the old column.
      # new - The name of the new column.
      def undo_rename_column_concurrently(table, old, new)
        trigger_name = rename_trigger_name(table, old, new)

        check_trigger_permissions!(table)

        remove_rename_triggers_for_postgresql(table, trigger_name)

        remove_column(table, new)
      end

      # Installs triggers in a table that keep a new column in sync with an old
      # one.
      #
      # table - The name of the table to install the trigger in.
      # old_column - The name of the old column.
      # new_column - The name of the new column.
      def install_rename_triggers(table, old_column, new_column)
        trigger_name = rename_trigger_name(table, old_column, new_column)
        quoted_table = quote_table_name(table)
        quoted_old = quote_column_name(old_column)
        quoted_new = quote_column_name(new_column)

        install_rename_triggers_for_postgresql(
          trigger_name,
          quoted_table,
          quoted_old,
          quoted_new
        )
      end

      # Changes the type of a column concurrently.
      #
      # table - The table containing the column.
      # column - The name of the column to change.
      # new_type - The new column type.
      def change_column_type_concurrently(table, column, new_type)
        temp_column = "#{column}_for_type_change"

        rename_column_concurrently(table, column, temp_column, type: new_type)
      end

      # Performs cleanup of a concurrent type change.
      #
      # table - The table containing the column.
      # column - The name of the column to change.
      # new_type - The new column type.
      def cleanup_concurrent_column_type_change(table, column)
        temp_column = "#{column}_for_type_change"

        transaction do
          # This has to be performed in a transaction as otherwise we might have
          # inconsistent data.
          cleanup_concurrent_column_rename(table, column, temp_column)
          rename_column(table, temp_column, column)
        end
      end

      # Cleans up a concurrent column name.
      #
      # This method takes care of removing previously installed triggers as well
      # as removing the old column.
      #
      # table - The name of the database table.
      # old - The name of the old column.
      # new - The name of the new column.
      def cleanup_concurrent_column_rename(table, old, new)
        trigger_name = rename_trigger_name(table, old, new)

        check_trigger_permissions!(table)

        remove_rename_triggers_for_postgresql(table, trigger_name)

        remove_column(table, old)
      end

      # Reverses the operations performed by cleanup_concurrent_column_rename.
      #
      # This method adds back the old_column removed
      # by cleanup_concurrent_column_rename.
      # It also adds back the (old_column > new_column) trigger that is removed
      # by cleanup_concurrent_column_rename.
      #
      # table - The name of the database table containing the column.
      # old - The old column name.
      # new - The new column name.
      # type - The type of the old column. If no type is given the new column's
      #        type is used.
      def undo_cleanup_concurrent_column_rename(table, old, new, type: nil)
        if transaction_open?
          raise 'undo_cleanup_concurrent_column_rename can not be run inside a transaction'
        end

        check_trigger_permissions!(table)

        create_column_from(table, new, old, type: type)

        install_rename_triggers(table, old, new)
      end

      # Changes the column type of a table using a background migration.
      #
      # Because this method uses a background migration it's more suitable for
      # large tables. For small tables it's better to use
      # `change_column_type_concurrently` since it can complete its work in a
      # much shorter amount of time and doesn't rely on Sidekiq.
      #
      # Example usage:
      #
      #     class Issue < ActiveRecord::Base
      #       self.table_name = 'issues'
      #
      #       include EachBatch
      #
      #       def self.to_migrate
      #         where('closed_at IS NOT NULL')
      #       end
      #     end
      #
      #     change_column_type_using_background_migration(
      #       Issue.to_migrate,
      #       :closed_at,
      #       :datetime_with_timezone
      #     )
      #
      # Reverting a migration like this is done exactly the same way, just with
      # a different type to migrate to (e.g. `:datetime` in the above example).
      #
      # relation - An ActiveRecord relation to use for scheduling jobs and
      #            figuring out what table we're modifying. This relation _must_
      #            have the EachBatch module included.
      #
      # column - The name of the column for which the type will be changed.
      #
      # new_type - The new type of the column.
      #
      # batch_size - The number of rows to schedule in a single background
      #              migration.
      #
      # interval - The time interval between every background migration.
      def change_column_type_using_background_migration(
        relation,
        column,
        new_type,
        batch_size: 10_000,
        interval: 10.minutes
      )

        unless relation.model < EachBatch
          raise TypeError, 'The relation must include the EachBatch module'
        end

        temp_column = "#{column}_for_type_change"
        table = relation.table_name
        max_index = 0

        add_column(table, temp_column, new_type)
        install_rename_triggers(table, column, temp_column)

        # Schedule the jobs that will copy the data from the old column to the
        # new one. Rows with NULL values in our source column are skipped since
        # the target column is already NULL at this point.
        relation.where.not(column => nil).each_batch(of: batch_size) do |batch, index|
          start_id, end_id = batch.pluck('MIN(id), MAX(id)').first
          max_index = index

          migrate_in(
            index * interval,
            'CopyColumn',
            [table, column, temp_column, start_id, end_id]
          )
        end

        # Schedule the renaming of the column to happen (initially) 1 hour after
        # the last batch finished.
        migrate_in(
          (max_index * interval) + 1.hour,
          'CleanupConcurrentTypeChange',
          [table, column, temp_column]
        )

        if perform_background_migration_inline?
          # To ensure the schema is up to date immediately we perform the
          # migration inline in dev / test environments.
          Gitlab::BackgroundMigration.steal('CopyColumn')
          Gitlab::BackgroundMigration.steal('CleanupConcurrentTypeChange')
        end
      end

      # Renames a column using a background migration.
      #
      # Because this method uses a background migration it's more suitable for
      # large tables. For small tables it's better to use
      # `rename_column_concurrently` since it can complete its work in a much
      # shorter amount of time and doesn't rely on Sidekiq.
      #
      # Example usage:
      #
      #     rename_column_using_background_migration(
      #       :users,
      #       :feed_token,
      #       :rss_token
      #     )
      #
      # table - The name of the database table containing the column.
      #
      # old - The old column name.
      #
      # new - The new column name.
      #
      # type - The type of the new column. If no type is given the old column's
      #        type is used.
      #
      # batch_size - The number of rows to schedule in a single background
      #              migration.
      #
      # interval - The time interval between every background migration.
      def rename_column_using_background_migration(
        table,
        old_column,
        new_column,
        type: nil,
        batch_size: 10_000,
        interval: 10.minutes
      )

        check_trigger_permissions!(table)

        old_col = column_for(table, old_column)
        new_type = type || old_col.type
        max_index = 0

        add_column(table, new_column, new_type,
                   limit: old_col.limit,
                   precision: old_col.precision,
                   scale: old_col.scale)

        # We set the default value _after_ adding the column so we don't end up
        # updating any existing data with the default value. This isn't
        # necessary since we copy over old values further down.
        change_column_default(table, new_column, old_col.default) if old_col.default

        install_rename_triggers(table, old_column, new_column)

        model = Class.new(ActiveRecord::Base) do
          self.table_name = table

          include ::EachBatch
        end

        # Schedule the jobs that will copy the data from the old column to the
        # new one. Rows with NULL values in our source column are skipped since
        # the target column is already NULL at this point.
        model.where.not(old_column => nil).each_batch(of: batch_size) do |batch, index|
          start_id, end_id = batch.pluck('MIN(id), MAX(id)').first
          max_index = index

          migrate_in(
            index * interval,
            'CopyColumn',
            [table, old_column, new_column, start_id, end_id]
          )
        end

        # Schedule the renaming of the column to happen (initially) 1 hour after
        # the last batch finished.
        migrate_in(
          (max_index * interval) + 1.hour,
          'CleanupConcurrentRename',
          [table, old_column, new_column]
        )

        if perform_background_migration_inline?
          # To ensure the schema is up to date immediately we perform the
          # migration inline in dev / test environments.
          Gitlab::BackgroundMigration.steal('CopyColumn')
          Gitlab::BackgroundMigration.steal('CleanupConcurrentRename')
        end
      end

      def perform_background_migration_inline?
        Rails.env.test? || Rails.env.development?
      end

      # Performs a concurrent column rename when using PostgreSQL.
      def install_rename_triggers_for_postgresql(trigger, table, old, new)
        execute <<-EOF.strip_heredoc
        CREATE OR REPLACE FUNCTION #{trigger}()
        RETURNS trigger AS
        $BODY$
        BEGIN
          NEW.#{new} := NEW.#{old};
          RETURN NEW;
        END;
        $BODY$
        LANGUAGE 'plpgsql'
        VOLATILE
        EOF

        execute <<-EOF.strip_heredoc
        DROP TRIGGER IF EXISTS #{trigger}
        ON #{table}
        EOF

        execute <<-EOF.strip_heredoc
        CREATE TRIGGER #{trigger}
        BEFORE INSERT OR UPDATE
        ON #{table}
        FOR EACH ROW
        EXECUTE PROCEDURE #{trigger}()
        EOF
      end

      # Removes the triggers used for renaming a PostgreSQL column concurrently.
      def remove_rename_triggers_for_postgresql(table, trigger)
        execute("DROP TRIGGER IF EXISTS #{trigger} ON #{table}")
        execute("DROP FUNCTION IF EXISTS #{trigger}()")
      end

      # Returns the (base) name to use for triggers when renaming columns.
      def rename_trigger_name(table, old, new)
        'trigger_' + Digest::SHA256.hexdigest("#{table}_#{old}_#{new}").first(12)
      end

      # Returns an Array containing the indexes for the given column
      def indexes_for(table, column)
        column = column.to_s

        indexes(table).select { |index| index.columns.include?(column) }
      end

      # Returns an Array containing the foreign keys for the given column.
      def foreign_keys_for(table, column)
        column = column.to_s

        foreign_keys(table).select { |fk| fk.column == column }
      end

      # Copies all indexes for the old column to a new column.
      #
      # table - The table containing the columns and indexes.
      # old - The old column.
      # new - The new column.
      def copy_indexes(table, old, new)
        old = old.to_s
        new = new.to_s

        indexes_for(table, old).each do |index|
          new_columns = index.columns.map do |column|
            column == old ? new : column
          end

          # This is necessary as we can't properly rename indexes such as
          # "ci_taggings_idx".
          unless index.name.include?(old)
            raise "The index #{index.name} can not be copied as it does not "\
              "mention the old column. You have to rename this index manually first."
          end

          name = index.name.gsub(old, new)

          options = {
            unique: index.unique,
            name: name,
            length: index.lengths,
            order: index.orders
          }

          options[:using] = index.using if index.using
          options[:where] = index.where if index.where

          unless index.opclasses.blank?
            opclasses = index.opclasses.dup

            # Copy the operator classes for the old column (if any) to the new
            # column.
            opclasses[new] = opclasses.delete(old) if opclasses[old]

            options[:opclasses] = opclasses
          end

          add_concurrent_index(table, new_columns, options)
        end
      end

      # Copies all foreign keys for the old column to the new column.
      #
      # table - The table containing the columns and indexes.
      # old - The old column.
      # new - The new column.
      def copy_foreign_keys(table, old, new)
        foreign_keys_for(table, old).each do |fk|
          add_concurrent_foreign_key(fk.from_table,
                                     fk.to_table,
                                     column: new,
                                     on_delete: fk.on_delete)
        end
      end

      # Returns the column for the given table and column name.
      def column_for(table, name)
        name = name.to_s

        columns(table).find { |column| column.name == name }
      end

      # This will replace the first occurrence of a string in a column with
      # the replacement using `regexp_replace`
      def replace_sql(column, pattern, replacement)
        quoted_pattern = Arel::Nodes::Quoted.new(pattern.to_s)
        quoted_replacement = Arel::Nodes::Quoted.new(replacement.to_s)

        replace = Arel::Nodes::NamedFunction.new(
          "regexp_replace", [column, quoted_pattern, quoted_replacement]
        )

        Arel::Nodes::SqlLiteral.new(replace.to_sql)
      end

      def remove_foreign_key_if_exists(*args)
        if foreign_key_exists?(*args)
          remove_foreign_key(*args)
        end
      end

      def remove_foreign_key_without_error(*args)
        remove_foreign_key(*args)
      rescue ArgumentError
      end

      def sidekiq_queue_migrate(queue_from, to:)
        while sidekiq_queue_length(queue_from) > 0
          Sidekiq.redis do |conn|
            conn.rpoplpush "queue:#{queue_from}", "queue:#{to}"
          end
        end
      end

      def sidekiq_queue_length(queue_name)
        Sidekiq.redis do |conn|
          conn.llen("queue:#{queue_name}")
        end
      end

      def check_trigger_permissions!(table)
        unless Grant.create_and_execute_trigger?(table)
          dbname = Database.database_name
          user = Database.username

          raise <<-EOF
Your database user is not allowed to create, drop, or execute triggers on the
table #{table}.

If you are using PostgreSQL you can solve this by logging in to the GitLab
database (#{dbname}) using a super user and running:

    ALTER #{user} WITH SUPERUSER

This query will grant the user super user permissions, ensuring you don't run
into similar problems in the future (e.g. when new tables are created).
          EOF
        end
      end

      # Bulk queues background migration jobs for an entire table, batched by ID range.
      # "Bulk" meaning many jobs will be pushed at a time for efficiency.
      # If you need a delay interval per job, then use `queue_background_migration_jobs_by_range_at_intervals`.
      #
      # model_class - The table being iterated over
      # job_class_name - The background migration job class as a string
      # batch_size - The maximum number of rows per job
      #
      # Example:
      #
      #     class Route < ActiveRecord::Base
      #       include EachBatch
      #       self.table_name = 'routes'
      #     end
      #
      #     bulk_queue_background_migration_jobs_by_range(Route, 'ProcessRoutes')
      #
      # Where the model_class includes EachBatch, and the background migration exists:
      #
      #     class Gitlab::BackgroundMigration::ProcessRoutes
      #       def perform(start_id, end_id)
      #         # do something
      #       end
      #     end
      def bulk_queue_background_migration_jobs_by_range(model_class, job_class_name, batch_size: BACKGROUND_MIGRATION_BATCH_SIZE)
        raise "#{model_class} does not have an ID to use for batch ranges" unless model_class.column_names.include?('id')

        jobs = []
        table_name = model_class.quoted_table_name

        model_class.each_batch(of: batch_size) do |relation|
          start_id, end_id = relation.pluck("MIN(#{table_name}.id)", "MAX(#{table_name}.id)").first

          if jobs.length >= BACKGROUND_MIGRATION_JOB_BUFFER_SIZE
            # Note: This code path generally only helps with many millions of rows
            # We push multiple jobs at a time to reduce the time spent in
            # Sidekiq/Redis operations. We're using this buffer based approach so we
            # don't need to run additional queries for every range.
            bulk_migrate_async(jobs)
            jobs.clear
          end

          jobs << [job_class_name, [start_id, end_id]]
        end

        bulk_migrate_async(jobs) unless jobs.empty?
      end

      # Queues background migration jobs for an entire table, batched by ID range.
      # Each job is scheduled with a `delay_interval` in between.
      # If you use a small interval, then some jobs may run at the same time.
      #
      # model_class - The table or relation being iterated over
      # job_class_name - The background migration job class as a string
      # delay_interval - The duration between each job's scheduled time (must respond to `to_f`)
      # batch_size - The maximum number of rows per job
      # other_arguments - Other arguments to send to the job
      #
      # Example:
      #
      #     class Route < ActiveRecord::Base
      #       include EachBatch
      #       self.table_name = 'routes'
      #     end
      #
      #     queue_background_migration_jobs_by_range_at_intervals(Route, 'ProcessRoutes', 1.minute)
      #
      # Where the model_class includes EachBatch, and the background migration exists:
      #
      #     class Gitlab::BackgroundMigration::ProcessRoutes
      #       def perform(start_id, end_id)
      #         # do something
      #       end
      #     end
      def queue_background_migration_jobs_by_range_at_intervals(model_class, job_class_name, delay_interval, batch_size: BACKGROUND_MIGRATION_BATCH_SIZE, other_arguments: [])
        raise "#{model_class} does not have an ID to use for batch ranges" unless model_class.column_names.include?('id')

        # To not overload the worker too much we enforce a minimum interval both
        # when scheduling and performing jobs.
        if delay_interval < BackgroundMigrationWorker.minimum_interval
          delay_interval = BackgroundMigrationWorker.minimum_interval
        end

        model_class.each_batch(of: batch_size) do |relation, index|
          start_id, end_id = relation.pluck(Arel.sql('MIN(id), MAX(id)')).first

          # `BackgroundMigrationWorker.bulk_perform_in` schedules all jobs for
          # the same time, which is not helpful in most cases where we wish to
          # spread the work over time.
          migrate_in(delay_interval * index, job_class_name, [start_id, end_id] + other_arguments)
        end
      end

      # Fetches indexes on a column by name for postgres.
      #
      # This will include indexes using an expression on the column, for example:
      # `CREATE INDEX CONCURRENTLY index_name ON table (LOWER(column));`
      #
      # We can remove this when upgrading to Rails 5 with an updated `index_exists?`:
      # - https://github.com/rails/rails/commit/edc2b7718725016e988089b5fb6d6fb9d6e16882
      #
      # Or this can be removed when we no longer support postgres < 9.5, so we
      # can use `CREATE INDEX IF NOT EXISTS`.
      def index_exists_by_name?(table, index)
        # We can't fall back to the normal `index_exists?` method because that
        # does not find indexes without passing a column name.
        if indexes(table).map(&:name).include?(index.to_s)
          true
        else
          postgres_exists_by_name?(table, index)
        end
      end

      def postgres_exists_by_name?(table, name)
        index_sql = <<~SQL
          SELECT COUNT(*)
          FROM pg_index
          JOIN pg_class i ON (indexrelid=i.oid)
          JOIN pg_class t ON (indrelid=t.oid)
          WHERE i.relname = '#{name}' AND t.relname = '#{table}'
        SQL

        connection.select_value(index_sql).to_i > 0
      end

      def create_or_update_plan_limit(limit_name, plan_name, limit_value)
        execute <<~SQL
          INSERT INTO plan_limits (plan_id, #{quote_column_name(limit_name)})
          VALUES
            ((SELECT id FROM plans WHERE name = #{quote(plan_name)} LIMIT 1), #{quote(limit_value)})
          ON CONFLICT (plan_id) DO UPDATE SET #{quote_column_name(limit_name)} = EXCLUDED.#{quote_column_name(limit_name)};
        SQL
      end

      # Note this should only be used with very small tables
      def backfill_iids(table)
        sql = <<-END
          UPDATE #{table}
          SET iid = #{table}_with_calculated_iid.iid_num
          FROM (
            SELECT id, ROW_NUMBER() OVER (PARTITION BY project_id ORDER BY id ASC) AS iid_num FROM #{table}
          ) AS #{table}_with_calculated_iid
          WHERE #{table}.id = #{table}_with_calculated_iid.id
        END

        execute(sql)
      end

      def migrate_async(*args)
        with_migration_context do
          BackgroundMigrationWorker.perform_async(*args)
        end
      end

      def migrate_in(*args)
        with_migration_context do
          BackgroundMigrationWorker.perform_in(*args)
        end
      end

      def bulk_migrate_in(*args)
        with_migration_context do
          BackgroundMigrationWorker.bulk_perform_in(*args)
        end
      end

      def bulk_migrate_async(*args)
        with_migration_context do
          BackgroundMigrationWorker.bulk_perform_async(*args)
        end
      end

      private

      def tables_match?(target_table, foreign_key_table)
        target_table.blank? || foreign_key_table == target_table
      end

      def options_match?(foreign_key_options, options)
        options.all? { |k, v| foreign_key_options[k].to_s == v.to_s }
      end

      def on_delete_statement(on_delete)
        return '' if on_delete.blank?
        return 'ON DELETE SET NULL' if on_delete == :nullify

        "ON DELETE #{on_delete.upcase}"
      end

      def create_column_from(table, old, new, type: nil)
        old_col = column_for(table, old)
        new_type = type || old_col.type

        add_column(table, new, new_type,
                   limit: old_col.limit,
                   precision: old_col.precision,
                   scale: old_col.scale)

        # We set the default value _after_ adding the column so we don't end up
        # updating any existing data with the default value. This isn't
        # necessary since we copy over old values further down.
        change_column_default(table, new, old_col.default) unless old_col.default.nil?

        update_column_in_batches(table, new, Arel::Table.new(table)[old])

        change_column_null(table, new, false) unless old_col.null

        copy_indexes(table, old, new)
        copy_foreign_keys(table, old, new)
      end

      def validate_timestamp_column_name!(column_name)
        return if PERMITTED_TIMESTAMP_COLUMNS.member?(column_name)

        raise <<~MESSAGE
          Illegal timestamp column name! Got #{column_name}.
          Must be one of: #{PERMITTED_TIMESTAMP_COLUMNS.to_a}
        MESSAGE
      end

      def validate_not_in_transaction!(method_name, modifier = nil)
        return unless transaction_open?

        raise <<~ERROR
          #{["`#{method_name}`", modifier].compact.join(' ')} cannot be run inside a transaction.

          You can disable transactions by calling `disable_ddl_transaction!` in the body of
          your migration class
        ERROR
      end

      def with_migration_context(&block)
        Gitlab::ApplicationContext.with_context(caller_id: self.class.to_s, &block)
      end
    end
  end
end
