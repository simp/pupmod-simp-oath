# This define takes params and constructs a consistantly formated 
#
# concat fragment that will be inserted as a line in /etc/liboath/users.oath
# @param user - A continuous string. Legal characters are 
#               a-z, A-Z, 0-9, -, _ (comma not included)
# @param token_type - Allows a string of `HOTP`, `HOTP/T<window_time>`,
#                     `HOTP/<one-time_password_length>` and 
#                     `HOTP/T<window_time>/<one-time_password_length>`
# @param pin - Allows '-', '+' or an integer between 1 and 8 digits in length
#
# @param secret_key - Any continuous string of even length (odd length 
#                     can break secret_key to one-time password generators

define oath::config::user (
  Array[Pattern[/^[a-zA-Z0-9\-_]+(\s+)?$/]]    $user,
  Pattern[/^HOTP((\/T\d+)?(\/\d+)?)(\s+)?$/]   $token_type,
  Variant[Enum['-','+'], Integer[0,99999999]]  $pin,
  Pattern[/^(..)+(\s+)?$/]                     $secret_key
) {
  include '::oath::config'
  $_separator = '_'
  $_name = strip(regsubst($name, '/', '_'))
  $_token_type = strip($token_type)
  $_secret_key = strip($secret_key)
  $_user = strip(join($user, $_separator))

  $_content = "${_token_type}\t${_user}\t${pin}\t${_secret_key}\n"

  concat::fragment { "oath_user_${_name}":
    target  => '/etc/liboath/users.oath',
    content => $_content,
  }
}
