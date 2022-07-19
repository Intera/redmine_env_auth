module RedmineEnvAuth
  module EnvAuthPatch

    module PrependMethods
      def find_current_user
        find_current_user_with_envauth
        super
      end
    end

    def self.install
      ApplicationController.class_eval do
        def remote_user
          #request.env["HTTP_X_REMOTE_USER"] = ""
          key = request.env[Setting.plugin_redmine_env_auth["env_variable_name"]]
          return nil unless key
          suffix = Setting.plugin_redmine_env_auth["remove_suffix"]
          if suffix.is_a?(String) and not suffix.empty?
            key.chomp suffix
          else
            key
          end
        end

        def get_env_firstname
          request.env[Setting.plugin_redmine_env_auth["env_variable_firstname"]]
        end          

        def get_env_lastname
          request.env[Setting.plugin_redmine_env_auth["env_variable_lastname"]]
        end          

        def get_env_mail
          request.env[Setting.plugin_redmine_env_auth["env_variable_email"]]
        end          

        def allow_other_login? user
          # User -> boolean
          # this checks if an existing session is allowed. redmine sessions can currently also
          # be started using the standard sign-in form.
          allow_other_login = Setting.plugin_redmine_env_auth["allow_other_login"]
          if not ["admins", "users", "all", "none"].include? allow_other_login
            allow_other_login = "all"
          end
          allow_other_login = false if "none" == allow_other_login
          if "users" == allow_other_login
            allow_other_login_users = Setting.plugin_redmine_env_auth["allow_other_login_users"]
            allow_other_login_users = allow_other_login_users.split(",").map {|a| a.strip }
          end
          if allow_other_login
            return true if ("all" == allow_other_login)
            return true if ("admins" == allow_other_login) and user.admin?
            return true if ("users" == allow_other_login) and allow_other_login_users.include?(user.login)
          end
          false
        end

        def find_current_user_with_envauth
          plugin_disabled = Setting.plugin_redmine_env_auth["enabled"] != "true"
          if plugin_disabled then return find_current_user_without_envauth end
          user = find_current_user_without_envauth
          if user and allow_other_login? user then
            if "login" == request.env["action_controller.instance"].action_name
              logger.debug "redmine_env_auth: ignoring active session and showing login form"
              reset_session
              return nil
            else
              logger.debug "redmine_env_auth: continuing active session for #{user.login}"
              return user
            end
          end
          logger.debug "redmine_env_auth: trying to log in using environment variable"
          key = remote_user
          if !key or key.empty?
            logger.info "redmine_env_auth: environment variable is unset. logging out any existing users. only allowed users can use standard login"
            reset_session if user
            return nil
          end
          logger.debug "redmine_env_auth: environment variable value is \"#{key}\""
          property = Setting.plugin_redmine_env_auth["redmine_user_property"]
          if user
            # existing session, check if user property matches current value of environment variable
            reuse_session = false
            if "mail" == property
              reuse_session = key == user.mail
            else
              reuse_session = key == user.login
            end
            if reuse_session
              logger.debug "redmine_env_auth: continuing active session for \"#{user.login}\""
              return user
            end
            reset_session
          end
          # try redmine users
          if "mail" == property
            user = User.find_by_mail key
          else
            user = User.find_by_login key
          end

          # try ldap users and auto registration
          if not user
            auto = "true" == Setting.plugin_redmine_env_auth["ldap_checked_auto_registration"]
            if auto then user = register_if_exists_in_ldap key end
          end
          if not user
            auto = "true" == Setting.plugin_redmine_env_auth["env_checked_auto_registration"]
            if auto then user = register_if_env_auto_registration_checked key end
          end

					if user and user.is_a? User and user.locked?
						logger.debug "user is locked. login is not allowed"
						reset_session
						nil
					end

					# start session or return nil
          if user and user.is_a? User
            logger.debug "redmine_env_auth: user found, start session"
            start_user_session user
            user.update_attribute :last_login_on, Time.now
            User.current = user
          else
            logger.debug "redmine_env_auth: redmine user #{key} not found using property #{property}"
            nil
          end
        end

        def register_if_exists_in_ldap login
          # search all ldap sources for a user with the given name and if found,
          # create a user with that name in redmine.
          auth_sources = AuthSource.where :type => "AuthSourceLdap"
          if 0 == auth_sources.count
            logger.debug "redmine_env_auth: no ldap source found"
            return
          end
          # attributes that redmine requires for creating a user
          required_attrs = [:firstname, :lastname, :mail]
          auth_sources.find do |auth_source|
            users = auth_source.search login
            next if 0 == users.length
            ldap_user = users.first
            next if login != ldap_user[:login]
            missing_attrs = required_attrs - ldap_user.keys
            if 0 < missing_attrs.length
              logger.debug "redmine_env_auth: missing attributes #{missing_attrs} from ldap, cant create user"
              next
            end
            user = User.new ldap_user.slice(:firstname, :lastname, :mail)
            user.login = ldap_user[:login]
            # registered users will be able to log in using ldap if redmine_env_auth is disabled.
            # an alternative would be to not set auth_source_id, users without password can not log in.
            user.auth_source_id = auth_source.id
            if user.save
              user.reload
              logger.debug "redmine_env_auth: user creation after ldap sync successful"
              return user
            else
              logger.error "redmine_env_auth: user creation after ldap sync failed"
              return
            end
          end
          logger.debug "redmine_env_auth: no user found via ldap"
          nil
        end

        def register_if_env_auto_registration_checked login
          logger.debug "attempt to create env-user"
          # check if required fields exist
          if get_env_lastname.empty? 
            logger.debug "redmine_env_auth: lastname is empty. cannot create user"
            return nil
          end

          if get_env_firstname.empty?
            logger.debug "redmine_env_auth: given_name is empty. cannot create user"
            return nil
          end

          if get_env_mail.empty?
            logger.debug "redmine_env_auth: given_name is empty. cannot create user"
            return nil
          end

          user = User.new({:firstname => get_env_firstname, :lastname => get_env_lastname, :mail => get_env_mail})
          user.login = login

          if Setting.plugin_redmine_env_auth["env_variable_new_user_initial_locked"] == "true"
						user.lock!
					end

					if Setting.plugin_redmine_env_auth["env_variable_admins"].split('/\s*,\s*/').include? login
						user.admin = true
					end
					
          if user.save
            user.reload
            logger.debug "redmine_env_auth: user creation successful"
            return user
          else
            logger.error "redmine_env_auth: user creation failed"
            return
          end
        end

        if self.respond_to?(:alias_method_chain) # Rails < 5
          # register find_current_user_with/without_envauth
          alias_method_chain :find_current_user, :envauth
        else # Rails >= 5
          alias_method :find_current_user_without_envauth, :find_current_user
          prepend PrependMethods
        end
      end
    end
  end
end
