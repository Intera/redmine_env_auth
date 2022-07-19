class EnvAuthController < ApplicationController
  def info
    effective = remote_user
    variable_name = Setting.plugin_redmine_env_auth["env_variable_name"]
    original = request.env[variable_name]
    keys = request.env.keys.sort.select {|a|
      ["action_dispatch.", "action_controller.", "rack.", "puma."].none? {|b| a.start_with?(b)}
    }.join("\n  ")
    text = [
      "variable name: #{variable_name}",
      "original value: #{original.inspect}",
      "effective value: #{effective.inspect}"
    ].join("\n")

    text = "#{text}\navailable variables:\n  #{keys}"
    render :plain => text
  end

  def logout
    if Setting.plugin_redmine_env_auth["external_logout_target"] == ""
      redirect_to signout_path
    else 
      redirect_to Setting.plugin_redmine_env_auth["external_logout_target"]
    end
  end
end
