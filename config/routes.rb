RedmineApp::Application.routes.draw do
  get "env_auth/info", :to => "env_auth#info"
  get 'env_auth/logout', :to => "env_auth#logout"
end
