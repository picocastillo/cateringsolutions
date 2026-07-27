class AddDelayedJobsStatsToMetricasSnapshots < ActiveRecord::Migration[5.2]
  def change
    add_column :metricas_snapshots, :delayed_jobs_stats, :text, after: :worst_response_times
  end
end
