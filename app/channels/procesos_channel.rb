class ProcesosChannel < ApplicationCable::Channel
  def subscribed
    if current_user
      stream_from "procesos_#{current_user.id}"
    elsif Rails.env.production?
      reject
    end
  end

  def unsubscribed; end
end
