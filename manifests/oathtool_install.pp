# == Class oath::oath_install
#
# This class is called from oath for installation of the oathtool
# utility. This utility enables conversion of a secret key into
# an appropriate TOTP or HOTP one-time password.
#
class oath::oathtool_install {
  assert_private()
  package { 'oathtool': ensure  => $::oath::package_ensure }
}
