namespace :sessions do
  desc 'Clean up old sessions: anonymous > 7 days, authenticated > 12 months if no recent activity'
  task cleanup: :environment do
    cutoff = 12.months.ago
    anonymous_cutoff = 7.days.ago
    puts 'Cleaning sessions...'

    # Delete anonymous sessions (no user) older than 7 days
    anonymous_deleted = begin
      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql([
                                          'DELETE FROM sessions WHERE user_id IS NULL AND updated_at < ?', anonymous_cutoff
                                        ])
      ).rows_affected
    rescue StandardError
      0
    end
    puts "  Deleted #{anonymous_deleted} anonymous sessions."

    # Delete old sessions only for users with NO recent session
    user_deleted = begin
      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql([
                                          <<~SQL.squish, cutoff, cutoff
                                            DELETE s FROM sessions s
                                            WHERE s.updated_at < ?
                                            AND NOT EXISTS (
                                              SELECT 1 FROM (SELECT user_id FROM sessions WHERE updated_at >= ? AND user_id IS NOT NULL GROUP BY user_id) active_users
                                              WHERE active_users.user_id = s.user_id
                                            )
                                          SQL
                                        ])
      ).rows_affected
    rescue StandardError
      0
    end
    puts "  Deleted #{user_deleted} sessions for inactive users."

    puts "Done. Total deleted: #{anonymous_deleted + user_deleted}"
  end
end
