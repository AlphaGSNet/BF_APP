class Api::V1::Pub::NotificationsController  < Api::V1::BaseController
  helper_method :trackable_object_partial

  def index
    @notifications_checked_at = current_user.notifications_checked_at
    @activities = current_user.notifications_received.includes([:recipient, :owner, :trackable]).page(params[:page]).per(params[:per_page]).where.not(key: 'user.birthday')
    current_user.update_column :notifications_checked_at, Time.now
  end

  private

  def trackable_object_partial activity
    if %w(Content Comment Recommend).include?(activity.trackable_type)
      activity.trackable_type.downcase
    end
  end
end
