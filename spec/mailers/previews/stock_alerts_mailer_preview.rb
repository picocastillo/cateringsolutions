# Preview all emails at http://localhost:3000/rails/mailers/stock_alerts_mailer
class StockAlertsMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/stock_alerts_mailer/daily_report
  delegate :daily_report, to: :StockAlertsMailer
end
