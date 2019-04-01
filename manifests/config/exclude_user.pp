# This define takes params and constructs a consistantly formated concat
# fragment that will be inserted as a line in /etc/liboath/exclude_users.oath
#
# @param user
#  The username that will be affected
define oath::config::exclude_user (
  Pattern[/^[a-zA-Z0-9\-_]+(\s+)?$/]   $user,
) {
  include '::oath::config'

  $_separator = '_'
  $_user = strip($user)

  $_content = "${_user}\n"

  concat::fragment { "oath_exclude_user_${_user}":
    target  => '/etc/liboath/exclude_users.oath',
    content => $_content,
  }
}
