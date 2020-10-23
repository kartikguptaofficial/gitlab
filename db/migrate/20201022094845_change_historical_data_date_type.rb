# frozen_string_literal: true

class ChangeHistoricalDataDateType < ActiveRecord::Migration[6.0]
  DOWNTIME = false

  def up
    # historical_data only contains 1059 rows in gitlab.com. A new row is added
    # once a day (at 12) by a cronjob (HistoricalDataWorker).
    # Self-managed GitLab instances will probably have even less data, since gitlab.com
    # is one of the oldest GitLab instances.

    # We're using `Time.zone.tzinfo.name` here because the sidekiq-cron gem
    # evaluates crons against the timezone configured in Rails.
    execute(
      <<SQL
      ALTER TABLE historical_data ALTER COLUMN date TYPE timestamptz USING ((date + '12:00'::time) AT TIME ZONE '#{Time.zone.tzinfo.name}');
SQL
    )
  end

  def down
    change_column :historical_data, :date, :date
  end
end
