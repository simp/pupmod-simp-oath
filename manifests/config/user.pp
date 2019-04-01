# This define takes params and constructs a consistantly formated concat
# fragment that will be inserted as a line in /etc/liboath/users.oath
#
# @param user
#  The username that will be affected
#
# @param token_type
#   The type of OATH token that you are managing:
#
#   * Valid Options:
#     * `HOTP`
#     * `HOTP/T<window_time>`
#     * `HOTP/<one-time_password_length>`
#     * `HOTP/T<window_time>/<one-time_password_length>`
#
# @param pin
#   The PIN to use for the OATH token
#
# @param secret_key
#   Any continuous string of even length (odd length can break secret_key to
#   one-time password generators)
#
define oath::config::user (
  Array[Pattern[/^[a-zA-Z0-9\-_]+(\s+)?$/]]   $user,
  Pattern[/^HOTP((\/T\d+)?(\/\d+)?)(\s+)?$/]  $token_type,
  Variant[Enum['-','+'], Integer[0,99999999]] $pin,
  Pattern[/^(..)+(\s+)?$/]                    $secret_key
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
