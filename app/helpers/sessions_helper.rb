module SessionsHelper

  def sign_in(user)
    session[:remember_token] = [user.key, user.salt]
    self.current_user = user
  end

  def current_user=(user)
    @current_user = user
  end

  def current_user
    @current_user ||= user_from_remember_token
  end

  def signed_in?
    !current_user.nil?
  end

  def sign_out
    session[:remember_token] = nil
    self.current_user = nil
  end

  private

    def user_from_remember_token
      User.authenticate_with_salt(*remember_token)
    end

    def remember_token
      session[:remember_token] || [nil, nil]
    end
end
