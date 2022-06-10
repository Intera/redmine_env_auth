# redmine_env_auth
this plugin allows to authenticate users using a variable in the request environment (set by the server or proxy server, in rails "request.env"). this variable can be custom named. one use case is log-in with single sign-on solutions (SSO) like ntlm/kerberos where the server (for example apache with mod_auth_kerberos) sets the request environment variable $REMOTE_USER to a username when a user has been authenticated.

# changelog
* 2018-08: completely revised, less code, added debugging features

# features
* automatically log-in users if a specific request environment variable is set, and log-out if it is unset
* option to allow conventional redmine logins for admins, specific users or everyone
* option to register users automatically if they are found using ldap
* "sign out" link hidden when autologin is active
* compatible with redmine 4

# installation
## download
dowload a [release](https://github.com/Intera/redmine_env_auth/releases) or a [zip file](https://github.com/Intera/redmine_env_auth/archive/master.zip) via github and unpack the archive.
alternatively you can clone the repository with "git clone https://github.com/Intera/redmine_env_auth.git"

## setup
move the "redmine_env_auth" directory from the download to your redmine installation directory under "plugins/", so that you have "plugins/redmine_env_auth". restart redmine. if the file system permissions are right, the plugin should now be installed. go into redmine under "Administration" "Plugins" to check that it is listed and eventually use the configure link to adjust settings of the plugin

# settings
|name|default|description|
|----|-------|-----------|
|enabled|true|enable or disable the plugin|
|name of request environment variable|REMOTE_USER||
|remove suffix||the given text will be removed from the end of the text in the environment variable|
|redmine user property|login|match local redmine users by login name or alternatively email address|
|allow other login|admins|this allows conventional logins. users must be allowed to see the login form|
|automatic registration with ldap check|false|if a matching local redmine user can not be found, try to find it in ldap and, if found, automatically create the user in redmine. the user will be linked with the ldap as the authentication source|

## redmine behind proxy
if redmine is run with a separate http server and another server first receives and proxies incoming requests, then the cgi environment will not be available to redmine and the authentication variable will not be set. this is the case for example if redmine is run with puma and another server like nginx or apache forwards requests to it. in this case, a http header can be used to transmit the user information. the setting for the env auth variable name must correspond to the header name used. with puma a HTTP_ prefix is added, with the following example config the variable name would be ``HTTP_X_REMOTE_USER`` instead of the default ``REMOTE_USER``.

important for security: under no circumstances should this header be forwarded from the client. you need to make sure that it is overwritten with your authentication value or removed if it exists before sending it to the redmine server.

apache 2.4 config example:
```
RequestHeader unset X_REMOTE_USER
RewriteEngine On
RewriteCond %{LA-U:REMOTE_USER} (.+)
RewriteRule .* - [E=RU:%1]
RequestHeader add X_REMOTE_USER %{RU}e
```

X_REMOTE_USER is first unset to ensure that it isnt set by some other source like a client or another proxy. the rewrite engine is used to look ahead (wait) on a future state of the variable (after it has been set by the authentication module, LA-U),
and when it is set (RewriteCond) apply the RewriteRule that doesnt rewrite the url but sets an environment variable RU with the match from the condition.
this requires the apache modules "headers" and "rewrite".

this other example can be found online, but it doesnt seem to work:
```
RequestHeader unset X_REMOTE_USER
RequestHeader set X_REMOTE_USER expr=%{REMOTE_USER}
```

# debugging
* /env_auth/info displays the current name and value of the environment variable that is configured to be used
* messages with the debug levels debug, info and error are written into the redmine log {redmine_root}/log/{environment}.log. log levels are set in `{redmine_root}/config/additional_environment.rb` (might have to be created), for example with the line `config.log_level = :debug`.
* you can display log output as it is being written with `tail -f production.log | grep redmine_env_auth`
* redmine sessions can be ended by going to /logout and clicking on the button

if you are locked out because the allow other login setting is not set to "all" and the request environment variable isnt set correctly, you might want to reset the plugin settings to be able to log-in with the conventional redmine login. the plugin settings are stored in the database and the sql to delete them is ``delete from settings where name="plugin_redmine_env_auth";``. you might have to restart redmine afterwards

# possible enhancements
* document how passing the login variable to only specific url paths can work
* all translations except "en", "de" and "ja" are out of date
* tests

# copyright and license
originally based on code from adam lantos, [redmine_http_auth](https://github.com/AdamLantos/redmine_http_auth).
* copyright (c) 2010 niif institute and adam lantos, released under the mit license
* copyright (c) 2018 [intera](https://www.intera.de/) (mit license)
