# This define takes params and constructs a consistantly formated concat
# fragment that will be inserted as a line in /etc/liboath/exclude_groups.oath
#
# @param group
#  The group that will be affected
define oath::config::exclude_group (
  Pattern[/^[a-zA-Z0-9\-_]+(\s+)?$/]   $group,
) {
  include '::oath::config'

  $_separator = '_'
  $_group = strip($group)

  $_content = "${_group}\n"

  concat::fragment { "oath_exclude_group_${_group}":
    target  => '/etc/liboath/exclude_groups.oath',
    content => $_content,
  }
}
