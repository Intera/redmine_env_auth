Redmine::Plugin.register :redmine_env_auth do
  name "Request Environment Authentication"
  author "Intera GmbH"
  url "http://github.com/intera/redmine_env_auth" if respond_to?(:url)
  description "A plugin for authentication based on variables in the request environment."
  version "1.3"

  Redmine::MenuManager.map :account_menu do |menu|
    # hide the logout link if an automatic login is active
    menu.delete :logout
    menu.push :logout, {:controller => 'env_auth', :action => 'logout'}, :caption => :label_logout, :if => Proc.new {
      if !User.current.logged?
        false
      elsif Setting.plugin_redmine_env_auth["enabled"] != "true"
        true
      elsif Setting.plugin_redmine_env_auth["show_logout_link"] == "true"
        true
      else
        false
      end
    }, :after => :my_account
  end

  settings :partial => "settings/redmine_env_auth_settings",
    :default => {
      "allow_other_login" => "admins",
      "allow_other_login_users" => "",
      "enabled" => "false",
      "env_variable_name" => "REMOTE_USER",
      "ldap_checked_auto_registration" => "false",
      "redmine_user_property" => "login",
      "remove_suffix" => "",
      "env_checked_auto_registration" => "false",
      "env_variable_firstname" => "GIVENNAME",
      "env_variable_lastname" => "LASTNAME",
      "env_variable_email" => "EMAIL",
      "env_variable_admins" => "",
      "env_variable_new_user_initial_locked" => "false",
      "show_logout_link" => "false",
      "external_logout_target" => ""
    }
end

if Rails.version > '6.0' && Rails.autoloaders.zeitwerk_enabled?
  RedmineEnvAuth::EnvAuthPatch.install
else
  Rails.configuration.to_prepare do
    RedmineEnvAuth::EnvAuthPatch.install
  end
end
