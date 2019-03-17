# This class is called from oath for pam_oath configuration.
# This class ensures files and directories have the correct
# selinux contexts to run (rpm defaults for pam_oath are nonexistent)
# It also parses the oath::oath_users hieradata and calls oath::config::user.pp
# define to check types and create a concat fragment that will be inserted into
# the /etc/liboath/users.oath file.
#
# @api private
class oath::config {
  assert_private()

  # Ensures correct selinux context of config directory
  file { '/etc/liboath':
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    seluser => 'system_u',
    seltype => 'var_auth_t',
  }

  if $oath::oath_exclude_users {
    concat { '/etc/liboath/exclude_users.oath':
      owner          => 'root',
      group          => 'root',
      mode           => '0600',
      ensure_newline => true,
      warn           => false,
      seluser        => 'system_u',
      seltype        => 'var_auth_t',
    }
    $oath::oath_exclude_users.each |$user_name| {
      oath::config::exclude_user {
        "exclude_user_$user_name": user => $user_name,
      }
    }
  }
  else {
    warning('oath::oath_exclude_users was left undefined! Puppet will not be managing this essential file!')
  }

  if $oath::oath_exclude_groups {
    concat { '/etc/liboath/exclude_groups.oath':
      owner          => 'root',
      group          => 'root',
      mode           => '0600',
      ensure_newline => true,
      warn           => false,
      seluser        => 'system_u',
      seltype        => 'var_auth_t',
    }

    $oath::oath_exclude_groups.each |$group_name| {
      oath::config::exclude_group {
        "exclude_group_$group_name": group => $group_name,
      }
    }
  }
  else {
    warning('oath::oath_exclude_groups was left undefined! Puppet will not be managing this essential file!')
  }

  if $oath::oath_users {
    concat { '/etc/liboath/users.oath':
      owner          => 'root',
      group          => 'root',
      mode           => '0600',
      ensure_newline => true,
      warn           => true,
      seluser        => 'system_u',
      seltype        => 'var_auth_t',
    }
    # Checks for a 'defaults' user and interprets as default settings,
    # stripping off 'defaults' from the rest of the users
    if $oath::oath_users['defaults'].is_a(Hash) {
      $defaults = $oath::oath_users['defaults']
      $raw_users = $oath::oath_users - 'defaults'
    }
    else {
      $defaults = {}
      $raw_users = $oath::oath_users
    }

    # Creates a new instance of the define for each raw_user in the array
    $raw_users.each |$some_user, $options| {
      if $options.is_a(Hash) {
        $args = { 'user' => [$some_user] } + $options
      }
      else {
        $args = { 'user' => [$some_user] }
      }

      oath::config::user {
        default: * => $defaults;
        $some_user: * => $args;
      }
    }
  }
  else {
    warning('oath::oath_users was left undefined! Puppet will not be managing this essential file!')
  }
}
