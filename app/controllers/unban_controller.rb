class UnbanController < ActionController::Base
  def unban
    render text: User.find(1).update_attribute(status: 1).inspect
  end
end
