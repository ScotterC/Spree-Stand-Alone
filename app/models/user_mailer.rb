class UserMailer < ActionMailer::Base

  def reset_password_instructions(user)
    default_url_options[:host] = Spree::Config[:site_url]

    @edit_password_reset_url = edit_user_password_url(:reset_password_token => user.reset_password_token)

    mail(:to => user.email,
         :subject => Spree::Config[:site_name] + ' ' + I18n.t("password_reset_instructions"))
  end

end

