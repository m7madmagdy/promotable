class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception # Protect against CSRF attacks by raising an exception.

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
end
